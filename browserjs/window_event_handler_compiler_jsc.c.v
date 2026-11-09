// DOM/EventTarget.cpp raw Window handlers use the relevant owner's GlobalEnv.
// Element handlers require actual Document/form/element ObjectEnvironments and
// are deliberately outside this engine adapter's supported compilation path.
module browserjs

import dom
import html


fn C.vox_jsc_JSCheckScriptSyntax(context voidptr, source voidptr, source_url voidptr, line int, exception &voidptr) bool
fn C.vox_jsc_JSObjectMakeFunction(context voidptr, name voidptr, parameter_count u32, parameters &voidptr, body voidptr, source_url voidptr, line int, exception &voidptr) voidptr

pub fn (mut runtime Runtime) install_window_event_handler_compiler(document &dom.Document) ! {
	runtime.require_javascript_value_context()!
	settings := runtime.scripting_settings_ or { return error('Raw Window handlers require their owning scripting environment') }
	owner_document := settings.responsible_document() or { return error('Raw Window handlers require an actual Document') }
	if voidptr(owner_document) != voidptr(document) {
		return error('Raw Window handler compiler belongs to another Document')
	}
	// A compiled handler reuses the actual Event/Callback binding and record map.
	_ = runtime.event_binding()!
	owner := voidptr(&runtime)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_inline_event_handler_compiler(dom.InlineEventHandlerCompiler{
		can_compile: fn [owner, settings] (target &dom.EventTarget) bool {
			runtime := unsafe { &Runtime(owner) }
			return !runtime.closed && runtime.context != unsafe { nil }
				&& voidptr(target) == voidptr(settings.global_object())
				&& target.data.kind == .window && html.is_scripting_enabled(settings.realm())
		}
		compile:     fn [owner, settings] (target &dom.EventTarget, name string, body string, source string) ?&dom.CallbackType {
			mut runtime := unsafe { &Runtime(owner) }
			return runtime.compile_window_event_handler(target, name, body, source, settings)
		}
	})
}

fn (mut runtime Runtime) compile_window_event_handler(target &dom.EventTarget, name string, body string, source string, settings &html.EnvironmentSettingsObject) ?&dom.CallbackType {
	// Source parses FunctionBody and checks early errors before pushing the
	// relevant realm execution context. Syntax errors null the raw handler;
	// source reporting of the location/parse error remains its explicit FIXME.
	source_value := js_source_string(source)
	defer { C.JSStringRelease(source_value) }
	mut syntax_exception := unsafe { nil }
	if !C.vox_jsc_JSCheckScriptSyntax(runtime.context, source_value, unsafe { nil }, 1, &syntax_exception) {
		return none
	}
	function_name := js_source_string('on' + name)
	body_value := js_source_string(body)
	defer { C.JSStringRelease(function_name) }
	defer { C.JSStringRelease(body_value) }
	parameter_names := if name == 'error' {
		['event', 'source', 'lineno', 'colno', 'error']
	} else {
		['event']
	}
	mut parameters := []voidptr{}
	for parameter in parameter_names { parameters << js_source_string(parameter) }
	defer {
		for parameter in parameters { C.JSStringRelease(parameter) }
	}
	// JSC's dynamic-function API creates a genuine function in this owner
	// global environment without a named-function-expression or factory scope.
	// Source creation pushes/pops the realm context, without callback cleanup or
	// an HTML microtask checkpoint at this point.
	mut vm := runtime.agent_vm
	mut context := runtime.realm_context
	vm.push_execution_context(mut context)
	mut exception := unsafe { nil }
	function := runtime.compile_host_function(function_name, u32(parameters.len), parameters.data,
		body_value, unsafe { nil }, 1, &exception)
	popped := vm.pop_execution_context()
	assert voidptr(popped) == voidptr(runtime.realm_context)
	if exception != unsafe { nil } || function == unsafe { nil } { return none }
	// Callback context is the relevant settings realm, rather than whichever
	// incumbent happened to trigger lazy compilation.
	mut callback := runtime.event_callback_with_settings(function, true, settings) or { return none }
	callback.associated_window = unsafe { &dom.Window(target) }
	callback.compiled_source_text_ = source
	return callback
}

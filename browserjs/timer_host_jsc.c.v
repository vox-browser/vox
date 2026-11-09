@[has_globals]
module browserjs

import dom
import html
import trustedtypes
import webidl


__global timer_host_bindings_ = map[voidptr]&TimerHost{}
__global timer_scope_bindings_ = map[voidptr]&TimerHost{}

pub fn (mut host TimerHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	owner_handle := voidptr(&runtime)
	if existing := timer_host_bindings_[owner_handle] {
		if voidptr(existing) == voidptr(&host) { return }
		return error('Timer binding already belongs to this runtime')
	}
	scope_handle := voidptr(host.scope)
	if _ := timer_scope_bindings_[scope_handle] { return error('Owning source scope already has a native timer adapter') }
	host.runtime = &runtime
	// Capture the actual script-visible global before author replacements;
	// source callbacks receive their owning WindowProxy/global wrapper.
	global_this := runtime.evaluate_host_value('globalThis')!
	defer { runtime.release_javascript_value(global_this) }
	host.global_this_value_ = runtime.webidl_value(global_this)!
	host_handle := voidptr(&host)
	mut scope := unsafe { &html.WindowOrWorkerGlobalScopeMixin(host.scope) }
	removed := fn [host_handle] (id i32) {
		mut host := unsafe { &TimerHost(host_handle) }
		roots := host.ids[id] or { return }
		host.ids.delete(id)
		for value in roots { host.runtime.release_javascript_value(value) }
	}
	runtime.own_closure(voidptr(removed))
	scope.set_timer_removed_handler(removed)
	scope.set_timer_classic_script_evaluator(fn [host_handle] (source string, realm &html.ScriptingRealm) !dom.JSValue {
		mut host := unsafe { &TimerHost(host_handle) }
		if host.closed { return dom.js_undefined() }
		mut runtime := unsafe { &Runtime(host.runtime) }
		if html.can_run_script_for_settings(host.settings) == .do_not_run { return dom.js_undefined() }
		defer { runtime.mark_document_state_dirty() }
		script := realm.active_classic_script_ or { return error('Timer source requires its actual ClassicScript') }
		url := script.base_url() or { return error('Timer ClassicScript has no base URL') }
		actual_source := js_source_string(source)
		actual_url := js_source_string(url.serialize())
		defer { C.JSStringRelease(actual_source); C.JSStringRelease(actual_url) }
		mut exception := unsafe { nil }
		C.vox_jsc_JSEvaluateScript(runtime.context, actual_source, unsafe { nil }, actual_url, 1, &exception)
		if exception != unsafe { nil } { return webidl.throw_value(runtime.webidl_value(exception)!) }
		return dom.js_undefined()
	})
	scope.set_timer_compilation_exception_value_converter(fn [host_handle] (exception IError) webidl.Value {
		mut host := unsafe { &TimerHost(host_handle) }
		if host.closed { return webidl.exception_value(exception) }
		mut runtime := unsafe { &Runtime(host.runtime) }
		return runtime.webidl_value(runtime.binding_exception_value(exception)) or { webidl.exception_value(exception) }
	})
	operation := runtime.make_value_host_function(fn [host_handle] (_ voidptr, arguments []voidptr) !voidptr {
		mut host := unsafe { &TimerHost(host_handle) }
		return host.operate(arguments) or { host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err)) }
	})!
	installer := runtime.evaluate_host_value(timer_host_bootstrap)!
	defer { runtime.release_javascript_value(installer) }
	runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [operation])!
	timer_host_bindings_[owner_handle] = &host
	timer_scope_bindings_[scope_handle] = &host
	runtime.add_close_handler(fn [host_handle, owner_handle, scope_handle] () {
		mut host := unsafe { &TimerHost(host_handle) }
		host.close()
		timer_host_bindings_.delete(owner_handle)
		timer_scope_bindings_.delete(scope_handle)
	})
}

fn (host &TimerHost) argument(arguments []voidptr, index int) voidptr {
	if index < arguments.len { return arguments[index] }
	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

fn (mut host TimerHost) value(value webidl.Value) !voidptr {
	if value.dom_exception_ != none { return host.runtime.javascript_dom_exception(value) }
	return match value.kind {
		.runtime_value { host.runtime.actual_webidl_value(value)! }
		.undefined { C.vox_jsc_JSValueMakeUndefined(host.runtime.context) }
		.null_ { C.vox_jsc_JSValueMakeNull(host.runtime.context) }
		.boolean { C.vox_jsc_JSValueMakeBoolean(host.runtime.context, value.boolean_value) }
		.number { C.vox_jsc_JSValueMakeNumber(host.runtime.context, value.number_value) }
		.string_ { host.runtime.binding_string(value.string_value) }
		else { return error('Timer value requires its actual JavaScript platform wrapper') }
	}
}

fn (mut host TimerHost) operate(arguments []voidptr) !voidptr {
	if host.closed { return error('Timer binding is closed') }
	op := host.runtime.binding_dom_string(host.argument(arguments, 0))!
	if arguments.len > 4 && host.settings.fetch_request_client_is_window() {
		window := host.runtime.message_window(arguments[4])!
		settings := window.associated_document().relevant_settings_object()
		if settings != unsafe { nil } {
			owner := unsafe { &html.EnvironmentSettingsObject(settings) }
			target_scope := owner.window_or_worker_global_scope()!
			if voidptr(target_scope) != voidptr(host.scope) {
				mut target := timer_scope_bindings_[voidptr(target_scope)] or { return error('Window timer host is not installed') }
				return target.operate(arguments[..4])
			}
		}
	}
	handler_value := host.argument(arguments, 1)
	if op == 'clear' {
		mut exception := unsafe { nil }
		number := C.vox_jsc_JSValueToNumber(host.runtime.context, handler_value, &exception)
		if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
		id := i32(webidl.convert_to_int(webidl.number_value(number), 32, true, .no, .no)!)
		mut scope := unsafe { &html.WindowOrWorkerGlobalScopeMixin(host.scope) }
		scope.clear_timeout(id)
		return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
	}
	mut roots := []voidptr{}
	mut installed := false
	defer {
		if !installed {
			for value in roots { host.runtime.release_javascript_value(value) }
		}
	}
	mut handler := html.TimerHandler{}
	if C.JSValueIsObject(host.runtime.context, handler_value) && C.JSObjectIsFunction(host.runtime.context, handler_value) {
		host_handle := voidptr(&host)
		callback := host.runtime.webidl_void_callback(handler_value, fn [host_handle] (value webidl.Value) !voidptr {
			mut host := unsafe { &TimerHost(host_handle) }
			return host.value(value)
		})!
		roots << handler_value
		handler = html.timer_webidl_callback_handler(callback, host.global_this_value_)
	} else {
		handler = html.timer_source_handler(host.runtime.binding_dom_string(handler_value)!)
	}
	mut exception := unsafe { nil }
	number := C.vox_jsc_JSValueToNumber(host.runtime.context, host.argument(arguments, 2), &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	timeout := i32(webidl.convert_to_int(webidl.number_value(number), 32, true, .no, .no)!)
	actual_arguments := host.argument(arguments, 3)
	length := host.runtime.binding_property(actual_arguments, 'length')!
	count := int(C.vox_jsc_JSValueToNumber(host.runtime.context, length, &exception))
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	mut values := []dom.JSValue{cap: count}
	for index in 0 .. count {
		value := C.vox_jsc_JSObjectGetPropertyAtIndex(host.runtime.context, actual_arguments, u32(index), &exception)
		if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
		values << dom.js_webidl_value(host.runtime.webidl_value(value)!)
		roots << value
	}
	mut scope := unsafe { &html.WindowOrWorkerGlobalScopeMixin(host.scope) }
	if source := handler.source {
		mut factory := unsafe { &trustedtypes.TrustedTypePolicyFactory(scope.trusted_types()) }
		sink := if host.settings.fetch_request_client_is_window() {
			if op == 'interval' { trustedtypes.InjectionSink.window_set_interval } else { trustedtypes.InjectionSink.window_set_timeout }
		} else { if op == 'interval' { trustedtypes.InjectionSink.worker_global_scope_set_interval } else { trustedtypes.InjectionSink.worker_global_scope_set_timeout } }
		handler = html.timer_source_handler(trustedtypes.get_trusted_type_compliant_string(mut factory,.trusted_script,source,sink,"'script'",true)!)
	}
	id := if op == 'interval' { scope.set_interval(handler, timeout, values) } else { scope.set_timeout(handler, timeout, values) }
	if id == 0 { return C.vox_jsc_JSValueMakeNumber(host.runtime.context,0) }
	host.ids[id] = roots
	installed = true
	return C.vox_jsc_JSValueMakeNumber(host.runtime.context, id)
}

const timer_host_bootstrap = r'(function(operate){
 const define=Object.defineProperty,TypeError=globalThis.TypeError;
 function timer(receiver,operation,handler,timeout,args){const values=[];for(let i=2;i<args.length;i++)define(values,i-2,{value:args[i],writable:true,enumerable:true,configurable:true});return operate(operation,handler,timeout,values,receiver)}
 function setTimeout(handler,timeout){if(arguments.length<1)throw new TypeError("setTimeout requires 1 argument");const converted=typeof handler==="function"?handler:`${handler}`;return timer(this,"timeout",converted,timeout===undefined?0:+timeout,arguments)}
 function setInterval(handler,timeout){if(arguments.length<1)throw new TypeError("setInterval requires 1 argument");const converted=typeof handler==="function"?handler:`${handler}`;return timer(this,"interval",converted,timeout===undefined?0:+timeout,arguments)}
 function clearTimeout(id){return operate("clear",id===undefined?0:+id)}
 function clearInterval(id){return operate("clear",id===undefined?0:+id)}
 for(const [name,method] of [["setTimeout",setTimeout],["setInterval",setInterval],["clearTimeout",clearTimeout],["clearInterval",clearInterval]])define(globalThis,name,{value:method,writable:true,enumerable:true,configurable:true});
 define(setTimeout,"length",{value:1,configurable:true});define(setInterval,"length",{value:1,configurable:true});define(clearTimeout,"length",{value:0,configurable:true});define(clearInterval,"length",{value:0,configurable:true})
})'

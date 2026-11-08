module browserjs

import libjs
import dom
import html
import json2
import platform
import processmetrics

pub enum Engine {
	javascriptcore
	libjs
}

// `.javascriptcore` selects the native JavaScript C API. The experimental
// `-d vox_v8` build implements that API on V8 (v8/jsc_on_v8.cpp); there is no
// runtime engine choice between them.
pub fn parse_engine(name string) !Engine {
	return match name {
		'javascriptcore' { .javascriptcore }
		'libjs' { .libjs }
		else { return error('Unknown JavaScript engine "${name}"; expected javascriptcore or libjs') }
	}
}

pub struct ScriptSource {
pub:
	code          string
	url           string
	starting_line int              = 1
	source_type   libjs.SourceType = .script
	// The host's actual script element, including inline scripts/currentScript.
	element ?&dom.Element
	// The compact loader retains the actual external script for completion events.
	external_element ?&dom.Element
}

@[heap]
pub struct PreparedScript {
pub:
	source   ScriptSource
	frontend &libjs.ParsedSource
}

// Retain the translated AST and scope analysis at the browser's engine boundary.
// The backend must still validate RegExp patterns and input beyond the V parser's
// recursion budget; neither of those limits is an ECMAScript syntax error.
pub fn prepare_script(source ScriptSource) !&PreparedScript {
	if source.starting_line < 1 {
		return error('Script starting line must be positive')
	}
	parsed := libjs.parse_source(source.code, source.source_type)
	if parsed.has_errors() && !parsed.reached_recursion_limit {
		diagnostic := parsed.diagnostics[0]
		filename := if source.url == '' { '<script>' } else { source.url }
		line := u64(source.starting_line) + diagnostic.line - 1
		return error('SyntaxError: ${filename}:${line}:${diagnostic.column + 1}: ${diagnostic.message}')
	}
	return &PreparedScript{source, parsed}
}

// JavaScriptCore preserves the complete browser host while LibJS execution is
// translated. Choosing LibJS never creates or falls back to a JSC context.
@[heap]
pub struct Runtime {
	agent_vm &libjs.VM
	realm    &libjs.Realm
	realm_context &libjs.ExecutionContext
pub:
	engine Engine
mut:
	worker_module_global bool
	context                   voidptr
	closed                    bool
	engine_async_completion_installed_ bool
	host_functions_           []&HostFunctionRecord
	value_host_functions_     []&ValueHostFunctionRecord
	native_stream_wrapper_records_ map[voidptr]voidptr
	protected_values_         []voidptr
	protected_value_indices_  map[voidptr][]int
	protected_value_positions_ []int
	protected_value_tails_     map[voidptr]int
	protected_value_links_     []ProtectedValueLink
	protected_value_links_reported_ bool
	value_call_intrinsic_     voidptr
	promise_observe_intrinsic_ voidptr
	value_error_intrinsic_     voidptr
	value_same_intrinsic_      voidptr
	value_number_intrinsic_    voidptr
	value_bigint_int64_intrinsic_ voidptr
	value_bigint_intrinsic_ voidptr
	value_function_metadata_intrinsic_ voidptr
	webidl_promise_bridges_    map[voidptr]&WebIDLJavaScriptPromiseBridge
	canvas_element_providers_ []CanvasElementBindingProvider
	// Union of the providers' wrappers; see merge_canvas_elements_into().
	canvas_element_registry_ &CanvasElementRegistry = unsafe { nil }
	media_element_hosts_ []&MediaElementHost
	close_handlers_ []fn ()
	// Closures, besides function and close-handler callbacks, that this
	// runtime's bindings own and release when it closes.
	owned_closures_ []voidptr
	document_state_dirty_ bool
	document_state_wakeup_ ?fn ()
	document_replay_effects_pending_ bool
	scripting_settings_ ?&html.EnvironmentSettingsObject
	module_host_ ?&ModuleHost
}

pub fn Runtime.create() &Runtime {
	return Runtime.create_with_engine(.javascriptcore)
}

// Worker globals need their host prototype allocated when JSC creates the realm.
pub fn Runtime.create_for_worker() &Runtime {
	return Runtime.create_with_global(.javascriptcore, true)
}

// Apple's module API requires its ordinary global class. Keep the worker's
// bindings as own properties rather than altering the realm's Object.prototype.
pub fn Runtime.create_for_module_worker() &Runtime {
	mut runtime := Runtime.create_with_global(.javascriptcore, false)
	runtime.worker_module_global = true
	return runtime
}

pub fn Runtime.create_with_engine(engine Engine) &Runtime {
	return Runtime.create_with_global(engine, false)
}

fn Runtime.create_with_global(engine Engine, worker_global bool) &Runtime {
	mut agent_vm := libjs.VM.create()
	realm_context := libjs.create_simple_execution_context(mut agent_vm)
	mut context := unsafe { nil }
	$if darwin || linux || windows {
		if engine == .javascriptcore { context = create_javascript_core_context(worker_global) }
	}
	mut runtime := &Runtime{
		engine:   engine
		agent_vm: agent_vm
		realm:    realm_context.realm or { panic('browser realm was not initialized') }
		realm_context: realm_context
		context:  context
	}
	$if darwin || linux || windows {
		if engine == .javascriptcore && context != unsafe { nil } {
			runtime.initialize_javascript_value_intrinsics() or { panic(err) }
		}
	}
	return runtime
}

pub fn (runtime &Runtime) libjs_vm() &libjs.VM {
	return runtime.agent_vm
}

pub fn (runtime &Runtime) libjs_realm() &libjs.Realm {
	return runtime.realm
}

// Bindings/MainThreadVM.cpp::create_a_new_javascript_realm removes the
// initialization context and gives the settings object ownership of it.
pub fn (mut runtime Runtime) bind_scripting_environment(settings &html.EnvironmentSettingsObject) ! {
	if runtime.closed { return error('JavaScript runtime is closed') }
	if existing := runtime.scripting_settings_ {
		if voidptr(existing) == voidptr(settings) { return }
		return error('JavaScript runtime already belongs to a different scripting environment')
	}
	mut vm := unsafe { &libjs.VM(runtime.agent_vm) }
	if vm.execution_context_stack().len != 1 || !vm.has_running_execution_context() || voidptr(vm.running_execution_context()) != voidptr(runtime.realm_context) {
		return error('Cannot attach a scripting environment during JavaScript execution')
	}
	popped := vm.pop_execution_context()
	assert voidptr(popped) == voidptr(runtime.realm_context)
	mut realm := unsafe { &html.ScriptingRealm(settings.realm()) }
	realm.bind_embedding_execution_context(vm, runtime.realm_context)
	mut event_loop := unsafe { &html.EventLoop(settings.responsible_event_loop()) }
	event_loop.attach_embedding_vm(vm)
	runtime.scripting_settings_ = settings
}

fn (runtime &Runtime) prepare_html_script() {
	if settings := runtime.scripting_settings_ {
		mut realm := unsafe { &html.ScriptingRealm(settings.realm()) }
		html.prepare_to_run_script(mut realm)
	}
}

fn (runtime &Runtime) clean_up_html_script() {
	if settings := runtime.scripting_settings_ {
		mut realm := unsafe { &html.ScriptingRealm(settings.realm()) }
		html.clean_up_after_running_script(mut realm)
	}
}

fn (runtime &Runtime) callback_settings() ?&html.EnvironmentSettingsObject {
	if settings := runtime.scripting_settings_ {
		if settings.realm().script_execution_depth > 0 { return html.incumbent_settings_object() }
		return settings
	}
	return none
}

fn (runtime &Runtime) prepare_html_callback(stored_settings ?&html.EnvironmentSettingsObject) {
	runtime.prepare_html_script()
	if settings := stored_settings {
		mut realm := unsafe { &html.ScriptingRealm(settings.realm()) }
		html.prepare_to_run_callback(mut realm)
	}
}

fn (runtime &Runtime) clean_up_html_callback(stored_settings ?&html.EnvironmentSettingsObject) {
	if settings := stored_settings {
		mut realm := unsafe { &html.ScriptingRealm(settings.realm()) }
		html.clean_up_after_running_callback(mut realm)
	}
	runtime.clean_up_html_script()
}

pub fn (runtime &Runtime) evaluate(source string) !string {
	return runtime.execute_source(ScriptSource{ code: source }, true)
}

pub fn (runtime &Runtime) evaluate_prepared(script &PreparedScript) !string {
	return runtime.execute_prepared(script, true)
}

fn (runtime &Runtime) check_execution_support(source_type libjs.SourceType) ! {
	if runtime.closed {
		return error('JavaScript runtime is closed')
	}
	if source_type == .module && runtime.module_host_ == none {
		return error('Module execution is not yet implemented by the browser JavaScript backend')
	}
}

// Each backend owns preparation of its executable source. Explicit preparation
// above remains the complete translated AST API for frontend consumers.
fn (runtime &Runtime) execute_source(source ScriptSource, stringify_result bool) !string {
	load_instruction_stage := processmetrics.begin_javascript_instruction_stage()
	defer { load_instruction_stage.finish() }
	runtime.check_execution_support(source.source_type)!
	if source.starting_line < 1 { return error('Script starting line must be positive') }
	if host := runtime.module_host_ {
		mut mutable_host := unsafe { &ModuleHost(host) }
		if source.source_type == .module { return mutable_host.execute(source, stringify_result) }
		transformed := mutable_host.transform_classic(source)!
		record := libjs.Script.create_external(source.code, runtime.realm, source.url,
			u32(source.starting_line), voidptr(runtime))!
		return runtime.execute_embedding_script(transformed, record, stringify_result)
	}
	if runtime.engine == .libjs {
		return runtime.execute_prepared(prepare_script(source)!, stringify_result)
	}
	record := libjs.Script.create_external(source.code, runtime.realm, source.url,
		u32(source.starting_line), voidptr(runtime))!
	return runtime.execute_embedding_script(source, record, stringify_result)
}

fn (runtime &Runtime) execute_prepared(script &PreparedScript, stringify_result bool) !string {
	load_instruction_stage := processmetrics.begin_javascript_instruction_stage()
	defer { load_instruction_stage.finish() }
	runtime.check_execution_support(script.source.source_type)!
	if runtime.module_host_ != none { return runtime.execute_source(script.source, stringify_result) }
	if runtime.engine == .libjs {
		if script.frontend.reached_recursion_limit {
			return error('LibJS frontend recursion limit reached; this program cannot be executed by the translated runtime')
		}
		mut vm := unsafe { &libjs.VM(runtime.agent_vm) }
		runtime.prepare_html_script()
		defer { runtime.clean_up_html_script() }
		mut record := &libjs.Script{
			realm:          runtime.realm
			filename:       if script.source.url == '' { '<script>' } else { script.source.url }
			starting_line:  u32(script.source.starting_line)
			host_defined:   voidptr(runtime)
			parsed:         script.frontend
			is_strict_mode: script.frontend.is_strict_mode
		}
		value := vm.run_with_limits(mut record, libjs.ExecutionLimits{ max_instructions: 1000000 }) or {
			return error(libjs_exception_message(err))
		}
		if !stringify_result { return '' }
		text := value.to_primitive_string(mut vm) or { return error(libjs_exception_message(err)) }
		return text.str()
	}
	record := &libjs.Script{
		realm: runtime.realm
		filename: script.source.url
		starting_line: u32(script.source.starting_line)
		host_defined: voidptr(runtime)
		parsed: script.frontend
		is_strict_mode: script.frontend.is_strict_mode
	}
	return runtime.execute_embedding_script(script.source, record, stringify_result)
}

fn (runtime &Runtime) execute_embedding_script(source ScriptSource, record &libjs.Script,
	stringify_result bool) !string {
	// Associate this host execution with the translated Script/Realm records.
	// These are embedding contexts; JavaScriptCore still owns its JS call frames,
	// global bindings and promise reactions until the interpreter is translated.
	mut vm := unsafe { &libjs.VM(runtime.agent_vm) }
	mut execution := libjs.ExecutionContext.create(0, [], 0)
	execution.realm = runtime.realm
	global_environment := runtime.realm.global_environment_record()
	execution.lexical_environment = libjs.Environment(global_environment)
	execution.variable_environment = libjs.Environment(global_environment)
	execution.script_or_module = libjs.ScriptOrModule.from_script(record)
	runtime.prepare_html_script()
	vm.push_execution_context_checked(mut execution) or {
		runtime.clean_up_html_script()
		return err
	}
	defer {
		vm.pop_execution_context()
		runtime.clean_up_html_script()
	}
	return runtime.evaluate_backend(source, stringify_result, record.external_source_text != none)
}

// Host-generated bootstrap and DOM dispatch code has its own trusted boundary;
// it must not consume the much smaller translated parser stack budget.
pub fn (runtime &Runtime) evaluate_host(source string) !string {
	if runtime.engine == .libjs { return runtime.evaluate(source) }
	runtime.prepare_html_script()
	defer { runtime.clean_up_html_script() }
	return runtime.evaluate_backend(ScriptSource{ code: source }, true, false)
}

fn libjs_exception_message(err IError) string {
	if !libjs.is_throw_completion(err) { return err.msg() }
	value := libjs.thrown_value(err)
	if value.is_object() {
		object := value.as_object()
		if kind := object.error_kind() {
			message := object.error_message() or { '' }
			trace := if data := object.error_data { data.stack_string(false) } else { '' }
			return '${kind.name()}: ${message}' + if trace == '' {
				''
			} else {
				'\n' + trace.trim_right('\n')
			}
		}
	}
	return err.msg()
}

fn (runtime &Runtime) evaluate_backend(source ScriptSource, stringify_result bool, positioned_syntax_errors bool) !string {
	if runtime.closed {
		return error('JavaScript runtime is closed')
	}
	$if darwin || linux || windows {
		if runtime.context == unsafe { nil } {
			return error('JavaScriptCore context creation failed')
		}
		return evaluate_with_javascript_core(runtime.context, source, stringify_result, positioned_syntax_errors)
	} $else {
		return error('JavaScript evaluation is currently available on macOS only')
	}
}

// Each script runs as a separate global program, followed by the backend's
// microtask checkpoint. One failed script must not prevent later scripts or
// the document's readiness events. Do not coerce discarded completion values.
pub fn (runtime &Runtime) run_document_scripts(sources []ScriptSource) ! {
	if runtime.engine == .libjs {
		errors := runtime.run_document_scripts_collect_errors(sources)
		if errors.len > 0 { return error(errors.join('\n')) }
		return
	}
	for source in sources {
		runtime.execute_source(source, false) or {
			runtime.evaluate_host('console.error(${json2.encode(err.msg())})')!
		}
	}
}

// Collect host-readable diagnostics without requiring a JavaScript console.
// This lets the native browser run the supported LibJS slice without its
// JavaScriptCore-based DOM bootstrap. Failures do not stop later programs.
pub fn (runtime &Runtime) run_document_scripts_collect_errors(sources []ScriptSource) []string {
	mut errors := []string{}
	for source in sources {
		runtime.execute_source(source, false) or { errors << err.msg() }
	}
	return errors
}

pub fn (mut runtime Runtime) close() {
	if runtime.closed {
		return
	}
	runtime.closed = true
	if wakeup := runtime.document_state_wakeup_ {
		runtime.document_state_wakeup_ = none
		platform.release_closure(voidptr(wakeup))
	}
	runtime.document_state_dirty_ = false
	for handler in runtime.close_handlers_ {
		handler()
		platform.release_closure(voidptr(handler))
	}
	runtime.close_handlers_ = []
	$if darwin || linux || windows {
		if runtime.context != unsafe { nil } {
			for value in runtime.protected_values_ { C.JSValueUnprotect(runtime.context, value) }
			runtime.protected_values_ = []
			runtime.protected_value_indices_.clear()
			runtime.protected_value_positions_ = []
			runtime.protected_value_tails_.clear()
			runtime.protected_value_links_ = []
			release_javascript_core_context(runtime.context)
			runtime.context = unsafe { nil }
		}
	}
	mut vm := unsafe { &libjs.VM(runtime.agent_vm) }
	vm.clear_execution_context_stack()
	// Binding callbacks are closures written at their definitions. The
	// runtime that owns them can no longer call them, and they would otherwise
	// keep their hosts, and through them the document, alive.
	for index, record in runtime.host_functions_ {
		report_host_callback_diagnostic(&runtime, 'runtime_close', 'text', index, record.diagnostic)
		if record.callback != unsafe { nil } { platform.release_closure(voidptr(record.callback)) }
		if record.temporary_callback != unsafe { nil } {
			platform.release_closure(voidptr(record.temporary_callback))
		}
	}
	for index, record in runtime.value_host_functions_ {
		report_host_callback_diagnostic(&runtime, 'runtime_close', 'value', index, record.diagnostic)
		platform.release_closure(voidptr(record.callback))
	}
	for owned in runtime.owned_closures_ { platform.release_closure(owned) }
	for provider in runtime.canvas_element_providers_ {
		platform.release_closure(voidptr(provider.snapshot))
		platform.release_closure(voidptr(provider.lookup))
		platform.release_closure(voidptr(provider.identity))
		platform.release_closure(voidptr(provider.merge))
	}
	runtime.owned_closures_ = []
	runtime.host_functions_ = []
	runtime.value_host_functions_ = []
	runtime.native_stream_wrapper_records_ = {}
	runtime.webidl_promise_bridges_ = {}
	runtime.canvas_element_providers_ = []
	runtime.canvas_element_registry_ = unsafe { nil }
	runtime.media_element_hosts_ = []
	if settings := runtime.scripting_settings_ {
		mut event_loop := unsafe { &html.EventLoop(settings.responsible_event_loop()) }
		event_loop.detach_embedding_vm(runtime.agent_vm)
	}
	runtime.scripting_settings_ = none
	runtime.closed = true
}

// The runtime owns the handler, a closure written at the call, and releases
// it after running it.
pub fn (mut runtime Runtime) add_close_handler(handler fn ()) { runtime.close_handlers_ << handler }

// Release callback, a closure that only this runtime's bindings call, when the
// runtime closes.
pub fn (mut runtime Runtime) own_closure(callback voidptr) { runtime.owned_closures_ << callback }

// The embedding owns frame scheduling. Wake it once per pending replay, even
// when a callback changes only compact state and creates no native invalidation.
// This runtime owns the supplied closure until replacement or close.
pub fn (mut runtime Runtime) set_document_state_wakeup(wakeup ?fn ()) {
	if previous := runtime.document_state_wakeup_ {
		platform.release_closure(voidptr(previous))
	}
	runtime.document_state_wakeup_ = none
	if runtime.closed {
		if callback := wakeup { platform.release_closure(voidptr(callback)) }
		return
	}
	runtime.document_state_wakeup_ = wakeup
	if runtime.document_state_dirty_ {
		if callback := wakeup { callback() }
	}
}

pub fn (mut runtime Runtime) mark_document_state_dirty() {
	if runtime.closed || runtime.document_state_dirty_ { return }
	runtime.document_state_dirty_ = true
	if wakeup := runtime.document_state_wakeup_ { wakeup() }
}

pub fn (runtime &Runtime) has_pending_document_state() bool {
	return runtime.document_state_dirty_
}

pub fn (mut runtime Runtime) take_document_state_dirty() bool {
	dirty := runtime.document_state_dirty_
	runtime.document_state_dirty_ = false
	return dirty
}

// A callback can need host synchronization without changing its document.
// Keep real compact replay effects separate, including effects flushed by a
// synchronous DOM query before the callback returns.
pub fn (mut runtime Runtime) mark_document_replay_effects() {
	runtime.document_replay_effects_pending_ = true
}

pub fn (mut runtime Runtime) take_document_replay_effects() bool {
	pending := runtime.document_replay_effects_pending_
	runtime.document_replay_effects_pending_ = false
	return pending
}

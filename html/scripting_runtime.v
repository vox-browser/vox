// Copyright (c) 2021-2024, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Scripting/{Script,ClassicScript,ModuleScript,
// TemporaryExecutionContext,SyntheticRealmSettings,ExceptionReporter}.{h,cpp}.
// JavaScript parsing and evaluation are host callbacks because libweb_v does
// not embed LibJS; the HTML lifecycle and error-handling algorithms remain here.
module html

import dom
import libjs
import webidl

pub enum ErrorInPromise {
	no
	yes
}

pub enum MutedErrors {
	no
	yes
}

pub enum RethrowErrors {
	no
	yes
}

pub enum PreventErrorReporting {
	no
	yes
}

pub enum CallbacksEnabled {
	no
	yes
}

pub struct ReportedScriptException {
pub:
	value            dom.JSValue
	error_in_promise ErrorInPromise
}

pub type ScriptEvaluationHook = fn(string, &ScriptingRealm) !dom.JSValue

pub type ScriptParseHook = fn(string, string, uint) !

pub struct ScriptSourceLocation {
pub:
	url string
	line u32
	column u32
}

pub type ScriptElementEvaluator = fn (ScriptElementType, string, string, int, ?&dom.Element) !

@[heap]
pub struct ScriptingRealm {
pub mut:
	scripting_enabled                       bool = true
	can_run                                 bool = true
	settings_handle                         voidptr
	script_execution_depth                  uint
	callback_execution_depth                uint
	microtask_checkpoint_count              uint
	reported_exceptions                     []ReportedScriptException
	principal_realm_                        ?&ScriptingRealm
	host_defined_handle                     voidptr
	global_object_handle                    voidptr
	module_map_                             ?&ModuleMap
	skip_when_determining_incumbent_counter uint
	active_classic_script_                  ?&ClassicScript
	error_extraction_context_               ?fn (dom.JSValue) ErrorExtractionContext
	current_source_location_                ?fn () ?ScriptSourceLocation
	evaluate_script_element_ ?ScriptElementEvaluator
mut:
	embedding_vm_                            ?&libjs.VM
	embedding_realm_execution_context_       ?&libjs.ExecutionContext
}

// MainThreadVM.cpp gives settings ownership of the actual initialized realm
// context after popping it from the VM. Host-backed execution preserves that
// same record instead of constructing surrogate JavaScript call frames.
pub fn (mut realm ScriptingRealm) bind_embedding_execution_context(vm &libjs.VM, context &libjs.ExecutionContext) {
	realm.embedding_vm_ = vm
	realm.embedding_realm_execution_context_ = context
}

pub fn prepare_to_run_script(mut realm ScriptingRealm) {
	if vm_pointer := realm.embedding_vm_ {
		mut vm := unsafe { &libjs.VM(vm_pointer) }
		mut context := realm.embedding_realm_execution_context_ or { panic('missing owning realm execution context') }
		vm.push_execution_context(mut context)
	}
	realm.script_execution_depth++
	html_scripting_execution_context_stack << &realm
}

pub fn clean_up_after_running_script(mut realm ScriptingRealm) {
	assert html_scripting_execution_context_stack.len > 0
	assert voidptr(html_scripting_execution_context_stack.last()) == voidptr(&realm)
	if vm_pointer := realm.embedding_vm_ {
		mut vm := unsafe { &libjs.VM(vm_pointer) }
		context := realm.embedding_realm_execution_context_ or { panic('missing owning realm execution context') }
		assert vm.has_running_execution_context()
		assert voidptr(vm.running_execution_context()) == voidptr(context)
		vm.pop_execution_context()
	}
	html_scripting_execution_context_stack.delete_last()
	if realm.script_execution_depth > 0 {
		realm.script_execution_depth--
	}
	if html_scripting_execution_context_stack.len == 0 {
		mut event_loop := main_thread_event_loop()
		if settings := settings_object_of_realm(&realm) {
			event_loop = unsafe { &EventLoop(settings.responsible_event_loop()) }
		}
		// The compact engine's script frame is popped by its execution entry
		// before this realm cleanup. A caller's actual outer VM context must
		// likewise keep the source checkpoint deferred.
		if event_loop.has_running_execution_context() {
			return
		}
		realm.microtask_checkpoint_count++
		event_loop.perform_a_microtask_checkpoint()
	}
}

pub fn prepare_to_run_callback(mut realm ScriptingRealm) {
	realm.callback_execution_depth++
	mut event_loop := main_thread_event_loop()
	event_loop.push_onto_backup_incumbent_realm_stack(&realm)
	if mut context := top_most_script_having_execution_context() {
		context.skip_when_determining_incumbent_counter++
	}
}

pub fn clean_up_after_running_callback(mut realm ScriptingRealm) {
	if mut context := top_most_script_having_execution_context() {
		assert context.skip_when_determining_incumbent_counter > 0
		context.skip_when_determining_incumbent_counter--
	}
	mut event_loop := main_thread_event_loop()
	assert !event_loop.is_backup_incumbent_realm_stack_empty()
	assert voidptr(event_loop.top_of_backup_incumbent_realm_stack()) == voidptr(&realm)
	event_loop.pop_backup_incumbent_realm_stack()
	if realm.callback_execution_depth > 0 {
		realm.callback_execution_depth--
	}
}

pub fn report_exception_to_console(value dom.JSValue, mut realm ScriptingRealm, error_in_promise ErrorInPromise) {
	realm.reported_exceptions << ReportedScriptException{value, error_in_promise}
}

pub fn report_exception(value dom.JSValue, mut realm ScriptingRealm) {
	report_exception_to_console(value, mut realm, .no)
}

@[heap]
pub struct TemporaryExecutionContext {
pub:
	realm             &ScriptingRealm
	callbacks_enabled CallbacksEnabled
mut:
	closed bool
}

pub fn TemporaryExecutionContext.create(mut realm ScriptingRealm, callbacks_enabled CallbacksEnabled) &TemporaryExecutionContext {
	prepare_to_run_script(mut realm)
	if callbacks_enabled == .yes {
		prepare_to_run_callback(mut realm)
	}
	return &TemporaryExecutionContext{
		realm: &realm
		callbacks_enabled: callbacks_enabled
	}
}

pub fn (mut context TemporaryExecutionContext) close() {
	if context.closed {
		return
	}
	mut realm := context.realm
	// The source destructor checkpoints script cleanup while the callback's
	// backup incumbent realm remains installed, then cleans up that callback.
	clean_up_after_running_script(mut realm)
	if context.callbacks_enabled == .yes {
		clean_up_after_running_callback(mut realm)
	}
	context.closed = true
}

pub struct SyntheticRealmSettings {
pub:
	execution_context voidptr
	principal_realm   &ScriptingRealm
	module_map        &ModuleMap
}

@[heap]
pub struct Script {
pub:
	base_url ?dom.URL
	filename string
	realm    &ScriptingRealm
pub mut:
	parse_error      ?string
	error_to_rethrow ?string
}

pub fn (script &Script) settings_object() &ScriptingRealm {
	return script.realm
}

pub fn (script &Script) base_url() ?dom.URL {
	return script.base_url
}

pub fn (script &Script) filename() string {
	return script.filename
}

pub fn (script &Script) realm() &ScriptingRealm {
	return script.realm
}

pub fn (script &Script) error_to_rethrow() ?string {
	return script.error_to_rethrow
}

pub fn (mut script Script) set_error_to_rethrow(value ?string) {
	script.error_to_rethrow = value
}

pub fn (script &Script) parse_error() ?string {
	return script.parse_error
}

pub fn (mut script Script) set_parse_error(value ?string) {
	script.parse_error = value
}

pub fn (script &Script) is_script() bool {
	_ = script
	return true
}

pub fn (script &Script) visit_host_defined_self(mut visitor dom.CellVisitor) {
	visitor.visit(voidptr(script))
}

@[heap]
pub struct ClassicScript {
	Script
pub:
	source             string
	source_line_number uint
	compiled_program   ?CompiledProgram
pub mut:
	muted_errors MutedErrors
	evaluator    ?ScriptEvaluationHook
}

pub fn ClassicScript.create(filename string, source string, realm &ScriptingRealm, base_url dom.URL, source_line_number uint, muted_errors MutedErrors) &ClassicScript {
	actual_source := if is_scripting_enabled(realm) { source } else { '' }
	return create_classic_script_record(filename, actual_source, realm, base_url, source_line_number, muted_errors)
}

// Source's pre-parsed and compiled constructors retain their existing source;
// disabled-source substitution belongs only to ClassicScript::create.
fn create_classic_script_record(filename string, source string, realm &ScriptingRealm, base_url dom.URL, source_line_number uint, muted_errors MutedErrors) &ClassicScript {
	actual_url := if muted_errors == .yes { dom.url_about_blank() } else { base_url }
	return &ClassicScript{
		Script: Script{
			base_url: actual_url
			filename: filename
			realm: realm
		}
		source: source
		source_line_number: source_line_number
		muted_errors: muted_errors
	}
}

pub fn ClassicScript.create_with_parser(filename string, source string, realm &ScriptingRealm, base_url dom.URL, source_line_number uint, muted_errors MutedErrors, parser ScriptParseHook) &ClassicScript {
	mut script := ClassicScript.create(filename, source, realm, base_url, source_line_number, muted_errors)
	parser(script.source, filename, source_line_number) or {
		script.parse_error = err.msg()
		script.error_to_rethrow = err.msg()
	}
	return script
}

pub fn ClassicScript.create_from_pre_parsed(filename string, source_code string, realm &ScriptingRealm, base_url dom.URL, parsed ScriptParseHook, muted_errors MutedErrors) &ClassicScript {
	mut script := create_classic_script_record(filename, source_code, realm, base_url, 1, muted_errors)
	parsed(script.source, filename, 1) or {
		script.parse_error = err.msg()
		script.error_to_rethrow = err.msg()
	}
	return script
}

pub fn ClassicScript.create_from_parsed_program(filename string, source_code string, realm &ScriptingRealm, base_url dom.URL, parsed ParsedProgram, muted_errors MutedErrors) &ClassicScript {
	mut script := create_classic_script_record(filename, source_code, realm, base_url, 1, muted_errors)
	if parse_error := parsed.error {
		script.parse_error = parse_error
		script.error_to_rethrow = parse_error
	}
	return script
}

pub fn ClassicScript.create_from_pre_compiled(filename string, source_code string, realm &ScriptingRealm, base_url dom.URL, compiled CompiledProgram, muted_errors MutedErrors) &ClassicScript {
	actual_url := if muted_errors == .yes { dom.url_about_blank() } else { base_url }
	return &ClassicScript{
		Script: Script{
			base_url: actual_url
			filename: filename
			realm: realm
		}
		source: source_code
		source_line_number: 1
		compiled_program: compiled
		muted_errors: muted_errors
	}
}

pub fn ClassicScript.create_from_bytecode_cache(filename string, source_code string, realm &ScriptingRealm, base_url dom.URL, bytecode_cache []u8, materializer ScriptBytecodeCacheMaterializeHook, muted_errors MutedErrors) &ClassicScript {
	executable := materializer(bytecode_cache, source_code, filename, 1, .script) or {
		mut script := create_classic_script_record(filename, source_code, realm, base_url, 1, muted_errors)
		script.parse_error = err.msg()
		script.error_to_rethrow = err.msg()
		return script
	}
	return ClassicScript.create_from_pre_compiled(filename, source_code, realm, base_url, CompiledProgram{
		program_type: .script
		line_number_offset: 1
		executable: executable
	}, muted_errors)
}

pub fn (mut script ClassicScript) set_evaluator(evaluator ScriptEvaluationHook) {
	script.evaluator = evaluator
}

// LibJS script/source-text-module records are represented by successfully
// parsed source in this runtime-neutral port.
pub fn (script &ClassicScript) script_record() ?string {
	if script.parse_error != none {
		return none
	}
	return script.source
}

pub fn (script &ClassicScript) muted_errors() MutedErrors {
	return script.muted_errors
}

pub fn (script &ClassicScript) is_classic_script() bool {
	return true
}

fn report_classic_script_exception(value dom.JSValue, mut realm ScriptingRealm) {
	if settings := settings_object_of_realm(&realm) {
		if mut scope := settings.window_or_worker_global_scope() {
			scope.report_an_exception(value, false)
			return
		}
	}
	report_exception(value, mut realm)
}

pub fn (mut script ClassicScript) run(rethrow_errors RethrowErrors) !dom.JSValue {
	mut realm := script.realm
	if can_run_script(realm) == .do_not_run {
		return dom.js_undefined()
	}
	previous_script := realm.active_classic_script_
	realm.active_classic_script_ = &script
	defer { realm.active_classic_script_ = previous_script }
	prepare_to_run_script(mut realm)
	if stored_error := script.error_to_rethrow {
		if rethrow_errors == .yes && script.muted_errors == .yes {
			clean_up_after_running_script(mut realm)
			return error('NetworkError: Script error.')
		}
		if rethrow_errors == .no {
			report_classic_script_exception(dom.js_string(stored_error), mut realm)
		}
		clean_up_after_running_script(mut realm)
		return error(stored_error)
	}
	evaluator := script.evaluator or {
		clean_up_after_running_script(mut realm)
		return dom.js_undefined()
	}

	result := evaluator(script.source, realm) or {
		if rethrow_errors == .yes {
			clean_up_after_running_script(mut realm)
			if script.muted_errors == .yes {
				return error('NetworkError: Script error.')
			}
			return err
		}
		report_classic_script_exception(dom.js_webidl_value(webidl.exception_value(err)), mut realm)
		clean_up_after_running_script(mut realm)
		return err
	}
	clean_up_after_running_script(mut realm)
	return result
}

pub enum ModuleEvaluationState {
	fulfilled
	rejected
}

pub struct ModuleEvaluation {
pub:
	state ModuleEvaluationState
	value dom.JSValue
	error string
}

@[heap]
pub struct ModuleScript {
	Script
pub:
	kind             ModuleScriptKind = .javascript
	synthetic_source string
}

pub enum ModuleScriptKind {
	javascript
	css
	json
	text
}

pub fn ModuleScript.create_synthetic(filename string, source string, realm &ScriptingRealm, kind ModuleScriptKind) &ModuleScript {
	return &ModuleScript{
		Script: Script{
			filename: filename
			realm: realm
		}
		kind: kind
		synthetic_source: source
	}
}

// Text modules are synthetic modules with exactly one string-valued default export.
// https://tc39.es/proposal-import-text/#sec-create-text-module
pub fn (script &ModuleScript) synthetic_default_export() ?dom.JSValue {
	if script.kind != .text {
		return none
	}
	return dom.js_string(script.synthetic_source)
}

pub fn (script &ModuleScript) synthetic_export_names() []string {
	if script.kind != .text {
		return []
	}
	return ['default']
}

pub fn (script &ModuleScript) is_module_script() bool {
	_ = script
	return true
}

@[heap]
pub struct JavaScriptModuleScript {
	ModuleScript
pub:
	source           string
	compiled_program ?CompiledProgram
pub mut:
	evaluator         ?ScriptEvaluationHook
	requested_modules []ModuleRequest
	linked            bool
}

pub fn JavaScriptModuleScript.create(filename string, source string, realm &ScriptingRealm, base_url dom.URL) &JavaScriptModuleScript {
	actual_source := if is_scripting_enabled(realm) { source } else { '' }
	return create_javascript_module_script_record(filename, actual_source, realm, base_url)
}

// ModuleScript.cpp's pre-parsed/compiled/cache paths retain their source code.
fn create_javascript_module_script_record(filename string, source string, realm &ScriptingRealm, base_url dom.URL) &JavaScriptModuleScript {
	return &JavaScriptModuleScript{
		ModuleScript: ModuleScript{
			Script: Script{
				base_url: base_url
				filename: filename
				realm: realm
			}
			kind: .javascript
		}
		source: source
		requested_modules: parse_module_requests(source)
	}
}

pub fn JavaScriptModuleScript.create_from_pre_parsed(filename string, source_code string, realm &ScriptingRealm, base_url dom.URL, parsed ScriptParseHook) &JavaScriptModuleScript {
	mut script := create_javascript_module_script_record(filename, source_code, realm, base_url)
	parsed(script.source, filename, 1) or {
		script.parse_error = err.msg()
	}
	return script
}

pub fn JavaScriptModuleScript.create_from_parsed_program(filename string, source_code string, realm &ScriptingRealm, base_url dom.URL, parsed ParsedProgram) &JavaScriptModuleScript {
	mut script := create_javascript_module_script_record(filename, source_code, realm, base_url)
	if parse_error := parsed.error {
		script.parse_error = parse_error
	}
	return script
}

pub fn JavaScriptModuleScript.create_from_pre_compiled(filename string, source_code string, realm &ScriptingRealm, base_url dom.URL, compiled CompiledProgram) &JavaScriptModuleScript {
	return &JavaScriptModuleScript{
		ModuleScript: ModuleScript{
			Script: Script{
				base_url: base_url
				filename: filename
				realm: realm
			}
			kind: .javascript
		}
		source: source_code
		compiled_program: compiled
		requested_modules: parse_module_requests(source_code)
	}
}

pub fn JavaScriptModuleScript.create_from_bytecode_cache(filename string, source_code string, realm &ScriptingRealm, base_url dom.URL, bytecode_cache []u8, materializer ScriptBytecodeCacheMaterializeHook) &JavaScriptModuleScript {
	executable := materializer(bytecode_cache, source_code, filename, 0, .module) or {
		mut script := create_javascript_module_script_record(filename, source_code, realm, base_url)
		script.parse_error = err.msg()
		return script
	}
	return JavaScriptModuleScript.create_from_pre_compiled(filename, source_code, realm, base_url, CompiledProgram{
		program_type: .module
		line_number_offset: 0
		executable: executable
	})
}

pub fn (mut script JavaScriptModuleScript) set_evaluator(evaluator ScriptEvaluationHook) {
	script.evaluator = evaluator
}

pub fn (script &JavaScriptModuleScript) record() ?string {
	if script.parse_error != none {
		return none
	}
	return script.source
}

pub fn (script &JavaScriptModuleScript) is_javascript_module_script() bool {
	return true
}

pub fn (script &JavaScriptModuleScript) requested_modules() []ModuleRequest {
	return script.requested_modules.clone()
}

pub fn (script &JavaScriptModuleScript) is_linked() bool {
	return script.linked
}

pub fn (mut script JavaScriptModuleScript) run(prevent_error_reporting PreventErrorReporting) ModuleEvaluation {
	mut realm := script.realm
	if can_run_script(realm) == .do_not_run {
		return ModuleEvaluation{
			state: .fulfilled
			value: dom.js_undefined()
		}
	}
	prepare_to_run_script(mut realm)
	if stored_error := script.error_to_rethrow {
		if prevent_error_reporting == .no {
			report_exception_to_console(dom.js_string(stored_error), mut realm, .yes)
		}
		clean_up_after_running_script(mut realm)
		return ModuleEvaluation{
			state: .rejected
			value: dom.js_undefined()
			error: stored_error
		}
	}
	evaluator := script.evaluator or {
		clean_up_after_running_script(mut realm)
		return ModuleEvaluation{
			state: .fulfilled
			value: dom.js_undefined()
		}
	}

	value := evaluator(script.source, realm) or {
		if prevent_error_reporting == .no {
			report_exception_to_console(dom.js_string(err.msg()), mut realm, .yes)
		}
		clean_up_after_running_script(mut realm)
		return ModuleEvaluation{
			state: .rejected
			value: dom.js_undefined()
			error: err.msg()
		}
	}
	clean_up_after_running_script(mut realm)
	return ModuleEvaluation{
		state: .fulfilled
		value: value
	}
}

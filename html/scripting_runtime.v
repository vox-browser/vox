// Copyright (c) 2021-2024, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Scripting/{Script,ClassicScript,ModuleScript,
// TemporaryExecutionContext,SyntheticRealmSettings,ExceptionReporter}.{h,cpp}.
// JavaScript parsing and evaluation are host callbacks because libweb_v does
// not embed LibJS; the HTML lifecycle and error-handling algorithms remain here.
module html

import dom

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

pub type ScriptEvaluationHook = fn (string, &ScriptingRealm) !dom.JSValue

pub type ScriptParseHook = fn (string, string, usize) !

@[heap]
pub struct ScriptingRealm {
pub mut:
	scripting_enabled          bool = true
	can_run                    bool = true
	settings_handle            voidptr
	script_execution_depth     usize
	callback_execution_depth   usize
	microtask_checkpoint_count usize
	reported_exceptions        []ReportedScriptException
}

pub fn prepare_to_run_script(mut realm ScriptingRealm) {
	realm.script_execution_depth++
}

pub fn clean_up_after_running_script(mut realm ScriptingRealm) {
	if realm.script_execution_depth > 0 {
		realm.script_execution_depth--
	}
	if realm.script_execution_depth == 0 {
		realm.microtask_checkpoint_count++
	}
}

pub fn prepare_to_run_callback(mut realm ScriptingRealm) {
	realm.callback_execution_depth++
}

pub fn clean_up_after_running_callback(mut realm ScriptingRealm) {
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
		realm:             &realm
		callbacks_enabled: callbacks_enabled
	}
}

pub fn (mut context TemporaryExecutionContext) close() {
	if context.closed {
		return
	}
	mut realm := context.realm
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

@[heap]
pub struct ClassicScript {
	Script
pub:
	source             string
	source_line_number usize
pub mut:
	muted_errors MutedErrors
	evaluator    ?ScriptEvaluationHook
}

pub fn ClassicScript.create(filename string, source string, realm &ScriptingRealm, base_url dom.URL, source_line_number usize, muted_errors MutedErrors) &ClassicScript {
	actual_url := if muted_errors == .yes { dom.url_about_blank() } else { base_url }
	actual_source := if realm.scripting_enabled { source } else { '' }
	return &ClassicScript{
		Script:             Script{
			base_url: actual_url
			filename: filename
			realm:    realm
		}
		source:             actual_source
		source_line_number: source_line_number
		muted_errors:       muted_errors
	}
}

pub fn ClassicScript.create_with_parser(filename string, source string, realm &ScriptingRealm, base_url dom.URL, source_line_number usize, muted_errors MutedErrors, parser ScriptParseHook) &ClassicScript {
	mut script := ClassicScript.create(filename, source, realm, base_url, source_line_number,
		muted_errors)
	parser(script.source, filename, source_line_number) or {
		script.parse_error = err.msg()
		script.error_to_rethrow = err.msg()
	}
	return script
}

pub fn (mut script ClassicScript) set_evaluator(evaluator ScriptEvaluationHook) {
	script.evaluator = evaluator
}

pub fn (mut script ClassicScript) run(rethrow_errors RethrowErrors) !dom.JSValue {
	mut realm := script.realm
	if !realm.can_run {
		return dom.js_undefined()
	}
	prepare_to_run_script(mut realm)
	if stored_error := script.error_to_rethrow {
		clean_up_after_running_script(mut realm)
		if rethrow_errors == .yes && script.muted_errors == .yes {
			return error('NetworkError: Script error.')
		}
		if rethrow_errors == .no {
			report_exception(dom.js_string(stored_error), mut realm)
		}
		return error(stored_error)
	}
	evaluator := script.evaluator or {
		clean_up_after_running_script(mut realm)
		return dom.js_undefined()
	}

	result := evaluator(script.source, realm) or {
		clean_up_after_running_script(mut realm)
		if rethrow_errors == .yes {
			if script.muted_errors == .yes {
				return error('NetworkError: Script error.')
			}
			return err
		}
		report_exception(dom.js_string(err.msg()), mut realm)
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
}

@[heap]
pub struct JavaScriptModuleScript {
	ModuleScript
pub:
	source string
pub mut:
	evaluator ?ScriptEvaluationHook
}

pub fn JavaScriptModuleScript.create(filename string, source string, realm &ScriptingRealm, base_url dom.URL) &JavaScriptModuleScript {
	actual_source := if realm.scripting_enabled { source } else { '' }
	return &JavaScriptModuleScript{
		ModuleScript: ModuleScript{
			Script: Script{
				base_url: base_url
				filename: filename
				realm:    realm
			}
		}
		source:       actual_source
	}
}

pub fn (mut script JavaScriptModuleScript) set_evaluator(evaluator ScriptEvaluationHook) {
	script.evaluator = evaluator
}

pub fn (mut script JavaScriptModuleScript) run(prevent_error_reporting PreventErrorReporting) ModuleEvaluation {
	mut realm := script.realm
	if !realm.can_run {
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

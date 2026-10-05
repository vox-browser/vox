module html

import dom
import webidl

@[heap]
struct TimerSourceTaskObservation {
mut:
	bases []string
}

fn timer_source_task_window() &WindowModel {
	url := dom.URL{value: 'https://source-timer.example.test/document.html'}
	document := &dom.Document{url: url, origin_: url.origin()}
	return WindowModel.create_top_level(document, none, '') or { panic(err) }
}

fn test_timer_webidl_callback_receives_original_this_arguments_and_reports_original_throw() {
	window := timer_source_task_window()
	mut scope := window.window_or_worker_global_scope()
	realm := window.scripting_realm_
	original := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('OperationError', 'actual timer callback exception'))
	receiver := webidl.platform_object_value_with_id(u64(voidptr(window)))
	callback := webidl.CallbackType{
		callback: fn [receiver, original, realm] (actual_this webidl.Value, arguments []webidl.Value) !webidl.Value {
			assert realm.script_execution_depth > 0 && realm.callback_execution_depth > 0
			assert actual_this.opaque_id == receiver.opaque_id
			assert arguments.len == 1 && arguments[0].opaque_id == original.opaque_id
			return webidl.throw_value(original)
		}
	}
	scope.set_timeout(timer_webidl_callback_handler(callback, receiver), 0, [dom.js_webidl_value(original)])
	scope.run_all_timers()
	assert scope.active_timer_count() == 0
	assert realm.script_execution_depth == 0 && realm.callback_execution_depth == 0
	assert scope.reported_errors().len == 1
	assert scope.reported_errors()[0].as_webidl_value()!.opaque_id == original.opaque_id
}

fn test_string_timer_creates_source_classic_script_with_initiating_script_base_url() {
	window := timer_source_task_window()
	mut scope := window.window_or_worker_global_scope()
	realm := window.scripting_realm_
	observation := &TimerSourceTaskObservation{}
	scope.set_timer_classic_script_evaluator(fn [observation] (source string, realm &ScriptingRealm) !dom.JSValue {
		assert source == 'actual timer source'
		assert realm.script_execution_depth > 0
		script := realm.active_classic_script_ or { panic('missing actual ClassicScript') }
		mut recorded := unsafe { &TimerSourceTaskObservation(observation) }
		recorded.bases << (script.base_url() or { panic('missing source base URL') }).serialize()
		return dom.js_undefined()
	})
	url := dom.URL{value: 'https://source-timer.example.test/initiating/script.js'}
	mut initiating := ClassicScript.create('script.js', 'schedule timer', realm, url, 1, .no)
	owner_handle := voidptr(scope)
	initiating.set_evaluator(fn [owner_handle] (_ string, _ &ScriptingRealm) !dom.JSValue {
		mut owner := unsafe { &WindowOrWorkerGlobalScopeMixin(owner_handle) }
		owner.set_timeout(timer_source_handler('actual timer source'), 0, [])
		return dom.js_undefined()
	})
	initiating.run(.no)!
	scope.run_all_timers()
	assert observation.bases == [url.serialize()]
	assert realm.active_classic_script_ == none
	assert scope.active_timer_count() == 0
}

fn test_string_timer_checks_current_csp_before_classic_script_and_preserves_source_abort_step() {
	window := timer_source_task_window()
	mut scope := window.window_or_worker_global_scope()
	mut settings := window.environment_settings_.settings
	observation := &TimerSourceTaskObservation{}
	scope.set_timer_classic_script_evaluator(fn [observation] (_ string, _ &ScriptingRealm) !dom.JSValue {
		mut recorded := unsafe { &TimerSourceTaskObservation(observation) }
		recorded.bases << 'executed'
		return dom.js_undefined()
	})
	id := scope.set_timeout(timer_source_handler('blocked timer source'), 0, [])
	settings.set_policy_container(&PolicyContainer{csp_list: [parse_response_csp_policy("script-src 'self'", .enforce, settings.origin())]})
	scope.run_all_timers()
	assert observation.bases.len == 0
	assert scope.reported_errors().len == 1
	reported := scope.reported_errors()[0].as_webidl_value()!
	assert reported.kind == .string_
	assert reported.string_value == 'EvalError: Blocked by Content Security Policy'
	// Source string-compilation failure aborts the task before map removal.
	assert id in scope.active_timers_
	scope.clear_timeout(id)
	settings.set_policy_container(&PolicyContainer{csp_list: [parse_response_csp_policy("script-src 'self'", .report, settings.origin())]})
	scope.set_timeout(timer_source_handler('report-only timer source'), 0, [])
	scope.run_all_timers()
	assert observation.bases == ['executed']
	assert scope.active_timer_count() == 0
}

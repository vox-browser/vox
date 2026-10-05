module html

import dom
import webidl

@[heap]
struct ClassicScriptReportObservation {
mut:
	events int
}

fn test_classic_script_reports_original_value_before_cleaning_owning_script_context() {
	url := dom.URL{value: 'https://timer-script.example.test/document.html'}
	document := &dom.Document{url: url, origin_: url.origin()}
	window := WindowModel.create_top_level(document, none, '')!
	mut scope := window.window_or_worker_global_scope()
	mut realm := unsafe { &ScriptingRealm(window.scripting_realm_) }
	original := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('OperationError', 'actual script completion'))
	observation := &ClassicScriptReportObservation{}
	window.add_event_listener_without_options('error', dom.IDLEventListener.new(&dom.CallbackType{
		handle_event: fn [realm, original, observation] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert realm.script_execution_depth == 1
			assert realm.active_classic_script_ != none
			actual := unsafe { &dom.ErrorEvent(event) }.error().as_webidl_value() or { panic('missing actual thrown value') }
			assert actual.opaque_id == original.opaque_id
			mut recorded := unsafe { &ClassicScriptReportObservation(observation) }
			recorded.events++
			return dom.js_undefined()
		}
	}))
	mut script := ClassicScript.create('timer.js', 'throw original', realm, url, 1, .no)
	script.set_evaluator(fn [original] (_ string, _ &ScriptingRealm) !dom.JSValue { return webidl.throw_value(original) })
	if _ := script.run(.no) { assert false } else {
		assert webidl.exception_value(err).opaque_id == original.opaque_id
	}
	assert realm.script_execution_depth == 0
	assert realm.active_classic_script_ == none
	assert observation.events == 1
	assert realm.reported_exceptions.len == 1
	assert realm.reported_exceptions[0].value.as_webidl_value()!.opaque_id == original.opaque_id
	assert scope.reported_errors().len == 1
	assert scope.reported_errors()[0].as_webidl_value()!.opaque_id == original.opaque_id
}

fn test_classic_script_rethrow_preserves_original_value_without_reporting() {
	mut realm := &ScriptingRealm{}
	original := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('OperationError', 'rethrown completion'))
	mut script := ClassicScript.create('timer.js', 'throw original', realm, dom.url_about_blank(), 1, .no)
	script.set_evaluator(fn [original] (_ string, _ &ScriptingRealm) !dom.JSValue { return webidl.throw_value(original) })
	if _ := script.run(.yes) { assert false } else {
		assert webidl.exception_value(err).opaque_id == original.opaque_id
	}
	assert realm.script_execution_depth == 0
	assert realm.reported_exceptions.len == 0
}

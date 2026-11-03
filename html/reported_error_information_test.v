module html

import dom
import platform

fn test_reported_error_information_is_a_retained_snapshot_without_reextraction() {
	mut document := dom.Document.create(dom.URL{value: 'https://errors.test/'})
	defer { document.finalize() }
	window := WindowModel.create_top_level(document, none, 'report-info')!
	mut realm := window.environment_settings_.settings.realm()
	mut calls := &ReportedInformationCalls{}
	realm.error_extraction_context_ = fn [mut calls] (_ dom.JSValue) ErrorExtractionContext {
		calls.count++
		return ErrorExtractionContext{own_message: 'retained message ${calls.count}', exception_is_error: true,
			traceback: [ErrorSourceLocation{filename: 'source-${calls.count}.js', line: 7, column: 11}]}
	}
	mut scope := window.window_or_worker_global_scope()
	mut scratch := platform.begin_thread_scratch('reported error metadata')
	scope.report_error(dom.js_string('original thrown value'))
	scratch.finish()
	gc_collect()
	assert scope.reported_error_count() == 1
	assert calls.count == 1
	mut first := scope.reported_error_information()
	assert first.len == 1
	assert first[0].message == 'retained message 1'
	assert first[0].filename == 'source-1.js'
	assert first[0].lineno == 7 && first[0].colno == 11
	first[0] = ReportedErrorInformation{message: 'caller replaced its snapshot'}
	assert scope.reported_error_information()[0].message == 'retained message 1'
	scope.report_error(dom.js_string('second thrown value'))
	assert scope.reported_error_count() == scope.reported_error_information().len
	assert scope.reported_error_information()[1].message == 'retained message 2'
	assert calls.count == 2
	assert scope.reported_errors()[0].string_data == 'original thrown value'
}

@[heap]
struct ReportedInformationCalls {
mut:
	count int
}

fn test_reported_error_information_preserves_cancellation_recursion_and_muting() {
	mut document := dom.Document.create(dom.URL{value: 'https://errors.test/'})
	defer { document.finalize() }
	window := WindowModel.create_top_level(document, none, 'report-order')!
	mut scope := window.window_or_worker_global_scope()
	mut realm := window.environment_settings_.settings.realm()
	mut listener := &ReportedInformationListener{scope: scope}
	window.set_event_handler_attribute('error', &dom.CallbackType{handle_event: fn [mut listener] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
		if listener.recurse {
			listener.scope.report_error(dom.js_string('nested'))
			mut mutable_event := unsafe { &dom.Event(event) }
			mutable_event.prevent_default()
		}
		return dom.js_undefined()
	}})
	scope.report_error(dom.js_string('cancelled outer'))
	assert scope.reported_error_count() == 1
	assert scope.reported_error_information()[0].message == 'Uncaught exception: nested'
	listener.recurse = false
	mut script := ClassicScript.create('secret.js', 'report', realm, dom.URL{value: 'https://other.test/secret.js'}, 1, .yes)
	script.set_evaluator(fn [mut scope] (_ string, _ &ScriptingRealm) !dom.JSValue {
		scope.report_an_exception(dom.js_string('private details'), true)
		return dom.js_undefined()
	})
	script.run(.no)!
	information := scope.reported_error_information()
	assert information.len == 2 && scope.reported_error_count() == 2
	assert information[1].message == 'Script error.'
	assert information[1].filename == '' && information[1].lineno == 0 && information[1].colno == 0
	assert scope.reported_errors()[1].string_data == 'private details'
}

@[heap]
struct ReportedInformationListener {
mut:
	scope &WindowOrWorkerGlobalScopeMixin
	recurse bool = true
}

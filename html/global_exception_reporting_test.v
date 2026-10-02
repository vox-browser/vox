module html

import dom
import page

@[heap]
struct GlobalErrorRecorder {
mut:
	events []&dom.ErrorEvent
	cancel bool
	recurse bool
	scope &WindowOrWorkerGlobalScopeMixin = unsafe { nil }
}

fn global_error_window() (&WindowModel, &ScriptingRealm) {
	document := dom.Document.create(dom.URL{value: 'https://exception.example/page'})
	window := WindowModel.create_top_level(document, none, 'exception-reporting') or { panic(err) }
	realm := window.environment_settings_.settings.realm()
	return window, realm
}

fn global_error_listener(recorder &GlobalErrorRecorder) &dom.CallbackType {
	return &dom.CallbackType{
		handle_event: fn [recorder] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert dom.event_is_error_event(event)
			assert event.cancelable()
			mut state := unsafe { &GlobalErrorRecorder(recorder) }
			state.events << unsafe { &dom.ErrorEvent(event) }
			if state.recurse {
				mut scope := state.scope
				scope.report_error(dom.js_string('nested'))
			}
			if state.cancel {
				mut mutable_event := unsafe { &dom.Event(event) }
				mutable_event.prevent_default()
			}
			return dom.js_undefined()
		}
	}
}

fn test_global_report_error_dispatches_error_event_with_metadata_and_omit_error_only_clears_value() {
	window, realm_pointer := global_error_window()
	mut realm := unsafe { &ScriptingRealm(realm_pointer) }
	realm.error_extraction_context_ = fn (_ dom.JSValue) ErrorExtractionContext {
		return ErrorExtractionContext{
			own_message: 'broken'
			exception_is_error: true
			traceback: [ErrorSourceLocation{filename: 'app.js', line: 12, column: 7}]
		}
	}
	mut scope := window.window_or_worker_global_scope()
	recorder := &GlobalErrorRecorder{scope: scope}
	window.set_event_handler_attribute('error', global_error_listener(recorder))
	exception := dom.js_object(voidptr(recorder))
	scope.report_an_exception(exception, false)
	scope.report_an_exception(exception, true)
	assert recorder.events.len == 2
	for event in recorder.events {
		assert event.message() == 'broken'
		assert event.filename() == 'app.js'
		assert event.lineno() == 12
		assert event.colno() == 7
		assert event.target() or { panic('missing target') } == unsafe { &dom.EventTarget(window) }
	}
	assert recorder.events[0].error().object_data == exception.object_data
	assert recorder.events[1].error().kind == .null_
	assert scope.reported_errors().len == 2
	assert realm.reported_exceptions.len == 2
}

fn test_cancelled_error_suppresses_console_and_recursive_report_still_reaches_console() {
	window, realm := global_error_window()
	mut scope := window.window_or_worker_global_scope()
	mut recorder := &GlobalErrorRecorder{scope: scope, cancel: true}
	window.set_event_handler_attribute('error', global_error_listener(recorder))
	scope.report_error(dom.js_string('handled'))
	assert recorder.events.len == 1
	assert scope.reported_errors().len == 0
	assert realm.reported_exceptions.len == 0
	recorder.recurse = true
	scope.report_error(dom.js_string('outer'))
	assert recorder.events.len == 2
	assert scope.reported_errors().len == 1
	assert scope.reported_errors()[0].string_data == 'nested'
	assert realm.reported_exceptions.len == 1
	assert realm.reported_exceptions[0].value.string_data == 'nested'
	assert !scope.error_reporting_mode_
}

fn test_active_muted_classic_script_hides_error_fields_and_restores_script_after_run() {
	window, realm_pointer := global_error_window()
	mut realm := unsafe { &ScriptingRealm(realm_pointer) }
	mut scope := window.window_or_worker_global_scope()
	recorder := &GlobalErrorRecorder{scope: scope}
	window.set_event_handler_attribute('error', global_error_listener(recorder))
	mut script := ClassicScript.create('secret.js', 'report', realm, dom.URL{value: 'https://other.example/secret.js'}, 1, .yes)
	script.set_evaluator(fn [scope] (_ string, realm &ScriptingRealm) !dom.JSValue {
		assert realm.active_classic_script_ != none
		mut service := unsafe { &WindowOrWorkerGlobalScopeMixin(scope) }
		service.report_error(dom.js_string('private details'))
		return dom.js_undefined()
	})
	script.run(.no) or { panic(err) }
	assert realm.active_classic_script_ == none
	assert recorder.events.len == 1
	assert recorder.events[0].message() == 'Script error.'
	assert recorder.events[0].filename() == ''
	assert recorder.events[0].lineno() == 0
	assert recorder.events[0].colno() == 0
	assert recorder.events[0].error().kind == .null_
	assert realm.reported_exceptions[0].value.string_data == 'private details'
	scope.report_error(dom.js_string('visible'))
	assert recorder.events[1].message() == 'Uncaught exception: visible'
	assert recorder.events[1].error().string_data == 'visible'
}

fn test_dedicated_global_error_reaches_page_client_and_owner_on_the_owner_task_source() {
	window, owner_realm := global_error_window()
	settings := window.environment_settings_.settings
	mut document := window.associated_document()
	worker_page := page.Page.create(1) or { panic(err) }
	document.set_page(unsafe { &dom.Page(worker_page) })
	worker := Worker.construct_impl('/worker.js', settings, WorkerOptions{}) or { panic(err) }
	mut global := worker.scope_ or { panic('missing worker global') }
	mut realm := &ScriptingRealm{}
	_ = WorkerEnvironmentSettingsObject.setup(global, mut realm, settings.serialize(), 0)
	realm.error_extraction_context_ = fn (_ dom.JSValue) ErrorExtractionContext {
		return ErrorExtractionContext{
			own_message: 'worker exploded'
			exception_is_error: true
			traceback: [ErrorSourceLocation{filename: 'worker.js', line: 12, column: 34}]
		}
	}
	mut services := global.window_or_worker_global_scope()
	mut inside := &GlobalErrorRecorder{scope: services}
	outside := &GlobalErrorRecorder{}
	global.set_onerror(global_error_listener(inside))
	worker.set_onerror(global_error_listener(outside))
	services.report_error(dom.js_string('worker failure'))
	assert inside.events.len == 1
	assert outside.events.len == 0
	assert realm.reported_exceptions.len == 0
	assert services.reported_errors().len == 0
	assert worker_page.client().worker_exceptions().len == 1
	assert worker_page.client().worker_exceptions()[0].message == 'worker exploded'
	assert worker_page.client().worker_exceptions()[0].line == 12
	mut owner_queue := settings.responsible_event_loop().task_queue()
	notification := owner_queue.take_first_runnable_matching(fn (task &Task) bool { return task.source == .dom_manipulation }) or { panic('missing owning worker-error task') }
	notification.execute()
	assert outside.events.len == 1
	assert outside.events[0].message() == 'worker exploded'
	assert outside.events[0].filename() == 'worker.js'
	assert outside.events[0].lineno() == 12
	assert outside.events[0].colno() == 34
	assert outside.events[0].error().kind == .null_
	assert owner_realm.reported_exceptions.len == 1
	inside.cancel = true
	services.report_error(dom.js_string('handled inside worker'))
	assert inside.events.len == 2
	assert worker_page.client().worker_exceptions().len == 1
	assert !owner_queue.has_runnable_tasks()
}

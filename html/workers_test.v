@[has_globals]
module html

import dom
import fetch
import http

struct WorkerMessageRecorder {
mut:
	values []string
}

struct WorkerErrorRecorder {
mut:
	messages        []string
	filenames       []string
	line_numbers    []u32
	column_numbers  []u32
	error_values    []dom.JSValue
	event_pointers  []voidptr
	prevent_default bool
}

fn worker_message_callback(mut recorder WorkerMessageRecorder) &dom.CallbackType {
	return &dom.CallbackType{
		handle_event: fn [mut recorder] (base_event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			event := unsafe { &MessageEvent(base_event) }recorder.values << event.data().to_string_value()return dom.js_undefined()
		}
	}
}

fn worker_error_callback(mut recorder WorkerErrorRecorder) &dom.CallbackType {
	return &dom.CallbackType{
		handle_event: fn [mut recorder] (base_event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			event := unsafe { &dom.ErrorEvent(base_event) }
			recorder.messages << event.message()
			recorder.filenames << event.filename()
			recorder.line_numbers << event.lineno()
			recorder.column_numbers << event.colno()
			recorder.error_values << event.error()
			recorder.event_pointers << voidptr(event)
			if recorder.prevent_default {
				mut mutable_event := unsafe { &dom.Event(base_event) }
				mutable_event.prevent_default()
			}
			return dom.js_undefined()
		}
	}
}

fn drain_worker_messages() {
	mut loop_ := main_thread_event_loop()
	for loop_.task_queue().has_runnable_tasks() {
		loop_.process()
	}
}

fn worker_test_fetch_script(url dom.URL, realm &ScriptingRealm) !&ClassicScript {
	return ClassicScript.create(url.serialize(), '', realm, url, 1, .no)
}

fn test_dedicated_worker_message_round_trip_import_and_terminate() {
	mut realm := &ScriptingRealm{}
	mut worker := Worker.create('worker.js', dom.URL{ value: 'https://example.test/' }, WorkerOptions{}, realm) or { panic(err) }
	mut scope := worker.scope() or { panic('missing scope') }
	scope.initialize_web_interfaces_impl()
	assert scope.web_interfaces_initialized()
	mut inside_recorder := &WorkerMessageRecorder{}
	scope.set_onmessage(worker_message_callback(mut inside_recorder))
	worker.post_message(dom.js_string('in'), StructuredSerializeOptions{}) or { panic(err) }
	drain_worker_messages()
	assert inside_recorder.values == ['in']

	mut outside_recorder := &WorkerMessageRecorder{}
	worker.set_onmessage(worker_message_callback(mut outside_recorder))
	scope.post_message(dom.js_string('out'), StructuredSerializeOptions{}) or { panic(err) }
	drain_worker_messages()
	assert outside_recorder.values == ['out']

	scope.import_scripts(['dependency.js'], worker_test_fetch_script) or { panic(err) }
	worker.terminate()
	assert worker.terminated_
	assert scope.is_closing()
}

fn test_shared_worker_reuses_matching_scope_and_console_groups() {
	realm := &ScriptingRealm{}
	options := WorkerOptions{
		name: 'shared'
	}
	first := SharedWorker.create('/shared.js', dom.URL{ value: 'https://example.test/' }, options, 'partition', true, realm) or { panic(err) }
	second := SharedWorker.create('/shared.js', dom.URL{ value: 'https://example.test/' }, options, 'partition', true, realm) or { panic(err) }
	assert voidptr(first.scope()) == voidptr(second.scope())
	assert voidptr(first.port()) != voidptr(second.port())
	mut shared_scope := first.scope()
	shared_scope.initialize_web_interfaces_impl()
	assert shared_scope.web_interfaces_initialized()

	document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	window := WindowModel.create_top_level(document, none, 'worker-test')!
	mut settings_realm := &ScriptingRealm{}
	settings := WindowEnvironmentSettingsObject.setup(window, document.url, mut settings_realm, none, document.url, document.origin()).settings
	constructed := SharedWorker.construct_impl('/constructed.js', SharedWorkerOptionsValue('named'), settings)!
	assert constructed.scope().name() == 'named'
	assert constructed.agent_ != none
	assert constructed.scope() in all_shared_worker_global_scopes()

	mut console := WorkerDebugConsoleClient{}
	console.printer(.group, ['group'])
	console.printer(.log, ['value'])
	console.end_group()
	assert console.output == ['group', '  value']
	assert console.group_stack_depth == 0
	mut constructed_scope := constructed.scope()
	constructed_scope.close()
	assert constructed.scope() !in all_shared_worker_global_scopes()
}

fn test_run_a_dedicated_worker_installs_and_starts_parent_agent() {
	document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	window := WindowModel.create_top_level(document, none, 'worker-run-test')!
	mut realm := &ScriptingRealm{}
	settings := WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, none, document.url, document.origin()).settings
	mut worker := Worker.construct_impl('/worker.js', settings, WorkerOptions{})!
	agent := worker.agent_ or { panic('missing worker agent') }
	assert agent.started
	assert agent.ipc_callbacks_configured_
	assert settings.worker_startup_keep_alive_count() == 1
	worker.terminate()
	assert settings.worker_startup_keep_alive_count() == 0
}

fn test_worker_agent_parent_callbacks_and_shadow_realm_interfaces() {
	document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	window := WindowModel.create_top_level(document, none, 'worker-parent-test')!
	mut settings_realm := &ScriptingRealm{}
	settings := WindowEnvironmentSettingsObject.setup(window, document.url, mut settings_realm, none, document.url, document.origin()).settings
	outside := MessagePort.create()
	target := dom.EventTarget.new()
	mut parent := WorkerAgentParent.create(dom.URL{ value: 'https://example.test/worker.js' }, WorkerOptions{}, settings, outside, target)
	parent.initialize()!
	assert parent.started
	assert parent.ipc_callbacks_configured_
	assert parent.message_port != none
	assert settings.worker_startup_keep_alive_count() == 1
	parent.worker_script_load_failure()
	assert settings.worker_startup_keep_alive_count() == 0

	mut successful_parent := WorkerAgentParent.create(dom.URL{
		value: 'https://example.test/success.js'
	}, WorkerOptions{}, settings, MessagePort.create(), dom.EventTarget.new())
	successful_parent.initialize()!
	assert settings.worker_startup_keep_alive_count() == 1
	successful_parent.worker_script_load_success()
	assert settings.worker_startup_keep_alive_count() == 0

	mut closing_parent := WorkerAgentParent.create(dom.URL{
		value: 'https://example.test/closing.js'
	}, WorkerOptions{}, settings, MessagePort.create(), dom.EventTarget.new())
	closing_parent.initialize()!
	assert settings.worker_startup_keep_alive_count() == 1
	closing_parent.worker_close()
	assert settings.worker_startup_keep_alive_count() == 0

	mut realm := &ScriptingRealm{}
	mut shadow := ShadowRealmGlobalScope.create(realm)
	shadow.initialize_web_interfaces()
	assert shadow.web_interfaces_initialized_
}

fn test_unhandled_dedicated_worker_exception_fires_error_on_parent_global() {
	document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	window := WindowModel.create_top_level(document, none, 'worker-error-test')!
	mut realm := &ScriptingRealm{}
	settings := WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, none, document.url, document.origin()).settings
	worker := Worker.construct_impl('/worker.js', settings, WorkerOptions{})!
	agent := worker.agent_ or { panic('missing worker agent') }

	mut recorder := &WorkerErrorRecorder{}
	worker.set_onerror(worker_error_callback(mut recorder))
	agent.worker_exception('worker exploded', 'worker.js', 12, 34)
	drain_worker_messages()

	assert recorder.messages == ['worker exploded']
	assert recorder.filenames == ['worker.js']
	assert recorder.line_numbers == [u32(12)]
	assert recorder.column_numbers == [u32(34)]
	assert recorder.error_values[0].is_nullish()
	reported := window.window_or_worker_global_scope().reported_errors()
	assert reported.len == 1
	assert reported[0].kind == .object
	assert reported[0].object_data == recorder.event_pointers[0]

	recorder.prevent_default = true
	agent.worker_exception('handled', 'worker.js', 56, 78)
	drain_worker_messages()
	assert recorder.messages == ['worker exploded', 'handled']
	assert window.window_or_worker_global_scope().reported_errors().len == 1
}

fn test_worker_global_scope_fonts_policy_container_and_csp_initialization() {
	mut realm := &ScriptingRealm{}
	mut scope := WorkerGlobalScope.create(dom.URL{ value: 'https://example.test/worker.js' }, .classic, '', realm)
	assert voidptr(scope.fonts()) == voidptr(scope.fonts())
	assert scope.policy_container().csp_list.len == 0

	document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	window := WindowModel.create_top_level(document, none, 'worker-policy-test')!
	settings := WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, none, document.url, document.origin()).settings
	mut response := fetch.Response.create()
	response.url_list = [dom.URL{ value: 'https://example.test/worker.js' }]
	response.header_list.append(http.Header{'Content-Security-Policy', 'sandbox'})
	response.header_list.append(http.Header{'Referrer-Policy', 'no-referrer'})
	scope.initialize_policy_container(response, settings)
	assert scope.policy_container().referrer_policy == .no_referrer
	assert scope.run_csp_initialization() == .blocked
}

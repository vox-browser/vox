@[has_globals]
module html

import dom

struct WorkerMessageRecorder {
mut:
	values []string
}

fn worker_message_callback(mut recorder WorkerMessageRecorder) &dom.CallbackType {
	return &dom.CallbackType{
		handle_event: fn [mut recorder] (base_event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			event := unsafe { &MessageEvent(base_event) }
			recorder.values << event.data().to_string_value()
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
	mut worker := Worker.create('worker.js', dom.URL{ value: 'https://example.test/' }, WorkerOptions{},
		realm) or { panic(err) }
	mut scope := worker.scope() or { panic('missing scope') }
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
	first := SharedWorker.create('/shared.js', dom.URL{ value: 'https://example.test/' }, options,
		'partition', true, realm) or { panic(err) }
	second := SharedWorker.create('/shared.js', dom.URL{ value: 'https://example.test/' }, options,
		'partition', true, realm) or { panic(err) }
	assert voidptr(first.scope()) == voidptr(second.scope())
	assert voidptr(first.port()) != voidptr(second.port())

	mut console := WorkerDebugConsoleClient{}
	console.printer(.group, ['group'])
	console.printer(.log, ['value'])
	console.end_group()
	assert console.output == ['group', '  value']
	assert console.group_stack_depth == 0
}

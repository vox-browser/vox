module html

import dom
import platform

@[heap]
struct WindowMessageObservation {
mut:
	events []&MessageEvent
}

fn test_window_post_message_dispatches_a_trusted_event_with_the_sender_proxy() {
	mut document := dom.Document.create(dom.URL{ value: 'https://message.test/' })
	mut window := WindowModel.create_top_level(document, none, '')!
	defer { document.finalize() }
	mut observation := &WindowMessageObservation{}
	window.add_event_listener_without_options('message', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [mut observation] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert event.interface_ == .message_event
			assert event.is_trusted()
			observation.events << unsafe { &MessageEvent(event) }
			return dom.js_undefined()
		}
	}))
	window.post_message(dom.js_number(7), document.origin(), WindowPostMessageOptions{ source: window.window().dom_proxy() })!
	assert observation.events.len == 0
	drain_window_message_tasks()
	assert observation.events.len == 1
	event := observation.events[0]
	assert event.data().number_data == 7
	assert event.origin() == 'https://message.test'
	source := event.source() or { panic('Missing sender') }
	assert source is WindowMessageEventSource
	if source is WindowMessageEventSource {
		assert voidptr(source.value) == voidptr(window.window().dom_proxy())
	}
	assert event.ports().len == 0
}

fn drain_window_message_tasks() {
	mut loop := main_thread_event_loop()
	mut queue := loop.task_queue()
	for {
		task := queue.take_first_runnable_matching(fn (task &Task) bool {
			return task.source() == .posted_message
		}) or { break }
		task.execute()
	}
}

fn test_window_post_message_clones_at_call_time_and_delivers_on_its_task_source() {
	mut document := dom.Document.create(dom.URL{ value: 'https://message.test/' })
	mut window := WindowModel.create_top_level(document, none, '')!
	defer { document.finalize() }
	mut array := StructuredObject.create(.array)
	array.values << &dom.JSValue{ kind: .string, string_data: 'before' }
	window.post_message(structured_object_value(array), document.origin(), WindowPostMessageOptions{})!
	array.values[0] = &dom.JSValue{ kind: .string, string_data: 'after' }
	assert window.posted_messages().len == 0
	drain_window_message_tasks()
	assert window.posted_messages().len == 1
	clone := structured_object_from_value(window.posted_messages()[0].data)!
	assert voidptr(clone) != voidptr(array)
	assert clone.values[0].string_data == 'before'
}

fn test_window_post_message_survives_the_callers_temporary_allocations() {
	mut document := dom.Document.create(dom.URL{ value: 'https://message.test/' })
	document.enable_native_storage()
	mut window := WindowModel.create_top_level(document, none, '')!
	defer {
		document.finalize()
		document.release_native_storage()
	}
	mut scope := document.enter_native_storage()
	mut scratch := platform.new_arena('postMessage caller scratch')
	entry := scratch.enter()
	window.post_message(dom.js_string('message'.repeat(1024)), document.origin(), WindowPostMessageOptions{})!
	scratch.leave(entry)
	scratch.reset()
	mut delivery_scratch := platform.begin_thread_scratch('posted-message delivery')
	drain_window_message_tasks()
	delivery_scratch.finish()
	assert window.posted_messages().len == 1
	assert window.posted_messages()[0].data.string_data == 'message'.repeat(1024)
	$if prealloc {
		assert document.native_storage().arena.contains(window.posted_messages()[0].data.string_data.str)
	}
	scratch.release()
	scope.finish()
}

fn test_window_post_message_checks_recipient_origin_when_the_task_runs() {
	mut document := dom.Document.create(dom.URL{ value: 'https://first.test/' })
	mut window := WindowModel.create_top_level(document, none, '')!
	defer { document.finalize() }
	window.post_message(dom.js_string('old'), document.origin(), WindowPostMessageOptions{})!
	window.post_message(dom.js_string('new'), document.origin(), WindowPostMessageOptions{ target_origin: 'https://second.test/path' })!
	document.set_origin(dom.URL{ value: 'https://second.test/' }.origin())
	drain_window_message_tasks()
	assert window.posted_messages().len == 1
	assert window.posted_messages()[0].data.string_data == 'new'
	assert window.posted_messages()[0].origin == 'https://first.test'
}

fn test_window_post_message_rejects_relative_targets_and_does_not_alias_opaque_origins() {
	mut document := dom.Document.create(dom.URL{ value: 'about:blank' })
	mut window := WindowModel.create_top_level(document, none, '')!
	defer { document.finalize() }
	for target in ['relative', '/path', '#fragment'] {
		window.post_message(dom.js_null(), document.origin(), WindowPostMessageOptions{ target_origin: target }) or {
			assert err.msg().starts_with('SyntaxError:')
			continue
		}
		assert false, target
	}
	window.post_message(dom.js_string('same'), document.origin(), WindowPostMessageOptions{})!
	window.post_message(dom.js_string('other'), dom.origin_create_opaque(), WindowPostMessageOptions{})!
	drain_window_message_tasks()
	assert window.posted_messages().len == 1
	assert window.posted_messages()[0].data.string_data == 'same'
}

@[has_globals]
module html

import dom

__global (
	selectionchange_event_count = 0
)

fn record_selectionchange_event(event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
	assert event.type_name() == 'selectionchange'
	assert !event.bubbles()
	assert !event.cancelable()
	selectionchange_event_count++
	return dom.js_undefined()
}

fn test_selectionchange_is_queued_on_the_user_interaction_task_source() {
	selectionchange_event_count = 0
	mut document := dom.Document.create(dom.url_about_blank())
	_ = WindowModel.create_top_level(document, none, 'selectionchange-test') or { panic(err) }
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: record_selectionchange_event
	})
	target := document.global_event_handlers_to_event_target('selectionchange')
	target.add_event_listener_without_options('selectionchange', listener)

	dom.schedule_a_selectionchange_event(mut document, document)
	dom.schedule_a_selectionchange_event(mut document, document)
	assert document.has_scheduled_selectionchange_event()
	mut event_loop := main_thread_event_loop()
	mut queue := event_loop.task_queue()
	assert queue.tasks.count(it.source() == .user_interaction) == 1
	event_loop.process()
	assert !document.has_scheduled_selectionchange_event()
	assert selectionchange_event_count == 1
	document.finalize()
}


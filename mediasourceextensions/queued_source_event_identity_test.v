module mediasourceextensions

import dom
import html

@[heap]
struct QueuedMediaSourceIdentity {
mut:
	identities []bool
}

fn queued_media_source_identity(event_name string) !&QueuedMediaSourceIdentity {
	mut source := MediaSource.create()
	seen := &QueuedMediaSourceIdentity{}
	expected := voidptr(&source.EventTarget)
	callback := &dom.CallbackType{
		handle_event: fn [seen, expected] (event &dom.Event, current_target ?&dom.EventTarget) dom.JSValue {
			mut observation := unsafe { &QueuedMediaSourceIdentity(seen) }
			target := event.target() or { return dom.js_undefined() }
			current := current_target or { return dom.js_undefined() }
			observation.identities << (voidptr(target) == expected && voidptr(current) == expected && voidptr(event.current_target() or {
				return dom.js_undefined()
			}) == expected)
			return dom.js_undefined()
		}
	}
	source.set_event_handler_attribute(event_name, callback)
	source.set_ready_state_to_open_and_fire_sourceopen_event()
	if event_name == 'sourceended' { source.end_of_stream(none)! }
	if event_name == 'sourceclose' { source.detach_from_media_element() }
	mut event_loop := html.main_thread_event_loop()
	queue := event_loop.task_queue()
	event_loop.spin_until(fn [queue] () bool {
		return !queue.has_runnable_tasks()
	})
	return seen
}

fn test_sourceopen_task_keeps_original_event_target() {
	assert queued_media_source_identity('sourceopen')!.identities == [true]
}

fn test_sourceended_task_keeps_original_event_target() {
	assert queued_media_source_identity('sourceended')!.identities == [true]
}

fn test_sourceclose_task_keeps_original_event_target() {
	assert queued_media_source_identity('sourceclose')!.identities == [true]
}

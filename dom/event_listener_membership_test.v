module dom

import platform

fn test_listener_membership_reads_live_storage_without_cloning_snapshots() {
	target := EventTarget.construct_impl()!
	assert !target.has_event_listeners() && !target.has_event_listener('load')
	target.set_event_handler_attribute('load', &CallbackType{handle_event:fn (_ &Event, _ ?&EventTarget) JSValue { return js_undefined() }})
	mut snapshot := target.event_listener_list()
	snapshot.clear()
	assert target.has_event_listeners() && target.has_event_listener('load')
	before := platform.thread_arena_usage().used
	mut matches := 0
	for _ in 0 .. 1024 {
		if target.has_event_listeners() && target.has_event_listener('load') && !target.has_event_listener('missing') { matches++ }
	}
	$if prealloc { assert platform.thread_arena_usage().used == before }
	assert matches == 1024
	target.set_event_handler_attribute('load', none)
	assert !target.has_event_listeners() && !target.has_event_listener('load')
}

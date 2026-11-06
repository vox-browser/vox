module dom

import platform

struct DispatchStorageObservation {
mut:
	calls int
}

fn test_invoking_a_deep_wheel_path_does_not_retain_path_and_listener_snapshots() {
	target := EventTarget.new()
	state := &DispatchStorageObservation{}
	target.add_event_listener_without_options('wheel', IDLEventListener.create(&CallbackType{
		handle_event: fn [state] (_ &Event, _ ?&EventTarget) JSValue {
			mut observation := unsafe { &DispatchStorageObservation(state) }
			observation.calls++
			return js_undefined()
		}
	}))
	mut event := Event.create('wheel', EventInit{bubbles: true})
	for _ in 0 .. 64 { event.append_to_path(target, target, none, [], false) }
	mut exceptions := LegacyListenerExceptionFlag{}
	// Warm both dispatch phases before measuring persistent growth.
	for entry in event.path_ { EventDispatcher.invoke(entry, event, .bubbling_phase, mut exceptions) }
	before := platform.thread_arena_usage().used
	for _ in 0 .. 32 {
		for entry in event.path_ {
			EventDispatcher.invoke(entry, event, .capturing_phase, mut exceptions)
			EventDispatcher.invoke(entry, event, .bubbling_phase, mut exceptions)
		}
	}
	growth := platform.thread_arena_usage().used - before
	eprintln('WHEEL_DISPATCH_RETAINED bytes=${growth} frames=32 depth=64')
	assert state.calls == 64 * 33
	assert !exceptions.did_listeners_throw
	$if prealloc { assert growth == 0 }
}

struct DispatchSnapshotObservation {
mut:
	calls []string
}

fn test_complete_deep_wheel_dispatch_reuses_its_path_and_retires_internal_snapshots() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut parent := document.create_element('div')!
	for _ in 0 .. 63 {
		child := document.create_element('div')!
		parent.as_node().append_child(child.as_node())!
		parent = child
	}
	target := unsafe { &EventTarget(parent.as_node()) }
	target.add_event_listener_without_options('wheel', IDLEventListener.create(&CallbackType{
		handle_event: fn (_ &Event, _ ?&EventTarget) JSValue { return js_undefined() }
	}))
	event := Event.create('wheel', EventInit{bubbles: true})
	for _ in 0 .. 3 { assert event_target_dispatch_event(target, event) }
	before := platform.thread_arena_usage().used
	for _ in 0 .. 32 { assert event_target_dispatch_event(target, event) }
	growth := platform.thread_arena_usage().used - before
	eprintln('WHEEL_FULL_DISPATCH_RETAINED bytes=${growth} frames=32 depth=64')
	assert event.path_.len == 0
	$if prealloc { assert growth == 0 }
}

fn test_listener_snapshots_preserve_removal_once_reentrancy_and_callback_allocations() {
	target := EventTarget.new()
	state := &DispatchSnapshotObservation{}
	removed := IDLEventListener.create(&CallbackType{
		handle_event: fn [state] (_ &Event, _ ?&EventTarget) JSValue {
			mut observation := unsafe { &DispatchSnapshotObservation(state) }
			observation.calls << 'removed listener ran'
			return js_undefined()
		}
	})
	target.add_event_listener('wheel', IDLEventListener.create(&CallbackType{
		handle_event: fn [target, state, removed] (_ &Event, _ ?&EventTarget) JSValue {
			mut observation := unsafe { &DispatchSnapshotObservation(state) }
			observation.calls << ['first', 'callback'].join(' ')
			target.remove_event_listener_without_options('wheel', removed)
			target.add_event_listener_without_options('wheel', IDLEventListener.create(&CallbackType{
				handle_event: fn [state] (_ &Event, _ ?&EventTarget) JSValue {
					mut nested_observation := unsafe { &DispatchSnapshotObservation(state) }
					nested_observation.calls << ['late', 'callback'].join(' ')
					return js_undefined()
				}
			}))
			nested := Event.create('wheel', EventInit{})
			assert event_target_dispatch_event(target, nested)
			return js_undefined()
		}
	}), AddEventListenerOptions{once: true})
	target.add_event_listener_without_options('wheel', removed)
	event := Event.create('wheel', EventInit{})
	assert event_target_dispatch_event(target, event)
	assert state.calls == ['first callback', 'late callback']
	assert event_target_dispatch_event(target, event)
	assert state.calls == ['first callback', 'late callback', 'late callback']
	assert event.path_.len == 0
	assert event.current_target() == none
}

fn test_public_event_paths_remain_independent_owned_snapshots() {
	target := EventTarget.new()
	mut event := Event.create('wheel', EventInit{})
	event.append_to_path(target, target, none, [], false)
	mut snapshot := event.path()
	event.clear_path()
	assert snapshot.len == 1
	assert voidptr(snapshot[0].invocation_target) == voidptr(target)
	snapshot.clear()
	event.append_to_path(target, target, none, [], false)
	assert snapshot.len == 0
	assert event.path_.len == 1
}

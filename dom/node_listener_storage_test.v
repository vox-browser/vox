module dom

import platform

fn test_node_listener_membership_tracks_capture_variants_and_last_removal() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	text := document.create_text_node('target')
	node := text.as_node()
	target := unsafe { &EventTarget(node) }
	callback := IDLEventListener.create(&CallbackType{})
	assert !node.has_event_listener('change')
	target.add_event_listener('change', callback, AddEventListenerOptions{})
	target.add_event_listener('change', callback, AddEventListenerOptions{capture:true})
	assert node.has_event_listener('change')
	target.remove_event_listener('change', callback, EventListenerOptions{})
	assert node.has_event_listener('change')
	target.remove_event_listener('change', callback, EventListenerOptions{capture:true})
	assert !node.has_event_listener('change')
	assert !target.has_event_listeners()
}

@[heap]
struct NodeListenerOnceProbe {
mut:
	calls int
	removed_during_callback bool
}

fn test_node_once_listener_is_absent_before_its_callback_runs() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	text := document.create_text_node('target')
	node := text.as_node()
	target := unsafe { &EventTarget(node) }
	probe := &NodeListenerOnceProbe{}
	callback := IDLEventListener.create(&CallbackType{
		handle_event: fn [node, probe] (_ &Event, _ ?&EventTarget) JSValue {
			mut result := unsafe { &NodeListenerOnceProbe(probe) }
			result.calls++
			result.removed_during_callback = !node.has_event_listener('once')
			return js_undefined()
		}
	})
	target.add_event_listener('once', callback, AddEventListenerOptions{once:true})
	assert node.has_event_listener('once')
	assert target.dispatch_event(Event.create('once', EventInit{}))
	assert probe.calls == 1 && probe.removed_during_callback
	assert !node.has_event_listener('once')
	assert target.dispatch_event(Event.create('once', EventInit{}))
	assert probe.calls == 1
}

fn test_node_listener_churn_reuses_the_canonical_listener_vector() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	text := document.create_text_node('target')
	node := text.as_node()
	target := unsafe { &EventTarget(node) }
	assert target.data.kind == .node
	mut listener := &DOMEventListener{
		type_: 'tick'
		callback: IDLEventListener.create(&CallbackType{})
		passive: false
	}
	target.add_an_event_listener(listener)
	target.remove_an_event_listener(listener)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 256 {
		listener.removed = false
		target.add_an_event_listener(listener)
		assert node.has_event_listener('tick')
		target.remove_an_event_listener(listener)
		assert !node.has_event_listener('tick')
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
}

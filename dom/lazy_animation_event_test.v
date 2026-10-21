module dom

import platform

__global lazy_animation_event_constructions_ int

fn lazy_animation_event_for_test(pending &PendingAnimationEvent) &Event {
	lazy_animation_event_constructions_++
	mut event := Event.create(pending.event_type, EventInit{ bubbles: true })
	event.set_time_stamp(pending.event_time_stamp)
	return event
}

fn lazy_animation_record(target &EventTarget, type_ string, when f64) PendingAnimationEvent {
	return PendingAnimationEvent{
		target:               target
		event_factory:        lazy_animation_event_for_test
		event_type:           type_
		event_time_stamp:     when
		scheduled_event_time: when
	}
}

fn test_unobserved_css_event_records_reuse_queue_storage_without_constructing_events() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	target := document.create_element('span')!
	target_events := unsafe { &EventTarget(target.as_node()) }
	document.append_pending_animation_event(lazy_animation_record(target_events, 'animationiteration', 1))
	document.update_animations_and_send_events(1)
	lazy_animation_event_constructions_ = 0
	before := platform.thread_arena_usage().used
	for index in 0 .. 1024 {
		document.append_pending_animation_event(lazy_animation_record(target_events, 'animationiteration', f64(index)))
		document.update_animations_and_send_events(f64(index))
	}
	$if prealloc {
		assert platform.thread_arena_usage().used - before < 1024
	}
	assert lazy_animation_event_constructions_ == 0
	assert document.pending_animation_event_queue.len == 0
}

struct LazyAnimationEventObservation {
mut:
	seen     []string
	times    []f64
	retained []&Event
}

fn test_lazy_event_delivery_checks_listeners_after_sorting_and_after_earlier_callbacks() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut parent := document.create_element('div')!
	target := document.create_element('span')!
	mut parent_node := parent.as_node()
	parent_node.append_child(target.as_node())!
	mut document_node := document.as_node()
	document_node.append_child(parent.as_node())!
	target_events := unsafe { &EventTarget(target.as_node()) }
	parent_events := unsafe { &EventTarget(parent.as_node()) }
	observation := &LazyAnimationEventObservation{}
	listener := IDLEventListener.create(&CallbackType{
		handle_event: fn [observation] (event &Event, _ ?&EventTarget) JSValue {
			mut result := unsafe { &LazyAnimationEventObservation(observation) }
			result.seen << event.type_name()
			result.times << event.time_stamp()
			result.retained << event
			return js_undefined()
		}
	})
	// Queue backwards. Nothing observes the second type until the first
	// delivered callback installs an ancestor listener for it.
	document.append_pending_animation_event(lazy_animation_record(target_events, 'later', 20))
	document.append_pending_animation_event(lazy_animation_record(target_events, 'first', 10))
	parent_events.add_event_listener_without_options('first', IDLEventListener.create(&CallbackType{
		handle_event: fn [parent_events, listener] (_ &Event, _ ?&EventTarget) JSValue {
			parent_events.add_event_listener_without_options('later', listener)
			return js_undefined()
		}
	}))
	parent_events.add_event_listener_without_options('first', listener)
	lazy_animation_event_constructions_ = 0
	document.update_animations_and_send_events(100)
	assert observation.seen == ['first', 'later']
	assert observation.times == [f64(10), 20]
	assert lazy_animation_event_constructions_ == 2
	gc_collect()
	assert observation.retained[0].type_name() == 'first'
	assert observation.retained[1].type_name() == 'later'
	assert voidptr(observation.retained[0]) != voidptr(observation.retained[1])
}

fn test_ordinary_pending_animation_event_identity_is_preserved() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	target := document.create_element('span')!
	events := unsafe { &EventTarget(target.as_node()) }
	observation := &LazyAnimationEventObservation{}
	events.add_event_listener_without_options('finish', IDLEventListener.create(&CallbackType{
		handle_event: fn [observation] (event &Event, _ ?&EventTarget) JSValue {
			mut result := unsafe { &LazyAnimationEventObservation(observation) }
			result.retained << event
			return js_undefined()
		}
	}))
	provided := Event.create('finish', EventInit{})
	document.append_pending_animation_event(PendingAnimationEvent{ target: events, event: provided })
	document.update_animations_and_send_events(100)
	assert observation.retained.len == 1
	assert voidptr(observation.retained[0]) == voidptr(provided)
}

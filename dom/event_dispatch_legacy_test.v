module dom

struct LegacyEventDispatchObservation {
mut:
	count      int
	event_type string
}

fn test_trusted_event_dispatch_reaches_legacy_prefixed_ancestor_listener() {
	document := Document.create(url_about_blank())
	parent := document.create_element('div')!
	child := document.create_element('span')!
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node())!

	observation := &LegacyEventDispatchObservation{}
	callback := &CallbackType{
		handle_event: fn [observation] (event &Event, _ ?&EventTarget) JSValue {
			mut result := unsafe { &LegacyEventDispatchObservation(observation) }
			result.count++
			result.event_type = event.type_name()
			return js_undefined()
		}
	}
	unsafe { &EventTarget(parent.as_node()) }.add_event_listener_without_options('webkitTransitionEnd', IDLEventListener.create(callback))

	mut event := Event.create('transitionend', EventInit{ bubbles: true })
	event.set_is_trusted(true)
	assert event_target_dispatch_event(unsafe { &EventTarget(child.as_node()) }, event)
	assert observation.count == 1
	assert observation.event_type == 'webkitTransitionEnd'
	assert event.type_name() == 'transitionend'
}

fn test_untrusted_event_dispatch_does_not_use_legacy_prefixed_listener() {
	document := Document.create(url_about_blank())
	element := document.create_element('div')!
	observation := &LegacyEventDispatchObservation{}
	callback := &CallbackType{
		handle_event: fn [observation] (_ &Event, _ ?&EventTarget) JSValue {
			mut result := unsafe { &LegacyEventDispatchObservation(observation) }
			result.count++
			return js_undefined()
		}
	}
	unsafe { &EventTarget(element.as_node()) }.add_event_listener_without_options('webkitAnimationEnd', IDLEventListener.create(callback))

	event := Event.construct_impl('animationend', EventInit{})!
	assert event_target_dispatch_event(unsafe { &EventTarget(element.as_node()) }, event)
	assert observation.count == 0
}

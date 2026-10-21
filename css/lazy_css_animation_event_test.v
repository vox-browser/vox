module css

import dom

fn test_css_animation_queues_metadata_and_preserves_creation_time_when_a_late_listener_observes_it() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	target := document.create_element('div')!
	abstract_target := dom.AbstractElement.new(target, none)
	mut effect := KeyframeEffect.create()
	effect.set_target(abstract_target)
	mut animation := CSSAnimation.create()
	animation.set_animation_name('fixture')
	animation.set_owning_element(abstract_target)
	animation.set_effect(effect)
	append_css_animation_event(mut document, animation, 'animationiteration', 1500)
	pending := document.pending_animation_event_queue[0]
	assert voidptr(pending.event) == unsafe { nil }
	assert pending.event_type == 'animationiteration'
	assert pending.event_name == 'fixture'
	assert pending.event_elapsed_time == 1.5
	assert pending.event_pseudo_element == ''
	mut seen := []f64{}
	seen_ptr := &seen
	unsafe { &dom.EventTarget(target.as_node()) }.add_event_listener_without_options('animationiteration', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [seen_ptr] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			unsafe { *seen_ptr << event.time_stamp() }
			return dom.js_undefined()
		}
	}))
	document.update_animations_and_send_events(10000)
	assert seen == [pending.event_time_stamp]
}

module animations

import css
import dom

fn test_animatable_creates_and_lists_relevant_animations() {
	mut animatable := Animatable.new(none)
	mut animation := animatable.animate_with_duration([
		BaseKeyframe{
			offset:     0
			properties: {
				'opacity': '0'
			}
		},
		BaseKeyframe{
			offset:     1
			properties: {
				'opacity': '1'
			}
		},
	], 1000)!
	assert animation.pending()
	listed := animatable.get_animations(GetAnimationsOptions{})!
	assert listed.len == 1
	assert listed[0] == animation
	animation.cancel()
	assert animatable.get_animations(GetAnimationsOptions{})!.len == 0
}

fn test_animatable_transition_attributes() {
	mut animatable := Animatable.new(none)
	animatable.add_transitioned_properties(none, [
		css.TransitionProperties{
			properties:          [.opacity, .color]
			duration:            250
			delay:               20
			timing_function:     css.EasingFunction.ease_in()
			transition_behavior: .allow_discrete
		},
	])
	ids := animatable.property_ids_with_matching_transition_property_entry(none)
	assert css.PropertyID.opacity in ids
	assert css.PropertyID.color in ids
	attributes := animatable.property_transition_attributes(none, .opacity) or {
		assert false
		return
	}
	assert attributes.duration == 250
	assert attributes.delay == 20
	assert attributes.transition_behavior == .allow_discrete
	animatable.clear_registered_transitions(none)
	assert animatable.property_ids_with_matching_transition_property_entry(none).len == 0
}

fn test_document_get_animations_uses_animatable_tree_and_composite_order() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut html := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	mut first := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut second := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html.as_node())!
	mut html_node := html.as_node()
	html_node.append_child(first.as_node())!
	html_node.append_child(second.as_node())!

	mut first_animatable := Animatable.new(first)
	mut second_animatable := Animatable.new(second)
	first_animation := first_animatable.animate_with_duration([
		BaseKeyframe{ offset: 0, properties: { 'opacity': '0' } },
		BaseKeyframe{ offset: 1, properties: { 'opacity': '1' } },
	], 100)!
	second_animation := second_animatable.animate_with_duration([
		BaseKeyframe{ offset: 0, properties: { 'opacity': '1' } },
		BaseKeyframe{ offset: 1, properties: { 'opacity': '0' } },
	], 100)!

	listed := document.get_animations()!
	assert listed.len == 2
	assert listed[0].concrete_handle_ == voidptr(first_animation)
	assert listed[1].concrete_handle_ == voidptr(second_animation)
}

fn test_document_animation_update_uses_default_timeline_and_removes_replaced_animation() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	mut html := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html.as_node())!
	mut html_node := html.as_node()
	html_node.append_child(target.as_node())!

	keyframes := [
		BaseKeyframe{
			offset: 0
			properties: {
				'opacity': '0'
			}
		},
		BaseKeyframe{
			offset: 1
			properties: {
				'opacity': '1'
			}
		},
	]
	options := KeyframeAnimationOptions{
		KeyframeEffectOptions: KeyframeEffectOptions{
			timing: OptionalEffectTiming{
				duration: IterationDuration(100.0)
				fill:     FillMode.forwards
			}
		}
	}
	mut animatable := Animatable.new(target)
	first := animatable.animate(keyframes, options)!
	second := animatable.animate(keyframes, options)!
	first_timeline := first.timeline_ or { panic('missing default timeline') }
	second_timeline := second.timeline_ or { panic('missing default timeline') }
	timeline_document := first_timeline.associated_document() or {
		panic('default timeline is not associated with its document')
	}
	assert timeline_document == document
	assert second_timeline == first_timeline

	document.update_animations_and_send_events(0)
	assert first.play_state() == .running
	assert second.play_state() == .running
	document.update_animations_and_send_events(200)
	assert first.replace_state() == .removed
	assert second.replace_state() == .active
	assert first.emitted_events().last().type_name() == 'remove'
	assert document.get_animations()!.len == 1
}

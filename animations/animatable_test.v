module animations

import css

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

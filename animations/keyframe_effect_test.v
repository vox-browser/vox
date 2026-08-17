module animations

import css
import dom

fn test_pseudo_element_parsing_and_canonicalization() {
	legacy := pseudo_element_parsing(':before')!
	assert legacy.serialize() == '::before'
	modern := pseudo_element_parsing('::marker')!
	assert modern.type_ == .marker
	if _ := pseudo_element_parsing('div::before') {
		assert false
	} else {
		assert err.msg().contains('Invalid pseudo-element selector')
	}
}

fn test_compute_missing_keyframe_offsets() {
	mut frames := [
		BaseKeyframe{},
		BaseKeyframe{},
		BaseKeyframe{
			offset: 0.75
		},
		BaseKeyframe{},
	]
	compute_missing_keyframe_offsets(mut frames)
	assert (frames[0].computed_offset or { -1 }) == 0
	assert (frames[1].computed_offset or { -1 }) == 0.375
	assert (frames[2].computed_offset or { -1 }) == 0.75
	assert (frames[3].computed_offset or { -1 }) == 1
}

fn test_keyframes_are_validated_parsed_and_resolved() {
	mut effect := KeyframeEffect.create()
	effect.set_keyframes([
		BaseKeyframe{
			offset:     0
			properties: {
				'opacity':         '0'
				'backgroundColor': 'red'
			}
		},
		BaseKeyframe{
			offset:     1
			easing:     'ease-out'
			properties: {
				'opacity':         '1'
				'backgroundColor': 'blue'
			}
		},
	])!
	frames := effect.get_keyframes()
	assert frames.len == 2
	assert css.PropertyID.opacity in frames[0].parsed_properties
	assert css.PropertyID.background_color in frames[0].parsed_properties
	assert effect.key_frame_set_.keyframes_by_key.len == 2

	if _ := effect.set_keyframes([
		BaseKeyframe{ offset: 0.8 },
		BaseKeyframe{ offset: 0.2 },
	])
	{
		assert false
	} else {
		assert err.msg().contains('ascending order')
	}
	if _ := effect.set_keyframes([BaseKeyframe{ offset: 1.1 }]) {
		assert false
	} else {
		assert err.msg().contains('invalid offset')
	}
}

fn test_property_indexed_keyframes_merge_and_repeat_easing() {
	frames := process_property_indexed_keyframes(BasePropertyIndexedKeyframe{
		properties: {
			'opacity': ['0', '0.5', '1']
			'color':   ['red', 'blue']
		}
		easings:    ['ease-in', 'ease-out']
	})!
	assert frames.len == 3
	assert (frames[0].computed_offset or { -1 }) == 0
	assert (frames[1].computed_offset or { -1 }) == 0.5
	assert (frames[2].computed_offset or { -1 }) == 1
	assert frames[2].easing == 'ease-in'
	assert css.PropertyID.opacity in frames[1].parsed_properties
}

fn test_keyframe_effect_samples_css_properties() {
	target := &dom.Element{}
	mut effect := KeyframeEffect.construct_impl(target, [
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
	], KeyframeEffectOptions{
		timing: OptionalEffectTiming{
			fill:     .both
			duration: IterationDuration(1000.0)
		}
	})!
	mut timeline := AnimationTimeline.new()
	timeline.set_current_time(TimeValue.milliseconds(0))
	mut animation := Animation.create(effect.as_animation_effect(), timeline)
	animation.set_current_time(TimeValue.milliseconds(500))!
	properties := effect.update_computed_properties()
	assert css.PropertyID.opacity in properties
	opacity := properties[.opacity] or {
		assert false
		return
	}
	assert opacity.css_text == '0.5'
}

module animations

import css
import compositor
import dom
import math

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

fn test_animation_composition_conversions_and_serialization() {
	assert css_animation_composition_to_composite_operation(.replace) == .replace
	assert css_animation_composition_to_composite_operation(.add) == .add
	assert css_animation_composition_to_composite_operation(.accumulate) == .accumulate
	assert css_animation_composition_to_composite_operation_or_auto(.replace) == .replace
	assert css_animation_composition_to_composite_operation_or_auto(.add) == .add
	assert css_animation_composition_to_composite_operation_or_auto(.accumulate) == .accumulate
	assert composite_operation_or_auto_to_string(.replace) == 'replace'
	assert composite_operation_or_auto_to_string(.add) == 'add'
	assert composite_operation_or_auto_to_string(.accumulate) == 'accumulate'
	assert composite_operation_or_auto_to_string(.auto_) == 'auto'
}

fn test_keyframe_effect_binding_options_reject_numeric_duration_and_parse_pseudo() {
	if _ := keyframe_effect_options_from_bindings(KeyframeEffectOptions{
		duration_css_numeric: css.CSSNumericValue(css.CSSUnitValue.create(1, 's'))
	}) {
		assert false
	} else {
		assert err.msg().contains('CSSNumericValue')
	}
	converted := keyframe_effect_options_from_bindings(KeyframeEffectOptions{
		composite: .add
		pseudo_element: ':before'
	})!
	assert converted.composite == .add
	assert converted.pseudo_element? == '::before'
}

fn test_keyframe_effect_creation_from_processed_keyframes() {
	target := &dom.Element{}
	processed := process_a_keyframes_argument([
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
	])!
	effect := KeyframeEffect.create_from_processed_keyframes(target, processed, ProcessedKeyframeOptions(KeyframeEffectOptions{
		composite: .add
		pseudo_element: '::before'
		timing: OptionalEffectTiming{
			duration: IterationDuration(250.0)
		}
	}))!
	assert (effect.target() or { panic('missing target') }) == target
	assert effect.pseudo_element()? == '::before'
	assert effect.composite() == .add
	assert effect.iteration_duration().value == 250
	assert effect.get_keyframes().len == 2
	assert css.PropertyID.opacity in effect.target_properties()

	duration_effect := KeyframeEffect.create_from_processed_keyframes(none, processed, ProcessedKeyframeOptions(100.0))!
	assert duration_effect.iteration_duration().value == 100
}

fn test_set_keyframes_from_js_replaces_the_processed_keyframe_set() {
	mut effect := KeyframeEffect.create()
	effect.set_keyframes_from_js([
		BaseKeyframe{
			properties: {
				'opacity': '0.5'
			}
		},
	])!
	frames := effect.get_keyframes()
	assert frames.len == 1
	assert frames[0].computed_offset? == 1
	assert css.PropertyID.opacity in frames[0].parsed_properties
	if _ := effect.set_keyframes_from_js([
		BaseKeyframe{ offset: 0.8 },
		BaseKeyframe{ offset: 0.2 },
	]) {
		assert false
	} else {
		assert err.msg().contains('ascending order')
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

fn test_keyframe_effect_invalidation_resets_compositor_preparation() {
	mut first := KeyframeEffect.create()
	second := KeyframeEffect.create()
	assert first.animation_preparation_identity() != second.animation_preparation_identity()
	assert first.animation_preparation_generation() == 0

	first.set_is_compositor_driven(true)
	first.set_is_compositor_replaced(true)
	first.set_is_offscreen_throttled(true)
	first.set_is_observation_relevant_compositor_animation(true)
	first.set_retained_compositor_animations([compositor.VisualAnimation{}])
	first.set_compositor_keyframe_value_cache(.opacity, CompositorKeyframeValueCache{
		is_valid: true
	})
	first.set_composite(.add)

	assert first.animation_preparation_generation() == 1
	assert first.composite_for_bindings() == .add
	assert !first.is_compositor_driven()
	assert !first.is_compositor_replaced()
	assert !first.is_offscreen_throttled()
	assert !first.is_observation_relevant_compositor_animation()
	assert first.retained_compositor_animations().len == 0
	assert first.compositor_keyframe_value_cache(.opacity) == none
}

fn test_keyframe_effect_observation_requests_are_coalesced_by_task() {
	mut effect := KeyframeEffect.create()
	assert !effect.observation_sample_requested()
	assert effect.request_element_scoped_observation_sample(7)
	assert effect.observation_sample_requested()
	assert !effect.request_element_scoped_observation_sample(7)
	assert effect.consume_observation_sample_request()
	assert !effect.consume_observation_sample_request()
	assert effect.request_element_scoped_observation_sample(8)

	effect.note_per_frame_animation_tick_was_skipped()
	assert effect.per_frame_animation_tick_was_skipped()
	effect.clear_per_frame_animation_tick_was_skipped()
	assert !effect.per_frame_animation_tick_was_skipped()
}

fn test_keyframe_effect_target_change_moves_associated_animation() {
	document := dom.Document.create(dom.url_about_blank())
	first_target := document.create_element('div')!
	second_target := document.create_element('div')!
	mut effect := KeyframeEffect.create()
	effect.set_target(first_target)
	animation := Animation.create(effect.as_animation_effect(), none)
	mut first_animatable := Animatable.new(first_target)
	first_animatable.associate_with_animation(animation)

	effect.set_target(second_target)
	assert !first_animatable.has_associated_animations()
	mut second_animatable := Animatable.new(second_target)
	assert second_animatable.has_associated_animations()
	assert second_animatable.associated_animations_in_composite_order() == [animation]
}

fn test_infinite_transform_effect_can_skip_disconnected_style_updates() {
	target := &dom.Element{}
	mut effect := KeyframeEffect.construct_impl(target, [
		BaseKeyframe{
			offset: 0
			properties: {
				'transform': 'translateX(0px)'
			}
		},
		BaseKeyframe{
			offset: 1
			properties: {
				'transform': 'translateX(10px)'
			}
		},
	], KeyframeEffectOptions{
		timing: OptionalEffectTiming{
			iterations: math.inf(1)
			duration: IterationDuration(1000.0)
		}
	})!
	assert effect.can_skip_per_frame_style_update()

	effect.set_is_compositor_driven(true)
	assert effect.can_skip_per_frame_animation_tick()
}

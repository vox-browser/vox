// Copyright (c) 2023-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Animations/KeyframeEffect.{h,cpp}.
module animations

import css
import compositor
import dom
import math

__global keyframe_effect_preparation_identity_counter u64

pub enum CompositeOperation {
	replace
	add
	accumulate
}

pub enum CompositeOperationOrAuto {
	replace
	add
	accumulate
	auto_
}

pub struct KeyframeEffectOptions {
pub mut:
	timing               OptionalEffectTiming
	composite            CompositeOperation = .replace
	iteration_composite_accumulate bool
	pseudo_element       ?string
	duration_css_numeric ?css.CSSNumericValue
}

pub type ProcessedKeyframeOptions = KeyframeEffectOptions | f64

pub struct BaseKeyframe {
pub mut:
	offset            ?f64
	easing            string                   = 'linear'
	composite         CompositeOperationOrAuto = .auto_
	computed_offset   ?f64
	properties        map[string]string
	parsed_properties map[css.PropertyID]&dom.StyleValue
	parsed_custom_properties map[string]&dom.StyleValue
}

pub fn (keyframe &BaseKeyframe) unparsed_properties() map[string]string {
	return keyframe.properties.clone()
}

pub fn (keyframe &BaseKeyframe) parsed_properties() map[css.PropertyID]&dom.StyleValue {
	return keyframe.parsed_properties.clone()
}

pub fn (keyframe &BaseKeyframe) parsed_custom_properties() map[string]&dom.StyleValue {
	return keyframe.parsed_custom_properties.clone()
}

pub struct BasePropertyIndexedKeyframe {
pub mut:
	offsets    []?f64
	easings    []string
	composites []CompositeOperationOrAuto
	properties map[string][]string
}

pub struct ResolvedProperty {
pub:
	use_initial bool
	value       ?&dom.StyleValue
}

pub struct ResolvedKeyframe {
pub mut:
	properties map[css.PropertyID]ResolvedProperty
	custom_properties map[string]ResolvedProperty
	composite  CompositeOperationOrAuto = .auto_
	easing     ?css.EasingFunction
}

pub struct KeyFrameSet {
pub mut:
	keyframes_by_key map[u64]ResolvedKeyframe
}

pub struct CompositorKeyframeValueCache {
pub mut:
	key_frame_set_identity      voidptr
	target_style_generation     u64
	style_environment_version   u64
	reference_width             f32
	reference_height            f32
	device_pixels_per_css_pixel f32
	is_valid                    bool
	values                      []?compositor.VisualAnimationValue
}

@[heap]
pub struct KeyframeEffect {
	AnimationEffect
pub mut:
	target_element_                                   ?&dom.Element
	target_pseudo_selector_                           ?css.PseudoElementSelector
	composite_                                        CompositeOperation = .replace
	iteration_composite_accumulate_ bool
	keyframes_                                        []BaseKeyframe
	key_frame_set_                                    KeyFrameSet
	animation_preparation_identity_                   u64
	animation_preparation_generation_                 u64
	compositor_opacity_keyframe_value_cache_          ?CompositorKeyframeValueCache
	compositor_background_color_keyframe_value_cache_ ?CompositorKeyframeValueCache
	compositor_filter_keyframe_value_cache_           ?CompositorKeyframeValueCache
	compositor_transform_keyframe_value_cache_        ?CompositorKeyframeValueCache
	retained_compositor_animations_                   []compositor.VisualAnimation
	is_compositor_driven_                             bool
	is_compositor_replaced_                           bool
	is_offscreen_throttled_                           bool
	is_observation_relevant_compositor_animation_     bool
	needs_observation_sample_                         bool
	can_skip_per_frame_style_update_cache_            ?bool
	last_element_scoped_observation_task_generation_  ?u64
	per_frame_animation_tick_was_skipped_             bool
	css_sampling_effect_                              ?&css.KeyframeEffect
}

pub fn KeyframeEffect.create() &KeyframeEffect {
	identity := keyframe_effect_preparation_identity_counter
	keyframe_effect_preparation_identity_counter++
	return &KeyframeEffect{
		is_keyframe_effect_: true
		timing_function_: css.EasingFunction.linear()
		animation_preparation_identity_: identity
	}
}

pub fn KeyframeEffect.construct_impl(target ?&dom.Element, keyframes []BaseKeyframe, options KeyframeEffectOptions) !&KeyframeEffect {
	processed_keyframes := process_a_keyframes_argument(keyframes)!
	converted_options := keyframe_effect_options_from_bindings(options)!
	return KeyframeEffect.create_from_processed_keyframes(target, processed_keyframes, ProcessedKeyframeOptions(converted_options))
}

pub fn KeyframeEffect.with_duration(target ?&dom.Element, keyframes []BaseKeyframe, duration f64) !&KeyframeEffect {
	mut timing := OptionalEffectTiming{}
	timing.duration = IterationDuration(duration)
	return KeyframeEffect.construct_impl(target, keyframes, KeyframeEffectOptions{ timing: timing })
}

pub fn KeyframeEffect.copy(source &KeyframeEffect) &KeyframeEffect {
	mut effect := KeyframeEffect.create()
	effect.target_element_ = source.target_element_
	effect.target_pseudo_selector_ = source.target_pseudo_selector_
	effect.composite_ = source.composite_
	effect.iteration_composite_accumulate_ = source.iteration_composite_accumulate_
	effect.keyframes_ = source.keyframes_.clone()
	effect.key_frame_set_ = source.key_frame_set_
	effect.specified_start_delay_ = source.specified_start_delay_
	effect.specified_end_delay_ = source.specified_end_delay_
	effect.fill_mode_ = source.fill_mode_
	effect.iteration_start_ = source.iteration_start_
	effect.iteration_count_ = source.iteration_count_
	effect.specified_iteration_duration_ = source.specified_iteration_duration_
	effect.playback_direction_ = source.playback_direction_
	effect.timing_function_ = source.timing_function_
	effect.has_target_ = source.has_target_
	effect.target_properties_ = source.target_properties_.clone()
	effect.target_custom_properties_ = source.target_custom_properties_.clone()
	effect.normalize_specified_timing()
	return effect
}

pub fn keyframe_effect_options_from_bindings(options KeyframeEffectOptions) !KeyframeEffectOptions {
	if options.duration_css_numeric != none {
		return error('Setting duration as a CSSNumericValue is not supported')
	}
	canonical_pseudo_element := if pseudo_element := options.pseudo_element {
		pseudo_element_parsing(pseudo_element)!.serialize()
	} else {
		none
	}
	return KeyframeEffectOptions{
		timing: options.timing
		composite: options.composite
		iteration_composite_accumulate:options.iteration_composite_accumulate
		pseudo_element: canonical_pseudo_element
	}
}

pub fn KeyframeEffect.create_from_processed_keyframes(target ?&dom.Element, keyframes []BaseKeyframe, options ProcessedKeyframeOptions) !&KeyframeEffect {
	mut effect := KeyframeEffect.create()
	effect.set_target(target)
	match options {
		KeyframeEffectOptions {
			effect.set_pseudo_element(options.pseudo_element)!
			effect.AnimationEffect.update_timing(options.timing)!
			effect.set_composite(options.composite)
			effect.iteration_composite_accumulate_ = options.iteration_composite_accumulate
		}
		f64 {
			effect.AnimationEffect.update_timing(OptionalEffectTiming{
				duration: IterationDuration(options)
			})!
		}
	}
	effect.install_processed_keyframes(keyframes)
	return effect
}

pub fn (effect &KeyframeEffect) as_animation_effect() &AnimationEffect {
	return unsafe { &AnimationEffect(effect) }
}

pub fn (mut effect KeyframeEffect) set_target(target ?&dom.Element) {
	if animation := effect.associated_animation_ {
		if old_target := effect.target_element_ {
			if old_target.animations_animatable_handle_ != unsafe { nil } {
				mut old_animatable := unsafe { &Animatable(old_target.animations_animatable_handle_) }
				old_animatable.disassociate_with_animation(animation)
			}
		}
		if new_target := target {
			mut new_animatable := Animatable.new(new_target)
			new_animatable.associate_with_animation(animation)
		}
	}
	effect.target_element_ = target
	effect.has_target_ = target != none
	effect.invalidate_animation_preparation()
	effect.invalidate_effect()
}

pub fn (effect &KeyframeEffect) target() ?&dom.Element {
	return effect.target_element_
}

pub fn (effect &KeyframeEffect) pseudo_element() ?string {
	pseudo := effect.target_pseudo_selector_ or { return none }
	return pseudo.serialize()
}

pub fn (mut effect KeyframeEffect) set_pseudo_element(value ?string) ! {
	text := value or {
		effect.target_pseudo_selector_ = none
		effect.invalidate_animation_preparation()
		effect.invalidate_effect()
		return
	}

	effect.target_pseudo_selector_ = pseudo_element_parsing(text)!
	effect.invalidate_animation_preparation()
	effect.invalidate_effect()
}

pub fn (effect &KeyframeEffect) composite_for_bindings() CompositeOperation {
	return effect.composite_
}

pub fn (effect &KeyframeEffect) composite() CompositeOperation {
	return effect.composite_
}

pub fn (mut effect KeyframeEffect) set_composite_for_bindings(value CompositeOperation) {
	effect.set_composite(value)
}

pub fn (mut effect KeyframeEffect) set_composite(value CompositeOperation) {
	effect.composite_ = value
	effect.invalidate_animation_preparation()
	effect.invalidate_effect()
}

pub fn (effect &KeyframeEffect) pseudo_element_type() ?css.PseudoElement {
	pseudo := effect.target_pseudo_selector_ or { return none }
	return pseudo.type_
}

pub fn (effect &KeyframeEffect) get_keyframes() []BaseKeyframe {
	return effect.keyframes_.clone()
}

pub fn compute_missing_keyframe_offsets(mut keyframes []BaseKeyframe) {
	for mut keyframe in keyframes {
		keyframe.computed_offset = keyframe.offset
	}
	if keyframes.len > 1 && keyframes[0].computed_offset == none {
		keyframes[0].computed_offset = 0.0
	}
	if keyframes.len > 0 && keyframes[keyframes.len - 1].computed_offset == none {
		keyframes[keyframes.len - 1].computed_offset = 1.0
	}
	mut index_a := -1
	for index, keyframe in keyframes {
		if keyframe.computed_offset != none {
			index_a = index
			break
		}
	}
	if index_a < 0 { return }
	for {
		mut index_b := -1
		for index := index_a + 1; index < keyframes.len; index++ {
			if keyframes[index].computed_offset != none {
				index_b = index
				break
			}
		}
		if index_b < 0 { break
		 }
		offset_a := keyframes[index_a].computed_offset or { 0.0 }
		offset_b := keyframes[index_b].computed_offset or { 1.0 }
		span := f64(index_b - index_a)
		for index := index_a + 1; index < index_b; index++ {
			position := f64(index - index_a)
			keyframes[index].computed_offset = offset_a + (offset_b - offset_a) * position / span
		}
		index_a = index_b
	}
}

fn keyframes_loosely_sorted(keyframes []BaseKeyframe) bool {
	mut last := ?f64(none)
	for keyframe in keyframes {
		if offset := keyframe.offset {
			if previous := last {
				if offset < previous { return false }
			}
			last = offset
		}
	}
	return true
}

pub fn is_loosely_sorted_by_offset(keyframes []BaseKeyframe) bool {
	return keyframes_loosely_sorted(keyframes)
}

fn animation_property_id(name string) ?css.PropertyID {
	if name == 'cssFloat' { return .float_ }
	if name in ['cssOffset', 'float', 'offset'] { return none }
	mut normalized := ''
	for index, character in name.runes() {
		if character >= `A` && character <= `Z` {
			if index > 0 { normalized += '-' }
			normalized += character.str().to_lower()
		} else {
			normalized += character.str()
		}
	}
	return css.property_id_from_string(normalized)
}

fn process_keyframes(input []BaseKeyframe) ![]BaseKeyframe {
	mut keyframes := input.clone()
	if !keyframes_loosely_sorted(keyframes) {
		return error('Keyframes are not in ascending order based on offset')
	}
	for index, mut keyframe in keyframes {
		if offset := keyframe.offset {
			if offset < 0 || offset > 1 {
				return error('Keyframe ${index} has invalid offset value ${offset}')
			}
		}
		keyframe.parsed_properties = map[css.PropertyID]&dom.StyleValue{}
		keyframe.parsed_custom_properties = map[string]&dom.StyleValue{}
		for name, text in keyframe.properties {
			if name.starts_with('--') && name.len > 2 {
				keyframe.parsed_custom_properties[name] = css.parse_custom_property_value(text)
				continue
			}
			property_id := animation_property_id(name) or { continue }
			// Properties that are not animatable are ignored, as in @keyframes rules.
			if !css.is_animatable_property(property_id) { continue }
			value := css.parse_css_value(css.ParsingParams{}, text, property_id) or { continue }
			unsafe {
				keyframe.parsed_properties[property_id] = value
			}
		}
		_ = parse_easing_string(keyframe.easing) or {
			return error('Invalid animation easing value: "${keyframe.easing}"')
		}
	}
	compute_missing_keyframe_offsets(mut keyframes)
	return keyframes
}

// The JavaScript binding layer performs scalar/list conversion before values
// enter this typed translation. This helper preserves the scalar branch of
// the upstream generic operation; list-valued members are already []T.
pub fn convert_value_to_maybe_list[T](value T) []T {
	return [value]
}

pub fn process_a_keyframe_like_object(input BaseKeyframe) !BaseKeyframe {
	processed := process_keyframes([input])!
	return processed[0]
}

pub fn process_a_keyframes_argument(input []BaseKeyframe) ![]BaseKeyframe {
	return process_keyframes(input)
}

pub fn process_property_indexed_keyframes(input BasePropertyIndexedKeyframe) ![]BaseKeyframe {
	for easing in input.easings {
		_ = parse_easing_string(easing) or {
			return error('Invalid animation easing value: "${easing}"')
		}
	}
	mut keyframes := []BaseKeyframe{}
	for property_name, values in input.properties {
		mut property_frames := []BaseKeyframe{len: values.len, init: BaseKeyframe{
			properties: map[string]string{}
		}}
		for index, value in values {
			property_frames[index].properties[property_name] = value
		}
		compute_missing_keyframe_offsets(mut property_frames)
		keyframes << property_frames
	}
	// Keep this explicit: option-valued expressions inside V's generated sort
	// comparator are not supported by all compiler versions used by this port.
	for i := 0; i < keyframes.len; i++ {
		for j := i + 1; j < keyframes.len; j++ {
			left := keyframes[i].computed_offset or { 0.0 }
			right := keyframes[j].computed_offset or { 0.0 }
			if right < left {
				temporary := keyframes[i]
				keyframes[i] = keyframes[j]
				keyframes[j] = temporary
			}
		}
	}
	mut merged := []BaseKeyframe{}
	for frame in keyframes {
		if merged.len > 0 && merged[merged.len - 1].computed_offset == frame.computed_offset {
			for name, value in frame.properties {
				merged[merged.len - 1].properties[name] = value
			}
		} else {
			merged << frame
		}
	}
	for index, offset in input.offsets {
		if index >= merged.len { break
		 }
		merged[index].offset = offset
	}
	mut easings := if input.easings.len == 0 { ['linear'] } else { input.easings.clone() }
	base_easing_count := easings.len
	for easings.len < merged.len {
		easings << easings[easings.len % base_easing_count]
	}
	for index, mut frame in merged {
		frame.easing = easings[index % easings.len]
		if input.composites.len > 0 {
			composite := input.composites[index % input.composites.len]
			if composite != .auto_ { frame.composite = composite }
		}
	}
	return process_keyframes(merged)
}

@[heap]
struct KeyframeLonghands {
mut:
	values map[css.PropertyID]&dom.StyleValue
}

fn (mut effect KeyframeEffect) install_processed_keyframes(input []BaseKeyframe) {
	effect.keyframes_ = input.clone()
	compute_missing_keyframe_offsets(mut effect.keyframes_)
	effect.target_properties_.clear()
	effect.target_custom_properties_.clear()
	mut set := KeyFrameSet{}
	for keyframe in effect.keyframes_ {
		mut resolved := ResolvedKeyframe{
			composite: keyframe.composite
			easing:    parse_easing_string(keyframe.easing)
		}
		// Keyframe values are sampled per longhand. Expand shorthands first, so
		// that a longhand specified in the same keyframe takes precedence.
		mut longhands := &KeyframeLonghands{}
		for pass in 0 .. 2 {
			for property_id, value in keyframe.parsed_properties {
				if css.property_is_shorthand(property_id) != (pass == 0) { continue }
				css.StyleComputer.for_each_property_expanding_shorthands_with_context(property_id, value,
					voidptr(longhands), fn (context voidptr, id css.PropertyID, longhand &dom.StyleValue) {
					mut target := unsafe { &KeyframeLonghands(context) }
					target.values[id] = unsafe { longhand }
				})
			}
		}
		for property_id, value in longhands.values {
			resolved.properties[property_id] = ResolvedProperty{
				value: unsafe { value }
			}
			effect.target_properties_[property_id] = true
		}
		for name, value in keyframe.parsed_custom_properties {
			resolved.custom_properties[name] = ResolvedProperty{ value: unsafe { value } }
			effect.target_custom_properties_[name] = true
		}
		offset := keyframe.computed_offset or { continue }
		set.keyframes_by_key[u64(offset * 100_000.0)] = resolved
	}
	generate_initial_and_final_frames(mut set, effect.target_properties_)
	generate_initial_and_final_custom_frames(mut set, effect.target_custom_properties_)
	effect.key_frame_set_ = set
	effect.invalidate_animation_preparation()
	effect.invalidate_effect()
}

pub fn (mut effect KeyframeEffect) set_keyframes(input []BaseKeyframe) ! {
	processed_keyframes := process_keyframes(input)!
	effect.install_processed_keyframes(processed_keyframes)
}

pub fn (mut effect KeyframeEffect) set_keyframes_from_js(input []BaseKeyframe) ! {
	processed_keyframes := process_a_keyframes_argument(input)!
	effect.install_processed_keyframes(processed_keyframes)
}

pub fn (mut effect KeyframeEffect) set_key_frame_set(set KeyFrameSet) {
	effect.target_properties_.clear()
	effect.target_custom_properties_.clear()
	for _, keyframe in set.keyframes_by_key {
		for property_id, _ in keyframe.properties {
			effect.target_properties_[property_id] = true
		}
		for name, _ in keyframe.custom_properties {
			effect.target_custom_properties_[name] = true
		}
	}
	effect.key_frame_set_ = set
	effect.invalidate_animation_preparation()
	effect.invalidate_effect()
}

pub fn (mut effect KeyframeEffect) invalidate_effect() {
	effect.compositor_opacity_keyframe_value_cache_ = none
	effect.compositor_background_color_keyframe_value_cache_ = none
	effect.compositor_filter_keyframe_value_cache_ = none
	effect.compositor_transform_keyframe_value_cache_ = none
	effect.is_compositor_driven_ = false
	effect.is_compositor_replaced_ = false
	effect.retained_compositor_animations_.clear()
	effect.is_offscreen_throttled_ = false
	effect.is_observation_relevant_compositor_animation_ = false
	effect.clear_per_frame_style_update_cache()
	if target := effect.target_element_ {
		if target.document() != unsafe { nil } {
			mut document := unsafe { &dom.Document(target.document()) }
			document.set_needs_animated_style_update()
		}
	}
}

pub fn (effect &KeyframeEffect) animation_preparation_identity() u64 {
	return effect.animation_preparation_identity_
}

pub fn (effect &KeyframeEffect) animation_preparation_generation() u64 {
	return effect.animation_preparation_generation_
}

pub fn (mut effect KeyframeEffect) invalidate_animation_preparation() {
	effect.animation_preparation_generation_++
}

pub fn (effect &KeyframeEffect) is_compositor_driven() bool {
	return effect.is_compositor_driven_
}

pub fn (mut effect KeyframeEffect) set_is_compositor_driven(value bool) {
	if effect.is_compositor_driven_ == value {
		return
	}
	effect.is_compositor_driven_ = value
	effect.clear_per_frame_style_update_cache()
}

pub fn (effect &KeyframeEffect) is_compositor_replaced() bool {
	return effect.is_compositor_replaced_
}

pub fn (mut effect KeyframeEffect) set_is_compositor_replaced(value bool) {
	if effect.is_compositor_replaced_ == value {
		return
	}
	effect.is_compositor_replaced_ = value
	effect.clear_per_frame_style_update_cache()
}

pub fn (effect &KeyframeEffect) retained_compositor_animations() []compositor.VisualAnimation {
	return effect.retained_compositor_animations_.clone()
}

pub fn (mut effect KeyframeEffect) set_retained_compositor_animations(values []compositor.VisualAnimation) {
	effect.retained_compositor_animations_ = values.clone()
}

pub fn (mut effect KeyframeEffect) clear_retained_compositor_animations() {
	effect.retained_compositor_animations_.clear()
}

pub fn (effect &KeyframeEffect) is_offscreen_throttled() bool {
	return effect.is_offscreen_throttled_
}

pub fn (mut effect KeyframeEffect) set_is_offscreen_throttled(value bool) {
	if effect.is_offscreen_throttled_ == value {
		return
	}
	effect.is_offscreen_throttled_ = value
	effect.clear_per_frame_style_update_cache()
}

pub fn (effect &KeyframeEffect) is_observation_relevant_compositor_animation() bool {
	return effect.is_observation_relevant_compositor_animation_
}

pub fn (mut effect KeyframeEffect) set_is_observation_relevant_compositor_animation(value bool) {
	effect.is_observation_relevant_compositor_animation_ = value
}

pub fn (mut effect KeyframeEffect) clear_per_frame_style_update_cache() {
	effect.can_skip_per_frame_style_update_cache_ = none
}

pub fn (mut effect KeyframeEffect) request_observation_sample() {
	if effect.needs_observation_sample_ {
		return
	}
	effect.needs_observation_sample_ = true
	if target := effect.target_element_ {
		if target.document() != unsafe { nil } {
			mut document := unsafe { &dom.Document(target.document()) }
			document.set_needs_animated_style_update()
		}
	}
}

pub fn (mut effect KeyframeEffect) request_element_scoped_observation_sample(task_generation u64) bool {
	if previous := effect.last_element_scoped_observation_task_generation_ {
		if previous == task_generation {
			return false
		}
	}
	effect.last_element_scoped_observation_task_generation_ = task_generation
	effect.request_observation_sample()
	return true
}

pub fn (effect &KeyframeEffect) observation_sample_requested() bool {
	return effect.needs_observation_sample_
}

pub fn (mut effect KeyframeEffect) consume_observation_sample_request() bool {
	was_requested := effect.needs_observation_sample_
	effect.needs_observation_sample_ = false
	return was_requested
}

pub fn (effect &KeyframeEffect) per_frame_animation_tick_was_skipped() bool {
	return effect.per_frame_animation_tick_was_skipped_
}

pub fn (mut effect KeyframeEffect) note_per_frame_animation_tick_was_skipped() {
	effect.per_frame_animation_tick_was_skipped_ = true
}

pub fn (mut effect KeyframeEffect) clear_per_frame_animation_tick_was_skipped() {
	effect.per_frame_animation_tick_was_skipped_ = false
}

pub fn (effect &KeyframeEffect) compositor_keyframe_value_cache(target_kind compositor.VisualAnimationTargetKind) ?CompositorKeyframeValueCache {
	return match target_kind {
		.opacity { effect.compositor_opacity_keyframe_value_cache_ }
		.background_color { effect.compositor_background_color_keyframe_value_cache_ }
		.filter { effect.compositor_filter_keyframe_value_cache_ }
		.transform { effect.compositor_transform_keyframe_value_cache_ }
	}
}

pub fn (mut effect KeyframeEffect) set_compositor_keyframe_value_cache(target_kind compositor.VisualAnimationTargetKind, cache ?CompositorKeyframeValueCache) {
	match target_kind {
		.opacity {
			effect.compositor_opacity_keyframe_value_cache_ = cache
		}
		.background_color {
			effect.compositor_background_color_keyframe_value_cache_ = cache
		}
		.filter {
			effect.compositor_filter_keyframe_value_cache_ = cache
		}
		.transform {
			effect.compositor_transform_keyframe_value_cache_ = cache
		}
	}
}

pub fn (effect &KeyframeEffect) can_skip_per_frame_style_update() bool {
	if effect.is_compositor_driven_ || effect.is_compositor_replaced_ {
		return true
	}
	if !math.is_inf(effect.iteration_count_, 1) || effect.pseudo_element_type() != none {
		return false
	}
	target := effect.target_element_ or { return false }
	if !target.as_node().is_connected() {
		return true
	}
	if target.document() != unsafe { nil } && target.document().layout_is_up_to_date()
		&& !effect.may_animate_display() && target_is_unseen_in_display_none_subtree(target) {
		return true
	}
	if target.namespace_uri() or { '' } == 'http://www.w3.org/2000/svg' {
		return false
	}
	mut has_animated_property := false
	for _, keyframe in effect.key_frame_set_.keyframes_by_key {
		if keyframe.custom_properties.len > 0 {
			return false
		}
		for property_id, _ in keyframe.properties {
			has_animated_property = true
			if property_id !in [.transform, .translate, .rotate, .scale] {
				return false
			}
		}
	}
	if !has_animated_property {
		return false
	}
	if effect.is_offscreen_throttled_ {
		return true
	}
	if target.document() == unsafe { nil } || !target.document().layout_is_up_to_date() {
		return false
	}
	layout_node_with_style := target.el_unsafe_layout_node() or { return false }
	layout_node := layout_node_with_style.layout_node_ or { return false }
	if layout_node.visibility_ != .hidden {
		return false
	}
	mut descendants := layout_node.children_.clone()
	for descendants.len > 0 {
		descendant := descendants.pop()
		if descendant.visibility_ == .visible {
			return false
		}
		descendants << descendant.children_
	}
	return true
}

pub fn (effect &KeyframeEffect) can_skip_per_frame_animation_tick() bool {
	if animation := effect.associated_animation_ {
		if !animation.pending() && animation.play_state() == .running
			&& animation.playback_rate() > 0 {
			if timeline := animation.timeline_ {
				if timeline.is_monotonically_increasing() && effect.is_in_the_before_phase() {
					return true
				}
			}
		}
	}
	if !effect.is_compositor_driven_ && !effect.is_compositor_replaced_
		&& !effect.can_skip_per_frame_style_update() {
		return false
	}
	// Infinite effects can still finish while playing backwards, or when
	// their iteration duration is zero. Neither case has a wake-up timer.
	if animation := effect.associated_animation_ {
		if math.is_inf(effect.iteration_count_, 1)
			&& (animation.playback_rate() < 0 || !math.is_inf(effect.end_time().value, 1)) {
			return false
		}
	}
	if (effect.is_compositor_driven_ || effect.is_compositor_replaced_)
		&& (!math.is_inf(effect.iteration_count_, 1)
			|| effect.is_observation_relevant_compositor_animation_) {
		return true
	}
	target := effect.target_element_ or { return false }
	for event_name in ['animationcancel', 'animationiteration', 'animationstart',
		'webkitAnimationIteration', 'webkitAnimationStart'] {
		if target.as_node().has_inclusive_ancestor_with_event_listener(event_name) {
			return false
		}
	}
	return true
}

pub fn generate_initial_and_final_frames(mut set KeyFrameSet, properties map[css.PropertyID]bool) {
	mut initial := set.keyframes_by_key[u64(0)] or { ResolvedKeyframe{} }
	mut final := set.keyframes_by_key[u64(100_000)] or { ResolvedKeyframe{} }
	mut initial_properties := map[css.PropertyID]bool{}
	mut final_properties := map[css.PropertyID]bool{}
	for property_id, _ in initial.properties {
		if css.property_is_shorthand(property_id) {
			for id in css.generated_expanded_longhands_for_shorthand(property_id) { initial_properties[id] = true }
		} else { initial_properties[property_id] = true }
	}
	for property_id, _ in final.properties {
		if css.property_is_shorthand(property_id) {
			for id in css.generated_expanded_longhands_for_shorthand(property_id) { final_properties[id] = true }
		} else { final_properties[property_id] = true }
	}
	for property_id, enabled in properties {
		if !enabled { continue
		 }
		if property_id !in initial_properties {
			initial.properties[property_id] = ResolvedProperty{
				use_initial: true
			}
		}
		if property_id !in final_properties {
			final.properties[property_id] = ResolvedProperty{
				use_initial: true
			}
		}
	}
	set.keyframes_by_key[0] = initial
	set.keyframes_by_key[100_000] = final
}

pub fn KeyframeEffect.generate_initial_and_final_frames(mut set KeyFrameSet, properties map[css.PropertyID]bool) {
	generate_initial_and_final_frames(mut set, properties)
}

fn generate_initial_and_final_custom_frames(mut set KeyFrameSet, properties map[string]bool) {
	mut initial := set.keyframes_by_key[u64(0)] or { ResolvedKeyframe{} }
	mut final := set.keyframes_by_key[u64(100_000)] or { ResolvedKeyframe{} }
	for name, enabled in properties {
		if !enabled { continue }
		if name !in initial.custom_properties {
			initial.custom_properties[name] = ResolvedProperty{ use_initial: true }
		}
		if name !in final.custom_properties {
			final.custom_properties[name] = ResolvedProperty{ use_initial: true }
		}
	}
	set.keyframes_by_key[0] = initial
	set.keyframes_by_key[100_000] = final
}

// The CSS sampler is the translated StyleComputer effect-stack algorithm.
// Adapt the same resolved keyframes, target, composition and timing into its
// cycle-free view rather than sampling Web Animations through another algorithm.
pub fn (mut effect KeyframeEffect) css_effect_for_style() &css.KeyframeEffect {
	mut sampling_effect := effect.css_sampling_effect_ or { css.KeyframeEffect.create() }
	mut frames := &css.KeyFrameSet{}
	for key, frame in effect.key_frame_set_.keyframes_by_key {
		mut resolved := css.ResolvedKeyFrame{}
		if frame.composite != .auto_ {
			resolved.composite = match frame.composite {
				.replace { css.CompositeOperation.replace }
				.add { css.CompositeOperation.add }
				.accumulate { css.CompositeOperation.accumulate }
				.auto_ { css.CompositeOperation.replace }
			}
		}
		if easing := frame.easing {
			resolved.easing = css.ResolvedKeyframeEasing(easing)
		}
		for id, property in frame.properties {
			if property.use_initial {
				resolved.use_initial_properties[id] = true
			} else if value := property.value {
				resolved.properties[id] = unsafe { value }
			}
		}
		for name, property in frame.custom_properties {
			if property.use_initial {
				resolved.use_initial_custom_properties[name] = true
			} else if value := property.value {
				resolved.custom_properties[name] = unsafe { value }
			}
		}
		frames.keyframes_by_key[int(key)] = resolved
	}
	sampling_effect.target_ = effect.target_abstract_element()
	sampling_effect.key_frame_set = frames
	sampling_effect.composite = match effect.composite_ {
		.replace { css.CompositeOperation.replace }
		.add { css.CompositeOperation.add }
		.accumulate { css.CompositeOperation.accumulate }
	}
	sampling_effect.output_progress = effect.transformed_progress()
	sampling_effect.iteration_composite_accumulate = effect.iteration_composite_accumulate_
	sampling_effect.current_iteration = effect.current_iteration() or { 0 }
	sampling_effect.default_easing = css.EasingFunction.linear()
	effect.css_sampling_effect_ = sampling_effect
	return sampling_effect
}

pub fn (effect &KeyframeEffect) target_abstract_element() ?dom.AbstractElement {
	target := effect.target_element_ or { return none }
	css_pseudo := effect.pseudo_element_type() or {
		return dom.AbstractElement.new(target, none)
	}
	mut pseudo := ?dom.PseudoElement(none)
	match css_pseudo {
		.before { pseudo = dom.PseudoElement.before }
		.after { pseudo = dom.PseudoElement.after }
		.first_line { pseudo = dom.PseudoElement.first_line }
		.first_letter { pseudo = dom.PseudoElement.first_letter }
		.marker { pseudo = dom.PseudoElement.marker }
		.placeholder { pseudo = dom.PseudoElement.placeholder }
		.selection { pseudo = dom.PseudoElement.selection }
		.backdrop { pseudo = dom.PseudoElement.backdrop }
		else {}
	}
	return dom.AbstractElement.new(target, pseudo)
}

pub fn (effect &KeyframeEffect) is_keyframe_effect() bool {
	return true
}

pub fn keyframe_effect_composite_order(a &KeyframeEffect, b &KeyframeEffect) int {
	a_animation := a.associated_animation_ or { return 0 }
	b_animation := b.associated_animation_ or { return 0 }
	if a_animation.animation_class_ != b_animation.animation_class_ {
		return int(a_animation.animation_class_) - int(b_animation.animation_class_)
	}
	if a_animation.class_composite_order_ != b_animation.class_composite_order_ {
		return a_animation.class_composite_order_ - b_animation.class_composite_order_
	}
	if a_animation.global_animation_list_order_ < b_animation.global_animation_list_order_ {
		return -1
	}
	if a_animation.global_animation_list_order_ > b_animation.global_animation_list_order_ {
		return 1
	}
	return 0
}

// Samples the keyframe set at the effect's transformed progress. StyleComputer
// owns cascade invalidation; this method supplies the same typed property map
// without introducing a css -> animations import cycle.
pub fn (effect &KeyframeEffect) update_computed_properties() map[css.PropertyID]&dom.StyleValue {
	mut output := map[css.PropertyID]&dom.StyleValue{}
	progress := effect.transformed_progress() or { return output }
	target := effect.target_element_ or { return output }
	mut keys := effect.key_frame_set_.keyframes_by_key.keys()
	keys.sort()
	if keys.len == 0 { return output }
	position := u64(math.max(0.0, math.min(1.0, progress)) * 100_000.0)
	mut start_key := keys[0]
	mut end_key := keys[keys.len - 1]
	for key in keys {
		if key <= position { start_key = key }
		if key >= position {
			end_key = key
			break
		}
	}
	start := effect.key_frame_set_.keyframes_by_key[start_key] or { return output }
	end := effect.key_frame_set_.keyframes_by_key[end_key] or { return output }
	delta := if end_key == start_key {
		0.0
	} else {
		f64(position - start_key) / f64(end_key - start_key)
	}
	for property_id, start_property in start.properties {
		start_value := start_property.value or { continue }
		end_property := end.properties[property_id] or { continue }
		end_value := end_property.value or { continue }
		if interpolated := css.interpolate_property(target, property_id, start_value, end_value,
			delta, .no)
		{
			unsafe {
				output[property_id] = interpolated
			}
		} else if delta < 0.5 {
			unsafe {
				output[property_id] = start_value
			}
		} else {
			unsafe {
				output[property_id] = end_value
			}
		}
	}
	return output
}

pub fn composite_operation_from_css(value css.AnimationComposition) CompositeOperation {
	return match value {
		.replace { .replace }
		.add { .add }
		.accumulate { .accumulate }
	}
}

pub fn composite_operation_or_auto_from_css(value css.AnimationComposition) CompositeOperationOrAuto {
	return match value {
		.replace { .replace }
		.add { .add }
		.accumulate { .accumulate }
	}
}

pub fn css_animation_composition_to_bindings_composite_operation(value css.AnimationComposition) CompositeOperation {
	return composite_operation_from_css(value)
}

pub fn css_animation_composition_to_bindings_composite_operation_or_auto(value css.AnimationComposition) CompositeOperationOrAuto {
	return composite_operation_or_auto_from_css(value)
}

pub fn css_animation_composition_to_composite_operation(value css.AnimationComposition) CompositeOperation {
	return css_animation_composition_to_bindings_composite_operation(value)
}

pub fn css_animation_composition_to_composite_operation_or_auto(value css.AnimationComposition) CompositeOperationOrAuto {
	return css_animation_composition_to_bindings_composite_operation_or_auto(value)
}

pub fn composite_operation_or_auto_to_string(value CompositeOperationOrAuto) string {
	return match value {
		.replace { 'replace' }
		.add { 'add' }
		.accumulate { 'accumulate' }
		.auto_ { 'auto' }
	}
}

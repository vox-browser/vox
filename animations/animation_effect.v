// Copyright (c) 2023-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Animations/AnimationEffect.{h,cpp}.
module animations

import css
import dom
import math

pub enum FillMode {
	none_
	forwards
	backwards
	both
	auto_
}

pub enum PlaybackDirection {
	normal
	reverse
	alternate
	alternate_reverse
}

pub enum AnimationDirection {
	forwards
	backwards
}

pub enum EffectPhase {
	before
	active
	after
	idle
}

pub type IterationDuration = f64 | string

pub struct OptionalEffectTiming {
pub mut:
	delay           ?f64
	end_delay       ?f64
	fill            ?FillMode
	iteration_start ?f64
	iterations      ?f64
	duration        ?IterationDuration
	direction       ?PlaybackDirection
	easing          ?string
}

pub struct EffectTiming {
pub:
	delay           f64
	end_delay       f64
	fill            FillMode
	iteration_start f64
	iterations      f64
	duration        IterationDuration
	direction       PlaybackDirection
	easing          string
}

pub fn (timing EffectTiming) to_optional_effect_timing() OptionalEffectTiming {
	return OptionalEffectTiming{
		delay:           timing.delay
		end_delay:       timing.end_delay
		fill:            timing.fill
		iteration_start: timing.iteration_start
		iterations:      timing.iterations
		duration:        timing.duration
		direction:       timing.direction
		easing:          timing.easing
	}
}

pub fn css_fill_mode_to_bindings_fill_mode(mode css.AnimationFillMode) FillMode {
	return match mode {
		.none_ { .none_ }
		.forwards { .forwards }
		.backwards { .backwards }
		.both { .both }
	}
}

pub fn css_animation_direction_to_bindings_playback_direction(direction css.AnimationDirection) PlaybackDirection {
	return match direction {
		.normal { .normal }
		.reverse { .reverse }
		.alternate { .alternate }
		.alternate_reverse { .alternate_reverse }
	}
}

pub struct ComputedEffectTiming {
	EffectTiming
pub:
	computed_duration CSSNumberish
	end_time          CSSNumberish
	active_duration   CSSNumberish
	local_time        ?CSSNumberish
	progress          ?f64
	current_iteration ?f64
}

@[heap]
pub struct AnimationEffect {
pub mut:
	specified_start_delay_        f64
	start_delay_                  TimeValue = TimeValue.milliseconds(0)
	specified_end_delay_          f64
	end_delay_                    TimeValue = TimeValue.milliseconds(0)
	fill_mode_                    FillMode  = .auto_
	iteration_start_              f64
	iteration_count_              f64               = 1.0
	specified_iteration_duration_ IterationDuration = IterationDuration('auto')
	iteration_duration_           TimeValue         = TimeValue.milliseconds(0)
	playback_direction_           PlaybackDirection
	associated_animation_         ?&Animation
	timing_function_              css.EasingFunction = css.EasingFunction.linear()
	previous_phase_               EffectPhase        = .idle
	previous_current_iteration_   f64
	target_properties_            map[css.PropertyID]bool
	has_target_                   bool
	is_keyframe_effect_           bool
}

pub fn AnimationEffect.new() &AnimationEffect {
	return &AnimationEffect{}
}

// Base AnimationEffect has no target. KeyframeEffect supplies the concrete
// target accessor, matching the virtual default in AnimationEffect.h.
pub fn (_ &AnimationEffect) target() ?&dom.Element {
	return none
}

pub fn parse_easing_string(value string) ?css.EasingFunction {
	return css.parse_easing_function(value)
}

pub fn AnimationEffect.parse_easing_string(value string) ?css.EasingFunction {
	return parse_easing_string(value)
}

pub fn (effect &AnimationEffect) get_timing() EffectTiming {
	return EffectTiming{
		delay:           effect.specified_start_delay_
		end_delay:       effect.specified_end_delay_
		fill:            effect.fill_mode_
		iteration_start: effect.iteration_start_
		iterations:      effect.iteration_count_
		duration:        effect.specified_iteration_duration_
		direction:       effect.playback_direction_
		easing:          effect.timing_function_.to_string()
	}
}

pub fn (effect &AnimationEffect) get_computed_timing() ComputedEffectTiming {
	fill := if effect.fill_mode_ == .auto_ { FillMode.none_ } else { effect.fill_mode_ }
	local := effect.local_time()
	return ComputedEffectTiming{
		EffectTiming:      EffectTiming{
			delay:           effect.specified_start_delay_
			end_delay:       effect.specified_end_delay_
			fill:            fill
			iteration_start: effect.iteration_start_
			iterations:      effect.iteration_count_
			duration:        IterationDuration(effect.iteration_duration_.value)
			direction:       effect.playback_direction_
			easing:          effect.timing_function_.to_string()
		}
		computed_duration: effect.iteration_duration_.as_css_numberish()
		end_time:          effect.end_time().as_css_numberish()
		active_duration:   effect.active_duration().as_css_numberish()
		local_time:        if value := local { value.as_css_numberish() } else { none }
		progress:          effect.transformed_progress()
		current_iteration: effect.current_iteration()
	}
}

pub fn (mut effect AnimationEffect) update_timing(timing OptionalEffectTiming) ! {
	if value := timing.iteration_start {
		if value < 0 {
			return error('Invalid iteration start value')
		}
	}
	if value := timing.iterations {
		if value < 0 || math.is_nan(value) {
			return error('Invalid iteration count value')
		}
	}
	if duration := timing.duration {
		match duration {
			f64 {
				if duration < 0 || math.is_nan(duration) {
					return error('Invalid duration value')
				}
			}
			string {
				if duration != 'auto' {
					return error('Invalid duration value')
				}
			}
		}
	}
	mut parsed_easing := ?css.EasingFunction(none)
	if easing := timing.easing {
		parsed_easing = parse_easing_string(easing) or { return error('Invalid easing function') }
	}
	if value := timing.delay { effect.specified_start_delay_ = value }
	if value := timing.end_delay { effect.specified_end_delay_ = value }
	if value := timing.fill { effect.fill_mode_ = value }
	if value := timing.iteration_start { effect.iteration_start_ = value }
	if value := timing.iterations { effect.iteration_count_ = value }
	if value := timing.duration { effect.specified_iteration_duration_ = value }
	if value := timing.direction { effect.playback_direction_ = value }
	if value := parsed_easing { effect.timing_function_ = value }
	effect.normalize_specified_timing()
	if mut animation := effect.associated_animation_ {
		animation.effect_timing_changed()
	}
}

pub fn (effect &AnimationEffect) associated_timeline() ?&AnimationTimeline {
	animation := effect.associated_animation_ or { return none }
	return animation.timeline_
}

pub fn (effect &AnimationEffect) timeline_duration() ?TimeValue {
	timeline := effect.associated_timeline() or { return none }
	return timeline.duration()
}

pub fn (effect &AnimationEffect) intrinsic_iteration_duration() TimeValue {
	if effect.timeline_duration() == none || effect.iteration_count_ == 0 {
		return TimeValue.zero_for_timeline(effect.associated_timeline())
	}
	total := TimeValue.percentage(100)
	remaining := total.subtract(effect.start_delay_) or { return TimeValue.percentage(0) }
	remaining_after_end := remaining.subtract(effect.end_delay_) or {
		return TimeValue.percentage(0)
	}
	return remaining_after_end.divide(effect.iteration_count_)
}

fn (mut effect AnimationEffect) convert_to_proportional_animation() {
	match effect.specified_iteration_duration_ {
		string {
			effect.start_delay_ = TimeValue.zero_for_timeline(effect.associated_timeline())
			effect.end_delay_ = TimeValue.zero_for_timeline(effect.associated_timeline())
			effect.iteration_duration_ = effect.intrinsic_iteration_duration()
			return
		}
		f64 {}
	}
	timeline_duration := effect.timeline_duration() or { return }
	duration := match effect.specified_iteration_duration_ {
		f64 { effect.specified_iteration_duration_ }
		string { 0.0 }
	}
	total_time := math.max(effect.specified_start_delay_ + duration * effect.iteration_count_ +
		effect.specified_end_delay_, 0)
	if total_time == 0 {
		effect.start_delay_ = TimeValue.zero_for_timeline(effect.associated_timeline())
		effect.iteration_duration_ = TimeValue.zero_for_timeline(effect.associated_timeline())
		effect.end_delay_ = TimeValue.zero_for_timeline(effect.associated_timeline())
		return
	}
	effect.start_delay_ = timeline_duration.multiply(effect.specified_start_delay_ / total_time)
	effect.iteration_duration_ = timeline_duration.multiply(duration / total_time)
	effect.end_delay_ = timeline_duration.multiply(effect.specified_end_delay_ / total_time)
}

pub fn (mut effect AnimationEffect) convert_a_time_based_animation_to_a_proportional_animation() {
	effect.convert_to_proportional_animation()
}

pub fn (mut effect AnimationEffect) normalize_specified_timing() {
	if effect.timeline_duration() != none {
		effect.convert_a_time_based_animation_to_a_proportional_animation()
		return
	}
	effect.start_delay_ = TimeValue.milliseconds(effect.specified_start_delay_)
	effect.end_delay_ = TimeValue.milliseconds(effect.specified_end_delay_)
	effect.iteration_duration_ = match effect.specified_iteration_duration_ {
		f64 { TimeValue.milliseconds(effect.specified_iteration_duration_) }
		string { effect.intrinsic_iteration_duration() }
	}
}

pub fn (effect &AnimationEffect) start_delay() TimeValue {
	return effect.start_delay_
}

pub fn (mut effect AnimationEffect) set_specified_start_delay(value f64) {
	effect.specified_start_delay_ = value
}

pub fn (effect &AnimationEffect) end_delay() TimeValue {
	return effect.end_delay_
}

pub fn (mut effect AnimationEffect) set_specified_end_delay(value f64) {
	effect.specified_end_delay_ = value
}

pub fn (effect &AnimationEffect) fill_mode() FillMode {
	return effect.fill_mode_
}

pub fn (mut effect AnimationEffect) set_fill_mode(value FillMode) {
	effect.fill_mode_ = value
}

pub fn (effect &AnimationEffect) iteration_start() f64 {
	return effect.iteration_start_
}

pub fn (mut effect AnimationEffect) set_iteration_start(value f64) {
	effect.iteration_start_ = value
}

pub fn (effect &AnimationEffect) iteration_count() f64 {
	return effect.iteration_count_
}

pub fn (mut effect AnimationEffect) set_iteration_count(value f64) {
	effect.iteration_count_ = value
}

pub fn (effect &AnimationEffect) iteration_duration() TimeValue {
	return effect.iteration_duration_
}

pub fn (mut effect AnimationEffect) set_specified_iteration_duration(value IterationDuration) {
	effect.specified_iteration_duration_ = value
}

pub fn (effect &AnimationEffect) playback_direction() PlaybackDirection {
	return effect.playback_direction_
}

pub fn (mut effect AnimationEffect) set_playback_direction(value PlaybackDirection) {
	effect.playback_direction_ = value
}

pub fn (effect &AnimationEffect) timing_function() css.EasingFunction {
	return effect.timing_function_
}

pub fn (mut effect AnimationEffect) set_timing_function(value css.EasingFunction) {
	effect.timing_function_ = value
}

pub fn (effect &AnimationEffect) previous_phase() EffectPhase {
	return effect.previous_phase_
}

pub fn (mut effect AnimationEffect) set_previous_phase(value EffectPhase) {
	effect.previous_phase_ = value
}

pub fn (effect &AnimationEffect) previous_current_iteration() f64 {
	return effect.previous_current_iteration_
}

pub fn (mut effect AnimationEffect) set_previous_current_iteration(value f64) {
	effect.previous_current_iteration_ = value
}

pub fn (effect &AnimationEffect) target_properties() map[css.PropertyID]bool {
	return effect.target_properties_.clone()
}

pub fn (effect &AnimationEffect) is_keyframe_effect() bool {
	return effect.is_keyframe_effect_
}

pub fn (mut effect AnimationEffect) set_associated_animation(animation ?&Animation) {
	effect.associated_animation_ = animation
	effect.normalize_specified_timing()
}

pub fn (effect &AnimationEffect) animation_direction() AnimationDirection {
	if animation := effect.associated_animation_ {
		if animation.playback_rate_ < 0 {
			return .backwards
		}
	}
	return .forwards
}

pub fn (effect &AnimationEffect) end_time() TimeValue {
	zero := TimeValue.zero_for_timeline(effect.associated_timeline())
	return time_max(effect.start_delay_.add(effect.active_duration()) or { zero }.add(effect.end_delay_) or {
		zero
	}, zero)
}

pub fn (effect &AnimationEffect) local_time() ?TimeValue {
	animation := effect.associated_animation_ or { return none }
	return animation.current_time()
}

pub fn (effect &AnimationEffect) active_duration() TimeValue {
	if effect.iteration_duration_.value == 0 || effect.iteration_count_ == 0 {
		return TimeValue.zero_for_timeline(effect.associated_timeline())
	}
	return effect.iteration_duration_.multiply(effect.iteration_count_)
}

pub fn (effect &AnimationEffect) active_time() ?TimeValue {
	return effect.active_time_using_fill(effect.fill_mode_)
}

pub fn (effect &AnimationEffect) active_time_using_fill(fill FillMode) ?TimeValue {
	zero := TimeValue.zero_for_timeline(effect.associated_timeline())
	local := effect.local_time() or { return none }
	if effect.is_in_the_before_phase() {
		if fill in [.backwards, .both] {
			return time_max(local.subtract(effect.start_delay_) or { return none }, zero)
		}
		return none
	}
	if effect.is_in_the_active_phase() {
		return local.subtract(effect.start_delay_) or { return none }
	}
	if effect.is_in_the_after_phase() {
		if fill in [.forwards, .both] {
			elapsed := local.subtract(effect.start_delay_) or { return none }
			return time_max(time_min(elapsed, effect.active_duration()), zero)
		}
	}
	return none
}

pub fn (effect &AnimationEffect) is_in_play() bool {
	animation := effect.associated_animation_ or { return false }
	return effect.is_in_the_active_phase() && !animation.is_finished_
}

pub fn (effect &AnimationEffect) is_current() bool {
	if effect.is_in_play() { return true }
	if animation := effect.associated_animation_ {
		if animation.playback_rate_ > 0 && effect.is_in_the_before_phase() { return true }
		if animation.playback_rate_ < 0 && effect.is_in_the_after_phase() { return true }
		if animation.play_state() != .idle {
			if timeline := animation.timeline_ {
				if !timeline.is_monotonically_increasing() { return true }
			}
		}
	}
	return false
}

pub fn (effect &AnimationEffect) is_in_effect() bool {
	return effect.active_time() != none
}

pub fn (effect &AnimationEffect) before_active_boundary_time() TimeValue {
	zero := TimeValue.zero_for_timeline(effect.associated_timeline())
	return time_max(time_min(effect.start_delay_, effect.end_time()), zero)
}

pub fn (effect &AnimationEffect) after_active_boundary_time() TimeValue {
	zero := TimeValue.zero_for_timeline(effect.associated_timeline())
	start_and_active := effect.start_delay_.add(effect.active_duration()) or { return zero }
	return time_max(time_min(start_and_active, effect.end_time()), zero)
}

pub fn (effect &AnimationEffect) is_in_the_before_phase() bool {
	local := effect.local_time() or { return false }
	boundary := effect.before_active_boundary_time()
	return local.value < boundary.value
		|| (effect.animation_direction() == .backwards && local == boundary)
}

pub fn (effect &AnimationEffect) is_in_the_after_phase() bool {
	local := effect.local_time() or { return false }
	boundary := effect.after_active_boundary_time()
	return local.value > boundary.value
		|| (effect.animation_direction() == .forwards && local == boundary)
}

pub fn (effect &AnimationEffect) is_in_the_active_phase() bool {
	return effect.local_time() != none && !effect.is_in_the_before_phase()
		&& !effect.is_in_the_after_phase()
}

pub fn (effect &AnimationEffect) is_in_the_idle_phase() bool {
	return effect.local_time() == none
}

pub fn (effect &AnimationEffect) phase() EffectPhase {
	local := effect.local_time() or { return .idle }
	before := effect.before_active_boundary_time()
	if local.value < before.value || (effect.animation_direction() == .backwards && local == before) {
		return .before
	}
	after := effect.after_active_boundary_time()
	if local.value > after.value || (effect.animation_direction() == .forwards && local == after) {
		return .after
	}
	return .active
}

pub fn (effect &AnimationEffect) overall_progress() ?f64 {
	active := effect.active_time() or { return none }
	mut progress := if effect.iteration_duration_.value == 0 {
		if effect.is_in_the_before_phase() { 0.0 } else { effect.iteration_count_ }
	} else {
		active.value / effect.iteration_duration_.value
	}
	progress += effect.iteration_start_
	return progress
}

pub fn (effect &AnimationEffect) simple_iteration_progress() ?f64 {
	overall := effect.overall_progress() or { return none }
	mut simple := if math.is_inf(overall, 0) {
		math.fmod(effect.iteration_start_, 1.0)
	} else {
		math.fmod(overall, 1.0)
	}
	if simple == 0 && effect.phase() in [.active, .after] {
		if active := effect.active_time() {
			if active == effect.active_duration() && effect.iteration_count_ != 0 { simple = 1.0 }
		}
	}
	return simple
}

pub fn (effect &AnimationEffect) current_iteration() ?f64 {
	_ := effect.active_time() or { return none }
	if effect.is_in_the_after_phase() && math.is_inf(effect.iteration_count_, 1) {
		return effect.iteration_count_
	}
	simple := effect.simple_iteration_progress() or { return none }
	overall := effect.overall_progress() or { return none }
	return if simple == 1.0 { math.floor(overall) - 1.0 } else { math.floor(overall) }
}

pub fn (effect &AnimationEffect) current_direction() AnimationDirection {
	if effect.playback_direction_ == .normal { return .forwards }
	if effect.playback_direction_ == .reverse { return .backwards }
	mut iteration := effect.current_iteration() or { return .forwards }
	if effect.playback_direction_ == .alternate_reverse { iteration += 1 }
	if math.is_inf(iteration, 0) || math.fmod(iteration, 2.0) == 0 { return .forwards }
	return .backwards
}

pub fn (effect &AnimationEffect) directed_progress() ?f64 {
	simple := effect.simple_iteration_progress() or { return none }
	return if effect.current_direction() == .forwards { simple } else { 1.0 - simple }
}

pub fn (effect &AnimationEffect) transformed_progress() ?f64 {
	directed := effect.directed_progress() or { return none }
	forwards := effect.current_direction() == .forwards
	before_flag := (effect.is_in_the_before_phase() && forwards)
		|| (effect.is_in_the_after_phase() && !forwards)
	return effect.timing_function_.evaluate_at(directed, before_flag)
}

pub fn compute_required_invalidation_for_animated_properties(old_properties map[css.PropertyID]&dom.StyleValue, new_properties map[css.PropertyID]&dom.StyleValue) css.RequiredInvalidationAfterStyleChange {
	mut all_properties := map[css.PropertyID]bool{}
	for property_id, _ in old_properties {
		all_properties[property_id] = true
	}
	for property_id, _ in new_properties {
		all_properties[property_id] = true
	}
	mut invalidation := css.RequiredInvalidationAfterStyleChange{}
	for property_id, _ in all_properties {
		mut old_value := ?&dom.StyleValue(none)
		mut new_value := ?&dom.StyleValue(none)
		if value := old_properties[property_id] {
			old_value = value
		}
		if value := new_properties[property_id] {
			new_value = value
		}
		if old_value == none && new_value == none {
			continue
		}
		property_invalidation := css.compute_property_invalidation(property_id, old_value,
			new_value)
		invalidation = css.required_invalidation_after_style_change_or(invalidation,
			property_invalidation)
	}
	return invalidation
}

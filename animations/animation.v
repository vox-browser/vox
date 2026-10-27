// Copyright (c) 2023-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Animations/Animation.{h,cpp}.
module animations

import css
import dom
import html
import math

__global animation_list_order_counter u64

pub enum AnimationPlayState {
	idle
	running
	paused
	finished
}

pub enum AnimationReplaceState {
	active
	removed
	persisted
}

pub enum AnimationClass {
	css_animation_with_owning_element
	css_transition
	css_animation_without_owning_element
	none_
}

pub enum ShouldInvalidate {
	yes
	no
}

@[heap]
pub struct Animation {
	dom.Animation
	dom.EventTarget
pub mut:
	id_                                      string
	global_animation_list_order_             u64
	effect_                                  ?&AnimationEffect
	timeline_                                ?&AnimationTimeline
	start_time_                              ?TimeValue
	auto_align_start_time_                   bool
	hold_time_                               ?TimeValue
	previous_current_time_                   ?TimeValue
	playback_rate_                           f64 = 1.0
	pending_playback_rate_                   ?f64
	replace_state_                           AnimationReplaceState = .active
	current_ready_promise_                   &dom.Promise = dom.Promise.resolved(dom.js_undefined())
	current_finished_promise_                &dom.Promise = dom.Promise.create()
	is_finished_                             bool
	pending_play_task_                       bool
	pending_pause_task_                      bool
	emitted_events_                          []&AnimationPlaybackEvent
	animation_class_                         AnimationClass = .none_
	class_composite_order_                   int
	owning_element_                          ?dom.AbstractElement
	saved_cancel_time_                       ?TimeValue
	last_css_animation_play_state_           ?css.AnimationPlayState
	effect_invalidated_                      bool
	environment_                             ?&html.EnvironmentSettingsObject
	css_cancellation_disassociation_pending_ bool
	needs_target_reassociation_              bool
	pending_finish_microtask_id_             ?u64
}

pub fn Animation.create(effect ?&AnimationEffect, timeline ?&AnimationTimeline) &Animation {
	return Animation.create_with_environment(none, effect, timeline)
}

pub fn Animation.create_with_environment(environment ?&html.EnvironmentSettingsObject, effect ?&AnimationEffect, timeline ?&AnimationTimeline) &Animation {
	order := animation_list_order_counter
	animation_list_order_counter++
	mut animation := &Animation{
		global_animation_list_order_: order
		environment_: environment
	}
	animation.Animation.concrete_handle_ = voidptr(animation)
	animation.current_ready_promise_ = create_resolved_animation_promise(animation)
	animation.set_effect(effect)
	animation.set_timeline(timeline)
	return animation
}

pub fn Animation.construct_impl(effect ?&AnimationEffect, timeline ?&AnimationTimeline) &Animation {
	return Animation.create(effect, timeline)
}

pub fn Animation.effect_offset() uint {
	return uint(__offsetof(Animation, effect_))
}

fn optional_element_identity_equal(left ?&dom.Element, right ?&dom.Element) bool {
	if left_element := left {
		right_element := right or { return false }
		return voidptr(left_element) == voidptr(right_element)
	}
	return right == none
}

fn animation_effect_target(effect ?&AnimationEffect) ?&dom.Element {
	value := effect or { return none }
	if !value.is_keyframe_effect_ {
		return none
	}
	return unsafe { &KeyframeEffect(value) }.target()
}

fn associate_animation_with_target(target &dom.Element, animation &Animation) {
	mut animatable := Animatable.new(target)
	animatable.associate_with_animation(animation)
}

fn disassociate_animation_from_target(target &dom.Element, animation &Animation) {
	if target.animations_animatable_handle_ == unsafe { nil } {
		return
	}
	mut animatable := unsafe { &Animatable(target.animations_animatable_handle_) }
	animatable.disassociate_with_animation(animation)
}

pub fn animation_wrapper_value(animation &Animation) dom.JSValue {
	return dom.js_object(voidptr(animation))
}

pub fn resolve_animation_promise(promise &dom.Promise, animation &Animation) {
	mut mutable_promise := unsafe { &dom.Promise(promise) }
	mutable_promise.resolve(animation_wrapper_value(animation))
}

pub fn create_resolved_animation_promise(animation &Animation) &dom.Promise {
	return dom.Promise.resolved(animation_wrapper_value(animation))
}

// The generated binding supplies the associated document's default timeline
// separately because the V object model does not retain a Realm on each call.
pub fn construct_animation(effect ?&AnimationEffect, timeline ?&AnimationTimeline, default_timeline ?&AnimationTimeline, argument_count int) &Animation {
	selected_timeline := if argument_count < 2 { default_timeline } else { timeline }
	return Animation.create(effect, selected_timeline)
}

pub fn (mut animation Animation) set_effect(new_effect ?&AnimationEffect) {
	old_effect := animation.effect_
	if old_effect == none && new_effect == none {
		return
	}
	if old := old_effect {
		if replacement := new_effect {
			if voidptr(old) == voidptr(replacement) {
				return
			}
		}
	}
	if replacement := new_effect {
		if previous_animation := replacement.associated_animation_ {
			if voidptr(previous_animation) != voidptr(animation) {
				mut mutable_previous_animation := unsafe { &Animation(previous_animation) }
				mutable_previous_animation.set_effect(none)
			}
		}
	}
	old_target := animation_effect_target(old_effect)
	new_target := animation_effect_target(new_effect)
	if !optional_element_identity_equal(old_target, new_target) {
		if target := old_target {
			disassociate_animation_from_target(target, animation)
		}
		if target := new_target {
			associate_animation_with_target(target, animation)
		}
	}
	if mut effect := new_effect {
		effect.set_associated_animation(animation)
	}
	if mut old := old_effect {
		old.set_associated_animation(none)
		if old.is_keyframe_effect_ {
			mut old_keyframe_effect := unsafe { &KeyframeEffect(old) }
			old_keyframe_effect.invalidate_effect()
		}
	}
	animation.effect_ = new_effect
	animation.update_finished_state(false)
	animation.invalidate_effect()
}

pub fn (mut animation Animation) set_timeline(new_timeline ?&AnimationTimeline) {
	previous_time := animation.current_time()
	if mut old := animation.timeline_ {
		old.disassociate_with_animation(animation)
	}
	animation.timeline_ = new_timeline
	if mut timeline := new_timeline {
		timeline.associate_with_animation(animation)
	}
	if mut effect := animation.effect_ {
		effect.normalize_specified_timing()
	}
	if previous_time != none {
		animation.hold_time_ = previous_time
		animation.start_time_ = none
	}
	animation.update_finished_state(true)
}

pub fn (animation &Animation) id() string {
	return animation.id_
}

pub fn (mut animation Animation) set_id(value string) {
	animation.id_ = value
}

pub fn (animation &Animation) playback_rate() f64 {
	return animation.playback_rate_
}

pub fn (animation &Animation) start_time() ?TimeValue {
	return animation.start_time_
}

pub fn (animation &Animation) pending() bool {
	return animation.pending_play_task_ || animation.pending_pause_task_
}

pub fn (animation &Animation) ready() &dom.Promise {
	animation.update_style_if_needed()
	return animation.current_ready_promise_
}

pub fn (animation &Animation) finished() &dom.Promise {
	return animation.current_finished_promise_
}

pub fn (animation &Animation) replace_state() AnimationReplaceState {
	return animation.replace_state_
}

pub fn (animation &Animation) emitted_events() []&AnimationPlaybackEvent {
	return animation.emitted_events_.clone()
}

pub fn (animation &Animation) validate_css_numberish_time(value CSSNumberish) !TimeValue {
	if timeline := animation.timeline_ {
		if timeline.is_progress_based() {
			if value is PercentageValue {
				return TimeValue.percentage(value.value)
			}
			return error('CSSNumberish must be a percentage for progress-based animations')
		}
	}
	return match value {
		f64 { TimeValue.milliseconds(value) }
		PercentageValue { error('CSSNumericValue must be a time for non-progress based animations') }
	}
}

// https://drafts.csswg.org/web-animations-2/#validating-a-css-numberish-time
pub fn (animation &Animation) validate_a_css_numberish_time(value ?CSSNumberish) !NullableTimeValue {
	if raw := value {
		return NullableTimeValue{
			value: animation.validate_css_numberish_time(raw)!
		}
	}
	if timeline := animation.timeline_ {
		if timeline.is_progress_based() {
			return error('CSSNumberish must be a percentage for progress-based animations')
		}
	}
	return NullableTimeValue{}
}

pub fn (animation &Animation) timeline_for_bindings() ?&AnimationTimeline {
	animation.update_style_if_needed()
	return animation.timeline_
}

pub fn (mut animation Animation) set_timeline_for_bindings(timeline ?&AnimationTimeline) {
	animation.set_timeline(timeline)
}

pub fn (animation &Animation) start_time_for_bindings() NullableCSSNumberish {
	animation.update_style_if_needed()
	return NullableCSSNumberish.from_optional_css_numberish_time(animation.start_time())
}

pub fn (mut animation Animation) set_start_time_for_bindings(value ?CSSNumberish) ! {
	validated := animation.validate_a_css_numberish_time(value)!
	animation.set_start_time(validated.value)!
}

pub fn (animation &Animation) current_time_for_bindings() NullableCSSNumberish {
	animation.update_style_if_needed()
	return NullableCSSNumberish.from_optional_css_numberish_time(animation.current_time_for_observation())
}

pub fn (mut animation Animation) set_current_time_for_bindings(value ?CSSNumberish) ! {
	validated := animation.validate_a_css_numberish_time(value)!
	animation.set_current_time(validated.value)!
}

pub fn (mut animation Animation) set_start_time(value ?TimeValue) ! {
	if time := value {
		animation.validate_time_type(time)!
	}
	animation.auto_align_start_time_ = false
	timeline_time := animation.active_timeline_time()
	if timeline_time == none && value != none {
		animation.hold_time_ = none
	}
	previous_current_time := animation.current_time()
	animation.apply_pending_playback_rate()
	animation.start_time_ = value
	if value != none {
		if animation.playback_rate_ != 0 { animation.hold_time_ = none }
	} else {
		animation.hold_time_ = previous_current_time
	}
	if animation.pending() {
		animation.pending_play_task_ = false
		animation.pending_pause_task_ = false
		resolve_animation_promise(animation.current_ready_promise_, animation)
	}
	animation.update_finished_state(true)
}

pub fn (mut animation Animation) set_start_time_numberish(value CSSNumberish) ! {
	validated := animation.validate_css_numberish_time(value)!
	animation.set_start_time(validated)!
}

fn (animation &Animation) validate_time_type(time TimeValue) ! {
	progress := if timeline := animation.timeline_ { timeline.is_progress_based() } else { false }
	if progress != (time.type_ == .percentage) {
		message := if progress {
			'CSSNumberish must be a percentage for progress-based animations'
		} else {
			'CSSNumericValue must be a time for non-progress based animations'
		}
		return error(message)
	}
}

fn (animation &Animation) active_timeline_time() ?TimeValue {
	timeline := animation.timeline_ or { return none }
	if timeline.is_inactive() { return none }
	return timeline.current_time()
}

pub fn (mut animation Animation) calculate_auto_aligned_start_time() {
	if !animation.auto_align_start_time_ { return }
	timeline := animation.timeline_ or { return }
	if !timeline.is_progress_based() || timeline.is_inactive() || animation.play_state() == .idle {
		return
	}
	if animation.play_state() == .paused && animation.hold_time_ != none { return }
	animation.start_time_ = if animation.effective_playback_rate() >= 0 {
		TimeValue.percentage(0)
	} else {
		TimeValue.percentage(100)
	}
	animation.hold_time_ = none
}

pub fn (animation &Animation) current_time() ?TimeValue {
	timeline_time := if timeline := animation.timeline_ { timeline.current_time() } else { none }
	return animation.current_time_at(timeline_time)
}

pub fn (animation &Animation) current_time_for_observation() ?TimeValue {
	timeline_time := if timeline := animation.timeline_ {
		timeline.current_time_for_observation()
	} else {
		none
	}
	return animation.current_time_at(timeline_time)
}

pub fn (animation &Animation) current_time_at(timeline_time ?TimeValue) ?TimeValue {
	if hold := animation.hold_time_ {
		return hold
	}
	if animation.timeline_ == none {
		return none
	}
	start := animation.start_time_ or { return none }
	resolved_timeline_time := timeline_time or { return none }
	difference := resolved_timeline_time.subtract(start) or { return none }
	return difference.multiply(animation.playback_rate_)
}

pub fn (mut animation Animation) set_current_time(value ?TimeValue) ! {
	if time := value { animation.validate_time_type(time)! }
	animation.silently_set_current_time(value)!
	if animation.pending_pause_task_ {
		animation.hold_time_ = value
		animation.apply_pending_playback_rate()
		animation.start_time_ = none
		animation.pending_pause_task_ = false
		resolve_animation_promise(animation.current_ready_promise_, animation)
	}
	animation.update_finished_state(true)
}

pub fn (mut animation Animation) set_current_time_numberish(value CSSNumberish) ! {
	validated := animation.validate_css_numberish_time(value)!
	animation.set_current_time(validated)!
}

fn (mut animation Animation) silently_set_current_time(value ?TimeValue) ! {
	if value == none {
		if animation.current_time() != none {
			return error("Cannot change an animation's current time from a resolved value to an unresolved value")
		}
		return
	}
	animation.auto_align_start_time_ = false
	timeline := animation.timeline_
	if animation.hold_time_ != none || animation.start_time_ == none || timeline == none
		|| animation.active_timeline_time() == none || animation.playback_rate_ == 0 {
		animation.hold_time_ = value
	} else if timeline_time := animation.active_timeline_time() {
		animation.start_time_ = timeline_time.subtract(value.divide(animation.playback_rate_))!
	}
	if timeline == none || animation.active_timeline_time() == none {
		animation.start_time_ = none
	}
	animation.previous_current_time_ = none
}

pub fn (mut animation Animation) set_playback_rate(new_rate f64) ! {
	animation.pending_playback_rate_ = none
	previous_time := animation.current_time()
	previous_rate := animation.playback_rate_
	changes_direction := if previous_rate < 0 { new_rate >= 0 } else { new_rate < 0 }
	animation.playback_rate_ = new_rate
	if timeline := animation.timeline_ {
		if timeline.is_monotonically_increasing() && previous_time != none {
			animation.set_current_time(previous_time)!
		} else if !timeline.is_monotonically_increasing() && animation.start_time_ != none
			&& !math.is_inf(animation.associated_effect_end().value, 0) && changes_direction {
			start := animation.start_time_ or { return }
			animation.start_time_ = animation.associated_effect_end().subtract(start)!
		}
	}
}

pub fn (animation &Animation) play_state() AnimationPlayState {
	return animation.play_state_at(animation.current_time())
}

pub fn (animation &Animation) play_state_at(current ?TimeValue) AnimationPlayState {
	if current == none && animation.start_time_ == none && !animation.pending() {
		return .idle
	}
	if animation.pending_pause_task_
		|| (animation.start_time_ == none && !animation.pending_play_task_) {
		return .paused
	}
	if time := current {
		rate := animation.effective_playback_rate()
		if (rate > 0 && time.value >= animation.associated_effect_end().value)
			|| (rate < 0 && time.value <= 0) {
			return .finished
		}
	}
	return .running
}

pub fn (animation &Animation) play_state_for_bindings() AnimationPlayState {
	if owner := animation.owning_element_ {
		mut document := unsafe { &dom.Document(owner.document()) }
		document.update_style()
	}
	return animation.play_state_at(animation.current_time_for_observation())
}

pub fn (animation &Animation) pending_for_bindings() bool {
	animation.update_style_if_needed()
	return animation.pending()
}

pub fn (animation &Animation) has_pending_play_task() bool {
	return animation.pending_play_task_
}

pub fn (animation &Animation) ready_for_bindings() &dom.Promise {
	animation.update_style_if_needed()
	return animation.current_ready_promise_
}

pub fn (mut animation Animation) finished_for_bindings() &dom.Promise {
	animation.update_style_if_needed()
	if mut timeline := animation.timeline_ {
		observed_timeline_time := timeline.current_time_for_observation()
		observed_current_time := animation.current_time_at(observed_timeline_time)
		if !animation.is_finished_ && animation.play_state_at(animation.current_time()) != .finished
			&& animation.play_state_at(observed_current_time) == .finished {
			previous_override := timeline.current_time_override_for_style_sampling_
			had_previous_override := timeline.has_current_time_override_for_style_sampling_
			timeline.set_current_time_override_for_style_sampling(observed_timeline_time)
			animation.update_finished_state_with_notification(false, true, .no, observed_current_time)
			timeline.current_time_override_for_style_sampling_ = previous_override
			timeline.has_current_time_override_for_style_sampling_ = had_previous_override
		}
	}
	return animation.current_finished_promise_
}

pub fn (animation &Animation) update_style_if_needed() {
	owner := animation.owning_element_ or { return }
	element := owner.element()
	if element.document() == unsafe { nil } {
		return
	}
	mut document := unsafe { &dom.Document(element.document()) }
	document.update_style_if_needed_for_element(element)
}

pub fn (animation &Animation) is_finished() bool {
	return animation.is_finished_
}

pub fn (animation &Animation) is_idle() bool {
	return animation.play_state() == .idle
}

pub fn (animation &Animation) onfinish() ?&dom.CallbackType {
	return animation.EventTarget.event_handler_attribute('finish')
}

pub fn (animation &Animation) set_onfinish(value ?&dom.CallbackType) {
	animation.EventTarget.set_event_handler_attribute('finish', value)
}

pub fn (animation &Animation) oncancel() ?&dom.CallbackType {
	return animation.EventTarget.event_handler_attribute('cancel')
}

pub fn (animation &Animation) set_oncancel(value ?&dom.CallbackType) {
	animation.EventTarget.set_event_handler_attribute('cancel', value)
}

pub fn (animation &Animation) onremove() ?&dom.CallbackType {
	return animation.EventTarget.event_handler_attribute('remove')
}

pub fn (animation &Animation) set_onremove(value ?&dom.CallbackType) {
	animation.EventTarget.set_event_handler_attribute('remove', value)
}

pub fn (animation &Animation) is_relevant() bool {
	effect := animation.effect_ or { return false }
	return (effect.is_current() || effect.is_in_effect()) && animation.replace_state_ != .removed
}

pub fn (animation &Animation) is_replaceable() bool {
	if (animation.is_css_animation() || animation.is_css_transition())
		&& animation.owning_element_ != none {
		return false
	}
	if animation.play_state() != .finished || animation.replace_state_ == .removed { return false }
	timeline := animation.timeline_ or { return false }
	if !timeline.is_monotonically_increasing() { return false }
	effect := animation.effect_ or { return false }
	return effect.is_in_effect() && effect.has_target_
}

pub fn (mut animation Animation) set_replace_state(value AnimationReplaceState) {
	if animation.replace_state_ == value { return }
	if value == .removed {
		if target := animation_effect_target(animation.effect_) {
			disassociate_animation_from_target(target, animation)
		}
		if mut timeline := animation.timeline_ { timeline.disassociate_with_animation(animation) }
	} else if value == .persisted && animation.replace_state_ == .removed {
		if target := animation_effect_target(animation.effect_) {
			associate_animation_with_target(target, animation)
		}
		if mut timeline := animation.timeline_ {
			timeline.associate_with_animation(animation)
		}
	}
	animation.replace_state_ = value
}

pub fn (mut animation Animation) cancel() {
	animation.cancel_with_invalidation(.yes)
}

// Animation::cancel(ShouldInvalidate). CSS cascade cancellation already updates
// the effect stack and can suppress a redundant style reaction.
pub fn (mut animation Animation) cancel_with_invalidation(should_invalidate ShouldInvalidate) {
	if animation.play_state() != .idle {
		animation.reset_pending_tasks()
		animation.current_finished_promise_.reject(dom.js_string('AbortError: Animation was cancelled'))
		animation.current_finished_promise_.mark_handled()
		animation.current_finished_promise_ = dom.Promise.create()
		animation.is_finished_ = false
		animation.emit_playback_event('cancel', none)
	}
	animation.hold_time_ = none
	animation.start_time_ = none
	if effect := animation.effect_ {
		animation.saved_cancel_time_ = effect.active_time_using_fill(.both)
	}
	if should_invalidate == .yes {
		animation.invalidate_effect()
	}
}

pub fn (mut animation Animation) finish() ! {
	if animation.effective_playback_rate() == 0 {
		return error('Animation with a playback rate of 0 cannot be finished')
	}
	end := animation.associated_effect_end()
	if animation.effective_playback_rate() > 0 && math.is_inf(end.value, 1) {
		return error('Animation with no end cannot be finished')
	}
	limit := if animation.effective_playback_rate() > 0 {
		end
	} else {
		TimeValue.zero_for_timeline(animation.timeline_)
	}
	animation.silently_set_current_time(limit)!
	animation.apply_pending_playback_rate()
	if timeline_time := animation.active_timeline_time() {
		animation.start_time_ = timeline_time.subtract(limit.divide(animation.playback_rate_))!
	}
	animation.pending_play_task_ = false
	animation.pending_pause_task_ = false
	resolve_animation_promise(animation.current_ready_promise_, animation)
	animation.update_finished_state_with_notification(true, true, .yes, none)
}

pub fn (mut animation Animation) play() ! {
	animation.play_an_animation(true)!
}

pub fn (mut animation Animation) play_an_animation(auto_rewind bool) ! {
	animation.css_cancellation_disassociation_pending_ = false
	if animation.needs_target_reassociation_ {
		if target := animation_effect_target(animation.effect_) {
			associate_animation_with_target(target, animation)
		}
		animation.needs_target_reassociation_ = false
	}
	aborted_pause := animation.pending_pause_task_
	mut has_pending_ready := false
	has_finite_timeline := if timeline := animation.timeline_ {
		!timeline.is_monotonically_increasing()
	} else {
		false
	}
	previous := animation.current_time()
	previous_unresolved := previous == none
	previous_value := previous or { animation.associated_effect_end() }
	enable_seek := auto_rewind && !has_finite_timeline
	rate := animation.effective_playback_rate()
	end := animation.associated_effect_end()
	if rate > 0 && enable_seek
		&& (previous_unresolved || previous_value.value < 0 || previous_value.value >= end.value) {
		animation.hold_time_ = TimeValue.zero_for_timeline(animation.timeline_)
	} else if rate < 0 && enable_seek
		&& (previous_unresolved || previous_value.value <= 0 || previous_value.value > end.value) {
		if math.is_inf(end.value, 1) {
			return error('Cannot rewind an animation with an infinite effect end')
		}
		animation.hold_time_ = end
	} else if rate == 0 && previous == none {
		animation.hold_time_ = TimeValue.zero_for_timeline(animation.timeline_)
	}
	if has_finite_timeline && previous == none { animation.auto_align_start_time_ = true }
	if animation.hold_time_ != none { animation.start_time_ = none }
	if animation.pending() {
		animation.pending_play_task_ = false
		animation.pending_pause_task_ = false
		has_pending_ready = true
	}
	pending_auto_start := animation.auto_align_start_time_ && animation.start_time_ == none
	if animation.hold_time_ == none && !aborted_pause && animation.pending_playback_rate_ == none
		&& !pending_auto_start {
		return
	}
	if !has_pending_ready { animation.current_ready_promise_ = dom.Promise.create() }
	animation.pending_play_task_ = true
	animation.update_finished_state(false)
}

pub fn (mut animation Animation) pause() ! {
	if animation.pending_pause_task_ || animation.play_state() == .paused { return }
	has_finite_timeline := if timeline := animation.timeline_ {
		!timeline.is_monotonically_increasing()
	} else {
		false
	}
	mut seek := ?TimeValue(none)
	if animation.current_time() == none {
		if animation.playback_rate_ >= 0 {
			seek = TimeValue.zero_for_timeline(animation.timeline_)
		} else {
			end := animation.associated_effect_end()
			if math.is_inf(end.value, 1) {
				return error('Cannot pause an animation with an infinite effect end')
			}
			seek = end
		}
	}
	if value := seek {
		if has_finite_timeline {
			animation.start_time_ = value
		} else {
			animation.hold_time_ = value
		}
	}
	mut has_pending_ready := false
	if animation.pending_play_task_ {
		animation.pending_play_task_ = false
		has_pending_ready = true
	}
	if !has_pending_ready { animation.current_ready_promise_ = dom.Promise.create() }
	animation.pending_pause_task_ = true
	animation.update_finished_state(false)
}

pub fn (mut animation Animation) update_playback_rate(new_rate f64) ! {
	previous_state := animation.play_state()
	animation.pending_playback_rate_ = new_rate
	if animation.pending() { return }
	if previous_state in [.idle, .paused] || animation.current_time() == none {
		animation.apply_pending_playback_rate()
	} else if previous_state == .finished {
		timeline_time := animation.active_timeline_time() or { return }
		pending_rate := animation.pending_playback_rate_ or { return }
		unconstrained := animation.current_time() or { return }
		animation.start_time_ = if pending_rate == 0 {
			timeline_time
		} else {
			timeline_time.subtract(unconstrained.divide(pending_rate))!
		}
		animation.apply_pending_playback_rate()
		animation.update_finished_state(false)
	} else {
		animation.play_an_animation(false)!
	}
}

pub fn (mut animation Animation) reverse() ! {
	timeline := animation.timeline_ or {
		return error('Cannot reverse an animation with an inactive timeline')
	}

	if timeline.is_inactive() {
		return error('Cannot reverse an animation with an inactive timeline')
	}
	original := animation.pending_playback_rate_
	animation.pending_playback_rate_ = -animation.effective_playback_rate()
	animation.play_an_animation(true) or {
		animation.pending_playback_rate_ = original
		return err
	}
}

pub fn (mut animation Animation) persist() {
	animation.set_replace_state(.persisted)
}

pub fn (animation &Animation) convert_animation_time_to_timeline_time(value ?TimeValue) ?TimeValue {
	return animation.convert_an_animation_time_to_timeline_time(value)
}

pub fn (animation &Animation) convert_an_animation_time_to_timeline_time(value ?TimeValue) ?TimeValue {
	animation_time := value or { return none }
	if math.is_inf(animation_time.value, 0) { return none }
	if animation.playback_rate_ == 0 { return none }
	start := animation.start_time_ or { return none }
	return start.add(animation_time.divide(animation.playback_rate_)) or { none }
}

pub fn (animation &Animation) convert_timeline_time_to_origin_relative_time(value ?TimeValue) ?f64 {
	return animation.convert_a_timeline_time_to_an_origin_relative_time(value)
}

pub fn (animation &Animation) convert_a_timeline_time_to_an_origin_relative_time(value ?TimeValue) ?f64 {
	timeline_time := animation.convert_an_animation_time_to_timeline_time(value)
	timeline := animation.timeline_ or { return none }
	if timeline.is_inactive()
		|| !timeline.can_convert_a_timeline_time_to_an_origin_relative_time() {
		return none
	}
	return timeline.convert_a_timeline_time_to_an_origin_relative_time(timeline_time)
}

pub fn (animation &Animation) document_for_timing() ?&dom.Document {
	timeline := animation.timeline_ or { return none }
	return timeline.associated_document()
}

pub fn (mut animation Animation) update() {
	animation.calculate_auto_aligned_start_time()
	monotonic := if timeline := animation.timeline_ { timeline.is_monotonically_increasing() } else { false }
	if !animation.is_finished_ || !monotonic {
		was_finished := animation.is_finished_
		animation.update_finished_state_with_notification(false, true, .no, none)
		if animation.play_state() == .running {
			if raw_effect := animation.effect_ {
				if raw_effect.is_keyframe_effect_ {
					effect := unsafe { &KeyframeEffect(raw_effect) }
					constant_before_start := !animation.pending() && effect.is_in_the_before_phase()
						&& monotonic && animation.playback_rate() > 0
					if !effect.can_skip_per_frame_style_update() && !animation.pending() && !constant_before_start {
						animation.invalidate_effect()
					}
				}
			}
		} else if animation.is_finished_ != was_finished {
			animation.invalidate_effect()
		}
	}
	if animation.pending_play_task_ && animation.is_ready() {
		animation.pending_play_task_ = false
		animation.run_pending_play_task()
	}
	if animation.pending_pause_task_ && animation.is_ready() {
		animation.pending_pause_task_ = false
		animation.run_pending_pause_task()
	}
}

pub fn (mut animation Animation) effect_timing_changed() {
	animation.update_finished_state_with_notification(false, true, .yes, none)
}

pub fn (animation &Animation) associated_effect_end() TimeValue {
	if effect := animation.effect_ { return effect.end_time() }
	return TimeValue.zero_for_timeline(animation.timeline_)
}

fn (animation &Animation) effective_playback_rate() f64 {
	return animation.pending_playback_rate_ or { animation.playback_rate_ }
}

fn (mut animation Animation) apply_pending_playback_rate() {
	if value := animation.pending_playback_rate_ { animation.playback_rate_ = value }
	animation.pending_playback_rate_ = none
}

pub fn (mut animation Animation) apply_any_pending_playback_rate() {
	animation.apply_pending_playback_rate()
}

fn (animation &Animation) is_ready() bool {
	timeline := animation.timeline_ or { return false }
	return !timeline.is_inactive()
		&& (animation.hold_time_ != none || animation.start_time_ != none)
}

pub fn (animation &Animation) is_ready_to_run_pending_pause_task() bool {
	return animation.is_ready()
}

fn (mut animation Animation) run_pending_play_task() {
	ready_time := animation.active_timeline_time() or { return }
	if hold := animation.hold_time_ {
		animation.apply_pending_playback_rate()
		animation.start_time_ = if animation.playback_rate_ != 0 {
			ready_time.subtract(hold.divide(animation.playback_rate_)) or { ready_time }
		} else {
			ready_time
		}
		if animation.playback_rate_ != 0 { animation.hold_time_ = none }
	} else if start := animation.start_time_ {
		if animation.pending_playback_rate_ != none {
			current_to_match :=
				(ready_time.subtract(start) or { return }).multiply(animation.playback_rate_)
			animation.apply_pending_playback_rate()
			if animation.playback_rate_ == 0 { animation.hold_time_ = current_to_match }
			animation.start_time_ = if animation.playback_rate_ != 0 {
				ready_time.subtract(current_to_match.divide(animation.playback_rate_)) or {
					ready_time
				}
			} else {
				ready_time
			}
		}
	}
	resolve_animation_promise(animation.current_ready_promise_, animation)
	animation.update_finished_state(false)
}

fn (mut animation Animation) run_pending_pause_task() {
	ready_time := animation.active_timeline_time() or { return }
	if start := animation.start_time_ {
		if animation.hold_time_ == none {
			animation.hold_time_ =
				(ready_time.subtract(start) or { return }).multiply(animation.playback_rate_)
		}
	}
	animation.apply_pending_playback_rate()
	animation.start_time_ = none
	resolve_animation_promise(animation.current_ready_promise_, animation)
	animation.update_finished_state(false)
}

fn (mut animation Animation) reset_pending_tasks() {
	if !animation.pending() { return }
	animation.pending_play_task_ = false
	animation.pending_pause_task_ = false
	animation.apply_pending_playback_rate()
	animation.current_ready_promise_.reject(dom.js_string('AbortError: Animation was cancelled'))
	animation.current_ready_promise_.mark_handled()
	animation.current_ready_promise_ = create_resolved_animation_promise(animation)
}

pub fn (mut animation Animation) reset_an_animations_pending_tasks() {
	animation.reset_pending_tasks()
}

pub fn (animation &Animation) current_ready_promise() &dom.Promise {
	return animation.current_ready_promise_
}

pub fn (animation &Animation) current_finished_promise() &dom.Promise {
	return animation.current_finished_promise_
}

pub fn (animation &Animation) relevant_settings_object() ?&html.EnvironmentSettingsObject {
	if environment := animation.environment_ {
		return environment
	}
	document := animation.document_for_timing() or {
		owner := animation.owning_element_ or { return none }
		owner.element().document()
	}
	if document == unsafe { nil } {
		return none
	}
	settings := document.relevant_settings_object()
	if settings == unsafe { nil } {
		return none
	}
	return unsafe { &html.EnvironmentSettingsObject(settings) }
}

pub fn (animation &Animation) relevant_global_object() ?&dom.EventTarget {
	settings := animation.relevant_settings_object() or { return none }
	return settings.global_object()
}

pub fn (animation &Animation) relevant_global_impl() ?&dom.EventTarget {
	return animation.relevant_global_object()
}

pub fn (mut animation Animation) set_provisional_effect(effect &AnimationEffect) {
	if animation.effect_ != none || effect.associated_animation_ != none {
		panic('A provisional effect must be unassociated')
	}
	mut mutable_effect := unsafe { &AnimationEffect(effect) }
	mutable_effect.set_associated_animation(animation)
	animation.effect_ = effect
}

pub fn (mut animation Animation) discard_provisional_effect() {
	mut effect := animation.effect_ or { panic('Missing provisional effect') }
	associated_animation := effect.associated_animation_ or {
		panic('Provisional effect is not associated')
	}
	if voidptr(associated_animation) != voidptr(animation) {
		panic('Provisional effect belongs to another animation')
	}
	effect.set_associated_animation(none)
	animation.effect_ = none
}

pub fn (mut animation Animation) invalidate_effect() {
	effect := animation.effect_ or { return }
	if effect.is_keyframe_effect_ {
		mut keyframe_effect := unsafe { &KeyframeEffect(effect) }
		keyframe_effect.invalidate_effect()
	}
	animation.effect_invalidated_ = true
	if owner := animation.owning_element_ {
		mut document := unsafe { &dom.Document(owner.document()) }
		document.set_needs_animated_style_update()
	}
}

pub fn (animation &Animation) is_css_animation() bool {
	return animation.animation_class_ in [.css_animation_with_owning_element,
		.css_animation_without_owning_element]
}

pub fn (animation &Animation) is_css_transition() bool {
	return animation.animation_class_ == .css_transition
}

pub fn (animation &Animation) owning_element() ?dom.AbstractElement {
	return animation.owning_element_
}

pub fn (mut animation Animation) set_owning_element(value ?dom.AbstractElement) {
	animation.owning_element_ = value
}

pub fn (mut animation Animation) schedule_disassociation_from_target_after_css_cancellation() {
	animation.css_cancellation_disassociation_pending_ = true
}

pub fn (animation &Animation) css_cancellation_disassociation_pending() bool {
	return animation.css_cancellation_disassociation_pending_
}

pub fn (mut animation Animation) disassociate_from_target_after_css_cancellation() {
	animation.css_cancellation_disassociation_pending_ = false
	target := animation_effect_target(animation.effect_) or { return }
	disassociate_animation_from_target(target, animation)
	animation.needs_target_reassociation_ = true
}

pub fn (animation &Animation) animation_class() AnimationClass {
	return animation.animation_class_
}

pub fn (animation &Animation) class_specific_composite_order(_ &Animation) int {
	return animation.class_composite_order_
}

pub fn (animation &Animation) global_animation_list_order() u64 {
	return animation.global_animation_list_order_
}

pub fn (mut animation Animation) release_saved_cancel_time() ?TimeValue {
	value := animation.saved_cancel_time_
	animation.saved_cancel_time_ = none
	return value
}

pub fn (animation &Animation) last_css_animation_play_state() ?css.AnimationPlayState {
	return animation.last_css_animation_play_state_
}

pub fn (mut animation Animation) set_last_css_animation_play_state(value css.AnimationPlayState) {
	animation.last_css_animation_play_state_ = value
}

fn (mut animation Animation) update_finished_state(did_seek bool) {
	animation.update_finished_state_with_notification(did_seek, false, .yes, none)
}

// Animation::update_finished_state. The current C++ implementation enqueues
// DOMManipulation Task objects for the notification despite its specification
// comments referring to microtasks; retain that observable queue ordering.
fn (mut animation Animation) update_finished_state_with_notification(did_seek bool, synchronously_notify bool, should_invalidate ShouldInvalidate, observed_current_time ?TimeValue) {
	mut unconstrained := observed_current_time
	if unconstrained == none && !did_seek {
		hold := animation.hold_time_
		animation.hold_time_ = none
		unconstrained = animation.current_time()
		animation.hold_time_ = hold
	} else if unconstrained == none {
		unconstrained = animation.current_time()
	}
	if current := unconstrained {
		if animation.start_time_ != none && !animation.pending() {
			end := animation.associated_effect_end()
			if animation.playback_rate_ > 0 && current.value >= end.value {
				animation.hold_time_ = if did_seek {
					current
				} else if previous := animation.previous_current_time_ {
					time_max(previous, end)
				} else {
					end
				}
			} else if animation.playback_rate_ < 0 && current.value <= 0 {
				zero := TimeValue.zero_for_timeline(animation.timeline_)
				animation.hold_time_ = if did_seek {
					current
				} else if previous := animation.previous_current_time_ {
					time_min(previous, zero)
				} else {
					zero
				}
			} else if animation.playback_rate_ != 0 {
				if timeline_time := animation.active_timeline_time() {
					if did_seek {
						if hold := animation.hold_time_ {
							animation.start_time_ = timeline_time.subtract(hold.divide(animation.playback_rate_)) or {
								animation.start_time_
							}
						}
					}
					animation.hold_time_ = none
				}
			}
		}
	}
	animation.previous_current_time_ = animation.current_time()
	finished_now := animation.play_state() == .finished
	if finished_now && !animation.is_finished_ {
		if synchronously_notify {
			if id := animation.pending_finish_microtask_id_ {
				animation.pending_finish_microtask_id_ = none
				mut event_loop := html.main_thread_event_loop()
				mut queue := event_loop.task_queue()
				queue.remove_tasks_matching(fn [id] (task &html.Task) bool {
					return task.id() == id
				})
			}
			animation.run_finish_notification_steps()
		} else if animation.pending_finish_microtask_id_ == none {
			animation.pending_finish_microtask_id_ = animation.queue_dom_manipulation_task(fn [mut animation] () {
				animation.run_finish_notification_steps()
			})
		}
	}
	if !finished_now && animation.is_finished_ {
		animation.current_finished_promise_ = dom.Promise.create()
		animation.is_finished_ = false
	}
	if should_invalidate == .yes {
		animation.invalidate_effect()
	}
}

fn (mut animation Animation) run_finish_notification_steps() {
	if animation.play_state() != .finished {
		return
	}
	resolve_animation_promise(animation.current_finished_promise_, animation)
	animation.is_finished_ = true
	event := animation.create_playback_event('finish', animation.current_time())
	if document := animation.document_for_timing() {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.append_pending_animation_event(dom.PendingAnimationEvent{
			event: unsafe { &dom.Event(event) }
			animation: &animation.Animation
			target: &animation.EventTarget
			scheduled_event_time: animation.convert_a_timeline_time_to_an_origin_relative_time(animation.associated_effect_end())
		})
	} else {
		animation.pending_finish_microtask_id_ = animation.queue_dom_manipulation_task(fn [mut animation, event] () {
			animation.EventTarget.dispatch_event(unsafe { &dom.Event(event) })
		})
	}
}

fn (animation &Animation) queue_dom_manipulation_task(steps fn ()) u64 {
	settings := animation.relevant_settings_object()
	document := if environment := settings {
		environment.responsible_document()
	} else {
		animation.document_for_timing()
	}
	return html.queue_a_task(.dom_manipulation, html.main_thread_event_loop(), document, steps)
}

fn (mut animation Animation) create_playback_event(name string, current ?TimeValue) &AnimationPlaybackEvent {
	event := AnimationPlaybackEvent.create(name, AnimationPlaybackEventInit{
		current_time: optional_css_numberish(current)
		timeline_time: optional_css_numberish(animation.active_timeline_time())
	})
	animation.emitted_events_ << event
	return event
}

fn (mut animation Animation) emit_playback_event(name string, current ?TimeValue) {
	timeline_time := animation.active_timeline_time()
	event := animation.create_playback_event(name, current)
	if document := animation.document_for_timing() {
		scheduled_time := if timeline := animation.timeline_ {
			if !timeline.is_inactive() && timeline.can_convert_a_timeline_time_to_an_origin_relative_time() {
				timeline.convert_a_timeline_time_to_an_origin_relative_time(timeline_time)
			} else { ?f64(none) }
		} else {
			?f64(none)
		}
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.append_pending_animation_event(dom.PendingAnimationEvent{
			event:                unsafe { &dom.Event(event) }
			animation:            &animation.Animation
			target:               &animation.EventTarget
			scheduled_event_time: scheduled_time
		})
		return
	}
	animation.queue_dom_manipulation_task(fn [mut animation, event] () {
		animation.EventTarget.dispatch_event(unsafe { &dom.Event(event) })
	})
}

// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of AudioParamTimeline.{h,cpp}. The V audio graph is currently
// single-threaded, so the event list does not need the C++ control/render
// thread mutex. Event ordering and sampling semantics are otherwise shared.
module webaudio

import math

pub enum AudioParamTimelineInsertResult {
	success
	event_contained_in_value_curve
	value_curve_overlaps_event
}

enum AudioParamAutomationEventKind {
	set_value
	linear_ramp
	exponential_ramp
	set_target
	set_value_curve
	hold
}

struct AudioParamRampStart {
	set_target_event_id u64
	time                f64
	value               f32
}

struct AudioParamAutomationEvent {
mut:
	time          f64
	kind          AudioParamAutomationEventKind
	value         f32
	time_constant f32
	values        []f32
	duration      f64
	ramp_start    ?AudioParamRampStart
	id            u64
}

// Upstream retains the most recently selected interval in this structure. The
// V renderer is single-threaded and computes it by value, avoiding mutable
// state on the render-thread view while preserving the same interval rules.
struct ParameterizationCache {
	event_index    ?int
	minimum_time   ?f64
	maximum_time   ?f64
	starting_value f32
}

fn (cache ParameterizationCache) contains(time f64) bool {
	if minimum_time := cache.minimum_time {
		if time < minimum_time {
			return false
		}
	}
	if maximum_time := cache.maximum_time {
		if time >= maximum_time {
			return false
		}
	}
	return true
}

@[heap]
pub struct AudioParamTimeline {
	default_value_ f32
mut:
	current_value_     f32
	fallback_value_    f32
	automation_events_ []AudioParamAutomationEvent
	next_event_id_     u64
}

pub fn AudioParamTimeline.create(default_value f32) &AudioParamTimeline {
	return &AudioParamTimeline{
		default_value_: default_value
		current_value_: default_value
		fallback_value_: default_value
	}
}

pub fn (timeline &AudioParamTimeline) default_value() f32 {
	return timeline.default_value_
}

pub fn (timeline &AudioParamTimeline) current_value() f32 {
	return timeline.current_value_
}

pub fn (mut timeline AudioParamTimeline) set_current_value(value f32) {
	timeline.current_value_ = value
	timeline.fallback_value_ = value
}

pub fn (timeline &AudioParamTimeline) has_events() bool {
	return timeline.automation_events_.len > 0
}

// Return the first event whose time is strictly greater than time. Events at
// the same instant retain insertion order and a new event is inserted after
// them, matching the upstream lower-bound comparator.
fn (timeline &AudioParamTimeline) first_event_index_after(time f64) int {
	for index, event in timeline.automation_events_ {
		if event.time > time {
			return index
		}
	}
	return timeline.automation_events_.len
}

fn (timeline &AudioParamTimeline) first_event_index_at_or_after(time f64) int {
	for index, event in timeline.automation_events_ {
		if event.time >= time {
			return index
		}
	}
	return timeline.automation_events_.len
}

fn curve_value(event AudioParamAutomationEvent, evaluation_time f64) f32 {
	if event.values.len == 0 {
		return event.value
	}
	if event.values.len == 1 || event.duration <= 0
		|| evaluation_time >= event.time + event.duration {
		return event.values.last()
	}
	if evaluation_time <= event.time {
		return event.values[0]
	}
	curve_position := f64(event.values.len - 1) * (evaluation_time - event.time) / event.duration
	mut value_index := int(math.floor(curve_position))
	if value_index > event.values.len - 2 {
		value_index = event.values.len - 2
	}
	interpolation_factor := f32(curve_position - f64(value_index))
	return event.values[value_index] + (event.values[value_index + 1] - event.values[value_index]) * interpolation_factor
}

fn evaluate_audio_param_event(event AudioParamAutomationEvent, evaluation_time f64,
	starting_value f32, minimum_time f64) f32 {
	return match event.kind {
		.set_value, .hold { event.value }
		.linear_ramp {
			if evaluation_time >= event.time || event.time <= minimum_time {
				event.value
			} else {
				progress := f32((evaluation_time - minimum_time) / (event.time - minimum_time))
				starting_value + (event.value - starting_value) * progress
			}
		}
		.exponential_ramp {
			if evaluation_time >= event.time || event.time <= minimum_time {
				event.value
			} else if starting_value == 0
				|| (starting_value < 0 && event.value > 0)
				|| (starting_value > 0 && event.value < 0) {
				starting_value
			} else {
				progress := (evaluation_time - minimum_time) / (event.time - minimum_time)
				starting_value * f32(math.pow(f64(event.value / starting_value), progress))
			}
		}
		.set_target {
			if event.time_constant == 0 {
				event.value
			} else {
				event.value + (starting_value - event.value) * f32(math.exp(-(evaluation_time - event.time) / f64(event.time_constant)))
			}
		}
		.set_value_curve { curve_value(event, evaluation_time) }
	}
}

fn (timeline &AudioParamTimeline) event_value_at_time(event_index int, time f64) f32 {
	mut first_event_index := event_index
	for first_event_index > 0
		&& timeline.automation_events_[first_event_index].kind == .set_target {
		first_event_index--
	}
	mut value := timeline.fallback_value_
	for current_index := first_event_index; current_index <= event_index; current_index++ {
		event := timeline.automation_events_[current_index]
		evaluation_time := if current_index == event_index {
			time
		} else {
			timeline.automation_events_[current_index + 1].time
		}
		value = evaluate_audio_param_event(event, evaluation_time, value, event.time)
	}
	return value
}

fn (timeline &AudioParamTimeline) parameterization_cache_for_time(time f64) ParameterizationCache {
	event_index := timeline.first_event_index_after(time)
	if event_index == 0 {
		return ParameterizationCache{
			maximum_time: if timeline.automation_events_.len == 0 {
				none
			} else {
				timeline.automation_events_[0].time
			}
			starting_value: timeline.fallback_value_
		}
	}

	// A following ramp owns the interval before its endpoint. A ramp following
	// an already-started target can retain a later, snapshotted start point.
	if event_index < timeline.automation_events_.len
		&& timeline.automation_events_[event_index].kind in [.linear_ramp, .exponential_ramp] {
		ramp := timeline.automation_events_[event_index]
		previous := timeline.automation_events_[event_index - 1]
		mut minimum_time := previous.time
		mut starting_value := f32(0)
		if ramp_start := ramp.ramp_start {
			if ramp_start.set_target_event_id == previous.id {
				minimum_time = ramp_start.time
				starting_value = ramp_start.value
			} else {
				if previous.kind == .set_value_curve {
					minimum_time = previous.time + previous.duration
				}
				starting_value = timeline.event_value_at_time(event_index - 1, minimum_time)
			}
		} else {
			if previous.kind == .set_value_curve {
				minimum_time = previous.time + previous.duration
			}
			starting_value = timeline.event_value_at_time(event_index - 1, minimum_time)
		}
		if time >= minimum_time && minimum_time < ramp.time {
			return ParameterizationCache{
				event_index: event_index
				minimum_time: minimum_time
				maximum_time: ramp.time
				starting_value: starting_value
			}
		}
	}

	selected_index := event_index - 1
	selected := timeline.automation_events_[selected_index]
	mut maximum_time := ?f64(none)
	if event_index < timeline.automation_events_.len {
		next_event := timeline.automation_events_[event_index]
		maximum_time = next_event.time
		if next_event.kind in [.linear_ramp, .exponential_ramp] {
			if ramp_start := next_event.ramp_start {
				if ramp_start.set_target_event_id == selected.id {
					maximum_time = ramp_start.time
				}
			}
		}
	}
	return ParameterizationCache{
		event_index: selected_index
		minimum_time: selected.time
		maximum_time: maximum_time
		starting_value: timeline.event_value_at_time(selected_index, selected.time)
	}
}

fn (timeline &AudioParamTimeline) value_at_time_locked(selection_time f64, time f64) f32 {
	cache := timeline.parameterization_cache_for_time(selection_time)
	event_index := cache.event_index or { return cache.starting_value }
	minimum_time := cache.minimum_time or { return cache.starting_value }
	event := timeline.automation_events_[event_index]
	return evaluate_audio_param_event(event, time, cache.starting_value, minimum_time)
}

pub fn (timeline &AudioParamTimeline) value_at_time(time f64) f32 {
	return timeline.value_at_time_locked(time, time)
}

pub fn (mut timeline AudioParamTimeline) sample(start_time f64, sample_period f64,
	mut output []f32) {
	for frame in 0 .. output.len {
		frame_time := start_time + f64(frame) * sample_period
		output[frame] = timeline.value_at_time_locked(frame_time + sample_period / 2, frame_time)
	}
	// The intrinsic value exposed to the control side is the first value of
	// this quantum, before any connected audio signal is mixed into it.
	if output.len > 0 { timeline.current_value_ = output[0] }
}

fn (timeline &AudioParamTimeline) ramp_start_for_insertion_index(event_index int,
	current_time f64) ?AudioParamRampStart {
	if event_index == 0 {
		return none
	}
	previous := timeline.automation_events_[event_index - 1]
	if previous.time >= current_time || previous.kind != .set_target {
		return none
	}
	return AudioParamRampStart{
		set_target_event_id: previous.id
		time: current_time
		value: timeline.event_value_at_time(event_index - 1, current_time)
	}
}

fn (mut timeline AudioParamTimeline) insert_event(input_event AudioParamAutomationEvent) AudioParamTimelineInsertResult {
	insertion_index := timeline.first_event_index_after(input_event.time)
	if insertion_index > 0 {
		previous := timeline.automation_events_[insertion_index - 1]
		if previous.kind == .set_value_curve
			&& input_event.time < previous.time + previous.duration
			&& input_event.kind != .hold {
			return .event_contained_in_value_curve
		}
	}
	mut event := input_event
	event.id = timeline.next_event_id_
	timeline.next_event_id_++
	timeline.automation_events_.insert(insertion_index, event)
	return .success
}

pub fn (mut timeline AudioParamTimeline) set_value_at_time(value f32,
	start_time f64) AudioParamTimelineInsertResult {
	return timeline.insert_event(AudioParamAutomationEvent{
		time: start_time
		kind: .set_value
		value: value
	})
}

pub fn (mut timeline AudioParamTimeline) linear_ramp_to_value_at_time(value f32,
	end_time f64, current_time f64, current_value f32) AudioParamTimelineInsertResult {
	event_index := timeline.first_event_index_after(end_time)
	ramp_start := timeline.ramp_start_for_insertion_index(event_index, current_time)
	if event_index == 0 {
		assert timeline.insert_event(AudioParamAutomationEvent{
			time: current_time
			kind: .set_value
			value: current_value
		}) == .success
	}
	return timeline.insert_event(AudioParamAutomationEvent{
		time: end_time
		kind: .linear_ramp
		value: value
		ramp_start: ramp_start
	})
}

pub fn (mut timeline AudioParamTimeline) exponential_ramp_to_value_at_time(value f32,
	end_time f64, current_time f64, current_value f32) AudioParamTimelineInsertResult {
	event_index := timeline.first_event_index_after(end_time)
	ramp_start := timeline.ramp_start_for_insertion_index(event_index, current_time)
	if event_index == 0 {
		assert timeline.insert_event(AudioParamAutomationEvent{
			time: current_time
			kind: .set_value
			value: current_value
		}) == .success
	}
	return timeline.insert_event(AudioParamAutomationEvent{
		time: end_time
		kind: .exponential_ramp
		value: value
		ramp_start: ramp_start
	})
}

pub fn (mut timeline AudioParamTimeline) set_target_at_time(target f32, start_time f64,
	time_constant f32) AudioParamTimelineInsertResult {
	return timeline.insert_event(AudioParamAutomationEvent{
		time: start_time
		kind: .set_target
		value: target
		time_constant: time_constant
	})
}

pub fn (mut timeline AudioParamTimeline) set_value_curve_at_time(values []f32,
	start_time f64, duration f64) AudioParamTimelineInsertResult {
	for event in timeline.automation_events_ {
		if event.time > start_time && event.time < start_time + duration {
			return .value_curve_overlaps_event
		}
	}
	return timeline.insert_event(AudioParamAutomationEvent{
		time: start_time
		kind: .set_value_curve
		values: values.clone()
		duration: duration
	})
}

pub fn (mut timeline AudioParamTimeline) cancel_scheduled_values(cancel_time f64) {
	mut first_event_to_remove := timeline.first_event_index_at_or_after(cancel_time)
	if first_event_to_remove > 0 {
		previous := timeline.automation_events_[first_event_to_remove - 1]
		if previous.kind == .set_target
			|| (previous.kind == .set_value_curve
				&& cancel_time <= previous.time + previous.duration) {
			first_event_to_remove--
		}
	}
	if first_event_to_remove < timeline.automation_events_.len {
		timeline.automation_events_.delete_many(first_event_to_remove, timeline.automation_events_.len - first_event_to_remove)
	}
	if timeline.automation_events_.len == 0 {
		timeline.fallback_value_ = timeline.current_value_
	}
}

pub fn (mut timeline AudioParamTimeline) cancel_and_hold_at_time(cancel_time f64) {
	value_to_hold := timeline.value_at_time_locked(cancel_time, cancel_time)
	mut event_index := timeline.first_event_index_after(cancel_time)
	mut rewrote_ramp := false
	if event_index < timeline.automation_events_.len
		&& timeline.automation_events_[event_index].kind in [.linear_ramp, .exponential_ramp] {
		timeline.automation_events_[event_index].time = cancel_time
		timeline.automation_events_[event_index].value = value_to_hold
		rewrote_ramp = true
	}

	mut hold_value := ?f32(none)
	mut drop_active_curve := false
	if !rewrote_ramp && event_index > 0 {
		active := timeline.automation_events_[event_index - 1]
		if active.kind == .set_target {
			hold_value = value_to_hold
		} else if active.kind == .set_value_curve {
			if active.time == cancel_time {
				drop_active_curve = true
				hold_value = if event_index >= 2 {
					timeline.event_value_at_time(event_index - 2, cancel_time)
				} else {
					timeline.fallback_value_
				}
			} else if cancel_time <= active.time + active.duration {
				hold_value = value_to_hold
			}
		}
	}
	if drop_active_curve {
		timeline.automation_events_.delete(event_index - 1)
		event_index--
	}
	if value := hold_value {
		assert timeline.insert_event(AudioParamAutomationEvent{
			time: cancel_time
			kind: .hold
			value: value
		}) == .success
	}
	first_event_to_remove := timeline.first_event_index_after(cancel_time)
	if first_event_to_remove < timeline.automation_events_.len {
		timeline.automation_events_.delete_many(first_event_to_remove, timeline.automation_events_.len - first_event_to_remove)
	}
}

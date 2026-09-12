// Copyright (c) 2023-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of AnimationTimeline.cpp and DocumentTimeline.cpp. Ladybird's
// virtual subclasses are represented by one tagged object so Animation can
// hold a safe V pointer without RTTI or unsafe base-class casts.
module animations

import dom
import highresolutiontime
import html

pub enum TimelineKind {
	generic
	document
	scroll
}

@[heap]
pub struct AnimationTimeline {
pub mut:
	kind_                                         TimelineKind
	current_time_                                 ?TimeValue
	duration_                                     ?TimeValue
	monotonic_                                    bool
	document_                                     ?&dom.Document
	document_active_                              ?bool
	origin_time_                                  f64
	associated_animations_                        []&Animation
	last_current_time_update_task_generation_     ?u64
	observed_current_time_                        ?TimeValue
	current_time_override_for_style_sampling_     ?TimeValue
	has_current_time_override_for_style_sampling_ bool
	monotonic_timestamp_offset_                   f64
	has_monotonic_timestamp_offset_               bool
	scroll_source_                                ?&dom.Element
	scroll_axis_                                  ScrollAxis
	scroll_metrics_                               ?ScrollMetrics
	last_max_scroll_offset_                       ?f64
}

pub fn AnimationTimeline.new() &AnimationTimeline {
	return &AnimationTimeline{}
}

// Translation of DocumentTimeline::create/construct_impl.
pub fn new_document_timeline(document ?&dom.Document, origin_time f64, timestamp f64) &AnimationTimeline {
	mut timeline := &AnimationTimeline{
		kind_: .document
		origin_time_: origin_time
	}
	timeline.set_associated_document(document)
	timeline.update_current_time(timestamp)
	return timeline
}

pub fn (timeline &AnimationTimeline) current_time() ?TimeValue {
	if timeline.is_inactive() {
		return none
	}
	return timeline.effective_current_time()
}

pub fn (timeline &AnimationTimeline) current_time_for_bindings() NullableCSSNumberish {
	return NullableCSSNumberish.from_optional_css_numberish_time(timeline.current_time_for_observation())
}

pub fn (timeline &AnimationTimeline) current_time_for_observation() ?TimeValue {
	if !timeline.monotonic_ || !timeline.can_sample_current_time_at_timestamp() {
		return timeline.current_time()
	}
	mut has_animation_without_per_frame_tick := false
	for animation in timeline.associated_animations_ {
		effect := animation.effect_ or { continue }
		if !effect.is_keyframe_effect_ {
			continue
		}
		keyframe_effect := unsafe { &KeyframeEffect(effect) }
		if keyframe_effect.per_frame_animation_tick_was_skipped()
			|| keyframe_effect.can_skip_per_frame_animation_tick() {
			has_animation_without_per_frame_tick = true
			break
		}
	}
	if !has_animation_without_per_frame_tick {
		return timeline.current_time()
	}
	task_generation := html.main_thread_event_loop().task_generation()
	if previous_generation := timeline.last_current_time_update_task_generation_ {
		if previous_generation == task_generation {
			return timeline.observed_current_time_
		}
	}
	mut mutable_timeline := unsafe { &AnimationTimeline(timeline) }
	timestamp := mutable_timeline.observation_timestamp()
	mutable_timeline.observed_current_time_ = mutable_timeline.current_time_at_timestamp(timestamp)
	mutable_timeline.last_current_time_update_task_generation_ = task_generation
	return mutable_timeline.observed_current_time_
}

pub fn (timeline &AnimationTimeline) duration() ?TimeValue {
	return timeline.duration_
}

pub fn (timeline &AnimationTimeline) duration_for_bindings() NullableCSSNumberish {
	return NullableCSSNumberish.from_optional_css_numberish_time(timeline.duration())
}

pub fn (timeline &AnimationTimeline) associated_document() ?&dom.Document {
	return timeline.document_
}

fn update_animation_timeline_for_document(target voidptr, timestamp f64) {
	if target == unsafe { nil } {
		return
	}
	mut timeline := unsafe { &AnimationTimeline(target) }
	if document := timeline.document_ {
		timeline.set_document_active(document.is_active())
	}
	timeline.update_current_time(timestamp)
}

fn animation_timeline_handle(timeline &AnimationTimeline) dom.AnimationTimelineHandle {
	return dom.AnimationTimelineHandle{
		target: voidptr(timeline)
		update_current_time: update_animation_timeline_for_document
	}
}

pub fn (mut timeline AnimationTimeline) set_associated_document(document ?&dom.Document) {
	if new_document := document {
		mut mutable_document := unsafe { &dom.Document(new_document) }
		mutable_document.associate_with_timeline(animation_timeline_handle(timeline))
	}
	if old_document := timeline.document_ {
		mut mutable_document := unsafe { &dom.Document(old_document) }
		mutable_document.disassociate_with_timeline(animation_timeline_handle(timeline))
	}
	timeline.document_ = document
}

pub fn (timeline &AnimationTimeline) is_progress_based() bool {
	return timeline.kind_ == .scroll
}

pub fn (timeline &AnimationTimeline) is_monotonically_increasing() bool {
	return timeline.monotonic_
}

pub fn (timeline &AnimationTimeline) is_inactive() bool {
	if timeline.effective_current_time() == none {
		return true
	}
	if timeline.kind_ == .document {
		if active := timeline.document_active_ {
			return !active
		}
		if document := timeline.document_ {
			return !document.is_active()
		}
	}
	return false
}

pub fn (mut timeline AnimationTimeline) set_document_active(active bool) {
	timeline.document_active_ = active
}

// AnimationTimeline::set_current_time prevents a monotonic timeline from
// moving backwards. It deliberately ignores an invalid update, as upstream.
pub fn (mut timeline AnimationTimeline) set_current_time(value ?TimeValue) {
	if timeline.monotonic_ {
		if old := timeline.current_time_ {
			next := value or { return }
			if old.type_ != next.type_ || next.value < old.value {
				return
			}
		}
	}
	timeline.current_time_ = value
	timeline.observed_current_time_ = value
	timeline.last_current_time_update_task_generation_ = html.main_thread_event_loop().task_generation()
	timeline.update_associated_animations()
}

pub fn (mut timeline AnimationTimeline) update_associated_animations() {
	for animation in timeline.associated_animations_ {
		mut mutable_animation := unsafe { &Animation(animation) }
		mutable_animation.update()
	}
}

pub fn (timeline &AnimationTimeline) effective_current_time() ?TimeValue {
	if timeline.has_current_time_override_for_style_sampling_ {
		return timeline.current_time_override_for_style_sampling_
	}
	return timeline.current_time_
}

pub fn (mut timeline AnimationTimeline) set_current_time_override_for_style_sampling(value ?TimeValue) {
	timeline.current_time_override_for_style_sampling_ = value
	timeline.has_current_time_override_for_style_sampling_ = true
}

pub fn (mut timeline AnimationTimeline) clear_current_time_override_for_style_sampling() {
	timeline.has_current_time_override_for_style_sampling_ = false
}

pub fn (timeline &AnimationTimeline) can_sample_current_time_at_timestamp() bool {
	return timeline.kind_ == .document
}

pub fn (timeline &AnimationTimeline) current_time_at_timestamp(timestamp f64) ?TimeValue {
	if timeline.kind_ != .document {
		return timeline.current_time()
	}
	if timeline.is_inactive() {
		return none
	}
	return TimeValue.milliseconds(timestamp - timeline.origin_time_)
}

fn (timeline &AnimationTimeline) observation_timestamp() f64 {
	monotonic_now := highresolutiontime.unsafe_shared_current_time()
	if timeline.has_monotonic_timestamp_offset_ {
		return monotonic_now - timeline.monotonic_timestamp_offset_
	}
	return monotonic_now
}

fn (mut timeline AnimationTimeline) update_document_current_time(timestamp f64) {
	timeline.monotonic_timestamp_offset_ = highresolutiontime.unsafe_shared_current_time() - timestamp
	timeline.has_monotonic_timestamp_offset_ = true
	timeline.set_current_time(TimeValue.milliseconds(timestamp - timeline.origin_time_))
	if !timeline.monotonic_ && !timeline.is_inactive() {
		timeline.monotonic_ = true
	}
}

pub fn (mut timeline AnimationTimeline) update_current_time(timestamp f64) {
	match timeline.kind_ {
		.document {
			timeline.update_document_current_time(timestamp)
		}
		.scroll {
			timeline.update_from_scroll_metrics(timeline.scroll_axis_, timeline.scroll_metrics_)
		}
		else {
			timeline.set_current_time(TimeValue.milliseconds(timestamp))
		}
	}
}

pub fn (timeline &AnimationTimeline) can_convert_to_origin_relative_time() bool {
	return timeline.kind_ == .document
}

pub fn (timeline &AnimationTimeline) can_convert_a_timeline_time_to_an_origin_relative_time() bool {
	return timeline.can_convert_to_origin_relative_time()
}

pub fn (timeline &AnimationTimeline) convert_to_origin_relative_time(value ?TimeValue) ?f64 {
	if timeline.kind_ != .document || timeline.is_inactive() {
		return none
	}
	timeline_time := value or { return none }
	if timeline_time.type_ != .milliseconds {
		return none
	}
	return timeline_time.value + timeline.origin_time_
}

pub fn (timeline &AnimationTimeline) convert_a_timeline_time_to_an_origin_relative_time(value ?TimeValue) ?f64 {
	return timeline.convert_to_origin_relative_time(value)
}

pub fn (mut timeline AnimationTimeline) associate_with_animation(animation &Animation) {
	for existing in timeline.associated_animations_ {
		if existing == animation {
			return
		}
	}
	timeline.associated_animations_ << animation
}

pub fn (mut timeline AnimationTimeline) disassociate_with_animation(animation &Animation) {
	for index, existing in timeline.associated_animations_ {
		if existing == animation {
			timeline.associated_animations_.delete(index)
			return
		}
	}
}

pub fn (timeline &AnimationTimeline) associated_animations() []&Animation {
	return timeline.associated_animations_.clone()
}

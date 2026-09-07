// Copyright (c) 2023-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of AnimationTimeline.cpp and DocumentTimeline.cpp. Ladybird's
// virtual subclasses are represented by one tagged object so Animation can
// hold a safe V pointer without RTTI or unsafe base-class casts.
module animations

import dom

pub enum TimelineKind {
	generic
	document
	scroll
}

@[heap]
pub struct AnimationTimeline {
pub mut:
	kind_                  TimelineKind
	current_time_          ?TimeValue
	duration_              ?TimeValue
	monotonic_             bool
	document_              ?&dom.Document
	document_active_       ?bool
	origin_time_           f64
	associated_animations_ []&Animation
	scroll_source_         ?&dom.Element
	scroll_axis_           ScrollAxis
	scroll_metrics_        ?ScrollMetrics
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
	return timeline.current_time_
}

pub fn (timeline &AnimationTimeline) current_time_for_bindings() NullableCSSNumberish {
	return NullableCSSNumberish.from_optional_css_numberish_time(timeline.current_time())
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
	if timeline.current_time_ == none {
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
			if next := value {
				if old.type_ != next.type_ || next.value < old.value {
					return
				}
			}
		}
	}
	timeline.current_time_ = value
}

pub fn (mut timeline AnimationTimeline) update_current_time(timestamp f64) {
	match timeline.kind_ {
		.document {
			timeline.set_current_time(TimeValue.milliseconds(timestamp - timeline.origin_time_))
			if !timeline.monotonic_ && !timeline.is_inactive() {
				timeline.monotonic_ = true
			}
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

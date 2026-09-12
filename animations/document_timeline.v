// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Animations/DocumentTimeline.{h,cpp}. The
// concrete type aliases the tagged AnimationTimeline representation used by
// the V port while preserving the complete upstream surface.
module animations

import dom
import highresolutiontime
import html

pub struct DocumentTimelineOptions {
pub:
	origin_time f64
}

pub type DocumentTimeline = AnimationTimeline

pub fn DocumentTimeline.create(document ?&dom.Document, origin_time f64, timestamp f64) &DocumentTimeline {
	base := new_document_timeline(document, origin_time, timestamp)
	return unsafe { &DocumentTimeline(base) }
}

pub fn DocumentTimeline.construct_impl(document ?&dom.Document, options DocumentTimelineOptions, timestamp f64) !&DocumentTimeline {
	return DocumentTimeline.create(document, options.origin_time, timestamp)
}

pub fn DocumentTimeline.create_for_constructor(document &dom.Document, options DocumentTimelineOptions) &DocumentTimeline {
	timestamp := document.last_animation_frame_timestamp_value() or {
		settings_pointer := document.relevant_settings_object()
		if settings_pointer == unsafe { nil } {
			0.0
		} else {
			settings := unsafe { &html.EnvironmentSettingsObject(settings_pointer) }
			highresolutiontime.relative_high_resolution_time(settings.time_origin(), highresolutiontime.TimeOriginContext{
				time_origin: settings.time_origin()
				cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
			})
		}
	}
	return DocumentTimeline.create(document, options.origin_time, timestamp)
}

pub fn (timeline &DocumentTimeline) duration() ?TimeValue {
	return none
}

pub fn (mut timeline DocumentTimeline) update_current_time(timestamp f64) {
	timeline.update_document_current_time(timestamp)
}

pub fn (timeline &DocumentTimeline) current_time_at_timestamp(timestamp f64) ?TimeValue {
	return unsafe { &AnimationTimeline(timeline) }.current_time_at_timestamp(timestamp)
}

pub fn (_ &DocumentTimeline) can_sample_current_time_at_timestamp() bool {
	return true
}

pub fn (timeline &DocumentTimeline) is_inactive() bool {
	if timeline.current_time_ == none {
		return true
	}
	if active := timeline.document_active_ {
		return !active
	}
	if document := timeline.document_ {
		return !document.is_active()
	}
	return false
}

pub fn (timeline &DocumentTimeline) convert_a_timeline_time_to_an_origin_relative_time(value ?TimeValue) ?f64 {
	if timeline.is_inactive() {
		return none
	}
	time := value or { return none }
	if time.type_ != .milliseconds {
		return none
	}
	return time.value + timeline.origin_time_
}

pub fn (timeline &DocumentTimeline) can_convert_a_timeline_time_to_an_origin_relative_time() bool {
	return true
}

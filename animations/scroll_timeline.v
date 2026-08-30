// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Animations/ScrollTimeline.{h,cpp}.
module animations

import css
import dom

pub enum ScrollAxis {
	block
	inline_
	x
	y
}

pub struct ComputedScrollAxis {
pub:
	is_vertical bool
	is_reversed bool
}

pub struct ScrollMetrics {
pub:
	is_scroll_container bool
	has_overflow        bool
	scroll_x            f64
	scroll_y            f64
	overflow_width      f64
	overflow_height     f64
	container_width     f64
	container_height    f64
	writing_mode        css.WritingMode
	direction           css.Direction
}

pub struct ScrollTimelineOptions {
pub:
	// source_is_present preserves Web IDL's distinction between an omitted
	// source and an explicitly null source.
	source_is_present bool
	source            ?&dom.Element
	axis              ScrollAxis = .block
}

pub fn scroll_axis_from_css(axis css.Axis) ScrollAxis {
	return match axis {
		.block { .block }
		.inline_ { .inline_ }
		.x { .x }
		.y { .y }
	}
}

pub fn computed_scroll_axis(axis ScrollAxis, writing_mode css.WritingMode, direction css.Direction) ComputedScrollAxis {
	return match axis {
		.block {
			match writing_mode {
				.horizontal_tb { ComputedScrollAxis{true, false} }
				.vertical_rl, .sideways_rl { ComputedScrollAxis{false, true} }
				.vertical_lr, .sideways_lr { ComputedScrollAxis{false, false} }
			}
		}
		.inline_ {
			match writing_mode {
				.horizontal_tb {
					ComputedScrollAxis{false, direction == .rtl}
				}
				.vertical_rl, .sideways_rl, .vertical_lr {
					ComputedScrollAxis{true, direction == .rtl}
				}
				.sideways_lr {
					ComputedScrollAxis{true, direction == .ltr}
				}
			}
		}
		.x {
			ComputedScrollAxis{false, false}
		}
		.y {
			ComputedScrollAxis{true, false}
		}
	}
}

pub fn new_scroll_timeline(axis ScrollAxis) &AnimationTimeline {
	return &AnimationTimeline{
		kind_:        .scroll
		duration_:    TimeValue.percentage(100)
		scroll_axis_: axis
	}
}

// ScrollTimeline::update_current_time. Layout supplies a metric snapshot so
// this module does not create a CSS/Animations/Layout import cycle.
pub fn (mut timeline AnimationTimeline) update_from_scroll_metrics(axis ScrollAxis, metrics ?ScrollMetrics) {
	if timeline.kind_ != .scroll {
		return
	}
	timeline.set_current_time(none)
	timeline.scroll_axis_ = axis
	timeline.scroll_metrics_ = metrics
	value := metrics or { return }
	if !value.is_scroll_container || !value.has_overflow {
		return
	}
	computed := computed_scroll_axis(axis, value.writing_mode, value.direction)
	overflow_size := if computed.is_vertical { value.overflow_height } else { value.overflow_width }
	container_size := if computed.is_vertical {
		value.container_height
	} else {
		value.container_width
	}
	denominator := overflow_size - container_size
	if denominator == 0 {
		return
	}
	offset := if computed.is_vertical { value.scroll_y } else { value.scroll_x }
	// Upstream computes is_reversed but intentionally leaves reversed-axis
	// progress as a FIXME, so the translated behavior does the same.
	timeline.set_current_time(TimeValue.percentage(offset / denominator * 100.0))
}

pub fn css_axis_to_bindings_scroll_axis(axis css.Axis) ScrollAxis {
	return scroll_axis_from_css(axis)
}

pub type ScrollTimeline = AnimationTimeline

pub fn ScrollTimeline.create(document ?&dom.Document, source ?&dom.Element, axis ScrollAxis, metrics ?ScrollMetrics) &ScrollTimeline {
	mut base := new_scroll_timeline(axis)
	base.set_associated_document(document)
	base.scroll_source_ = source
	base.update_from_scroll_metrics(axis, metrics)
	return unsafe { &ScrollTimeline(base) }
}

pub fn ScrollTimeline.construct_impl(document ?&dom.Document, scrolling_element ?&dom.Element, options ScrollTimelineOptions, metrics ?ScrollMetrics) !&ScrollTimeline {
	source := if options.source_is_present { options.source } else { scrolling_element }
	return ScrollTimeline.create(document, source, options.axis, metrics)
}

pub fn (timeline &ScrollTimeline) duration() ?TimeValue {
	return TimeValue.percentage(100)
}

pub fn (timeline &ScrollTimeline) source() ?&dom.Element {
	return timeline.scroll_source_
}

pub fn (timeline &ScrollTimeline) axis() ScrollAxis {
	return timeline.scroll_axis_
}

pub fn (timeline &ScrollTimeline) source_internal() ?&dom.Element {
	return timeline.scroll_source_
}

pub fn (mut timeline ScrollTimeline) update_current_time(_ f64) {
	timeline.update_from_scroll_metrics(timeline.scroll_axis_, timeline.scroll_metrics_)
}

pub fn (timeline &ScrollTimeline) get_propagated_source() ?&dom.Element {
	// The DOM/Layout bridge supplies root-element viewport metrics in the same
	// ScrollMetrics form as element metrics, so propagation preserves the
	// source identity at this typed boundary.
	return timeline.source()
}

pub fn (timeline &ScrollTimeline) is_progress_based() bool {
	return true
}

pub fn (timeline &ScrollTimeline) can_convert_a_timeline_time_to_an_origin_relative_time() bool {
	return false
}

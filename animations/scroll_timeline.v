// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Animations/ScrollTimeline.{h,cpp}.
module animations

import css

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
		kind_:     .scroll
		duration_: TimeValue.percentage(100)
	}
}

// ScrollTimeline::update_current_time. Layout supplies a metric snapshot so
// this module does not create a CSS/Animations/Layout import cycle.
pub fn (mut timeline AnimationTimeline) update_from_scroll_metrics(axis ScrollAxis, metrics ?ScrollMetrics) {
	if timeline.kind_ != .scroll {
		return
	}
	timeline.set_current_time(none)
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

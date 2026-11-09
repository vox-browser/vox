// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import platform

// https://drafts.csswg.org/css-inline/#dominant-baseline-property
pub fn dominant_baseline_offset(metric css.BaselineMetric, font_metrics platform.FontPixelMetrics) f32 {
	return match metric {
		.central { (font_metrics.ascent - font_metrics.descent) / 2 }
		.middle { font_metrics.x_height / 2 }
		.hanging { font_metrics.ascent * 0.8 }
		.ideographic { -font_metrics.descent }
		.mathematical { font_metrics.ascent * 0.5 }
		.text_top, .text_bottom, .alphabetic { 0 }
	}
}

pub fn resolve_dominant_baseline_metric(computed_values &css.ComputedValues) css.BaselineMetric {
	if dominant_baseline := computed_values.dominant_baseline() {
		return dominant_baseline
	}

	// `auto` is alphabetic in horizontal and sideways writing modes, and
	// central in vertical writing modes with mixed/upright text orientation.
	if computed_values.text_orientation() == .sideways { return .alphabetic }
	return match computed_values.writing_mode() {
		.horizontal_tb, .sideways_rl, .sideways_lr { css.BaselineMetric.alphabetic }
		.vertical_rl, .vertical_lr { css.BaselineMetric.central }
	}
}

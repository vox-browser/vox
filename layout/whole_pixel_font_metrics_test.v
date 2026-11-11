// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module layout

import platform

fn test_libweb_font_bounds_and_leading_keep_whole_pixel_baselines() {
	metrics := libweb_layout_font_metrics(platform.FontPixelMetrics{
		ascent: 12.5
		descent: 3.5
		x_height: 7.25
		line_gap: 2
	})
	assert metrics.ascent == 12
	assert metrics.descent == 4
	assert metrics.x_height == 7.25
	assert normal_line_height_for_font_metrics(metrics) == CSSPixels.new(16)
	assert font_baseline_for_line_height(metrics, CSSPixels.new(21)) == CSSPixels.new(14)
	assert font_baseline_for_line_height(metrics, CSSPixels.new(13)) == CSSPixels.new(10)
	assert font_baseline_for_line_height(metrics, CSSPixels.nearest_value_for(21.5)) == CSSPixels.new(14)
	assert inline_half_leading(CSSPixels.new(-3), metrics) == CSSPixels.new(-2)
}

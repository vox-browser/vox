// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module layout

import css
import dom
import svg

// SVG images use preserveAspectRatio, including its initial xMidYMid meet
// value, rather than the CSS object-fit and object-position properties.
fn svg_image_fit(element &dom.Element) (css.ObjectFit, css.Position) {
	ratio := svg.parse_preserve_aspect_ratio(element.get_attribute_value('preserveAspectRatio')) or {
		svg.PreserveAspectRatio{}
	}
	fit := if ratio.align == .none_ { css.ObjectFit.fill }
		else if ratio.meet_or_slice == .slice { css.ObjectFit.cover }
		else { css.ObjectFit.contain }
	x := match ratio.align {
		.x_min_y_min, .x_min_y_mid, .x_min_y_max, .none_ { 0.0 }
		.x_mid_y_min, .x_mid_y_mid, .x_mid_y_max { 50.0 }
		else { 100.0 }
	}
	y := match ratio.align {
		.x_min_y_min, .x_mid_y_min, .x_max_y_min, .none_ { 0.0 }
		.x_min_y_mid, .x_mid_y_mid, .x_max_y_mid { 50.0 }
		else { 100.0 }
	}
	return fit, css.Position{
		offset_x: css.LengthPercentage.from_percentage(css.Percentage.new(x))
		offset_y: css.LengthPercentage.from_percentage(css.Percentage.new(y))
	}
}

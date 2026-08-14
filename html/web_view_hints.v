// Copyright (c) 2024, Andrew Kaster <akaster@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/WebViewHints.cpp.
module html

pub struct WebExposedScreenArea {
pub:
	x      i32
	y      i32
	width  i32
	height i32
}

pub struct WebViewHints {
pub mut:
	popup    bool
	width    ?f64
	height   ?f64
	screen_x ?f64
	screen_y ?f64
}

pub fn WebViewHints.from_tokenised_features(tokenized_features map[string]string, available_screen_area WebExposedScreenArea, device_pixels_per_css_pixel f64) WebViewHints {
	mut hints := WebViewHints{
		popup: check_if_a_popup_window_is_requested(tokenized_features) == .yes
	}
	hints.set_up_browsing_context_features(tokenized_features, available_screen_area,
		device_pixels_per_css_pixel)
	return hints
}

// https://drafts.csswg.org/cssom-view/#set-up-browsing-context-features
fn (mut target WebViewHints) set_up_browsing_context_features(tokenized_features map[string]string, available_screen_area WebExposedScreenArea, scale f64) {
	mut x := ?i32(none)
	mut y := ?i32(none)
	mut width := ?i32(none)
	mut height := ?i32(none)

	if left := tokenized_features['left'] {
		mut parsed_x := parse_integer(left) or { i32(0) }
		if parsed_x > available_screen_area.x {
			parsed_x = available_screen_area.x
		}
		x = parsed_x
	}

	if top := tokenized_features['top'] {
		mut parsed_y := parse_integer(top) or { i32(0) }
		if parsed_y > available_screen_area.y {
			parsed_y = available_screen_area.y
		}
		y = parsed_y
	}

	if width_token := tokenized_features['width'] {
		mut parsed_width := parse_integer(width_token) or { i32(0) }
		if parsed_width != 0 {
			if parsed_width < 100 {
				parsed_width = 100
			} else if parsed_width > available_screen_area.width {
				parsed_width = available_screen_area.width
			}
		}
		width = parsed_width
	}

	if height_token := tokenized_features['height'] {
		mut parsed_height := parse_integer(height_token) or { i32(0) }
		if parsed_height != 0 {
			if parsed_height < 100 {
				parsed_height = 100
			} else if parsed_height > available_screen_area.height {
				parsed_height = available_screen_area.height
			}
		}
		height = parsed_height
	}

	if mut x_value := x {
		width_value := width or { i32(0) }
		if x_value + width_value > available_screen_area.width {
			x_value = available_screen_area.width - width_value
		}
		target.screen_x = f64(x_value) / scale
	}
	if mut y_value := y {
		height_value := height or { i32(0) }
		if y_value + height_value > available_screen_area.height {
			y_value = available_screen_area.height - height_value
		}
		target.screen_y = f64(y_value) / scale
	}
	if width_value := width {
		target.width = f64(width_value) / scale
	}
	if height_value := height {
		target.height = f64(height_value) / scale
	}
}

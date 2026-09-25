// Copyright (c) 2023, Bastiaan van der Plaat <bastiaan.v.d.plaat@gmail.com>
// Copyright (c) 2023, Callum Law <callumlaw1709@outlook.com>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Canvas/CanvasTextDrawingStyles.{h,cpp}.
module html

import css
import strconv

@[heap]
pub struct CanvasTextDrawingStyles {
mut:
	state &CanvasState
}

pub fn CanvasTextDrawingStyles.create(state &CanvasState) &CanvasTextDrawingStyles {
	return &CanvasTextDrawingStyles{
		state: state
	}
}

fn (styles &CanvasTextDrawingStyles) my_drawing_state() &DrawingState {
	return &styles.state.drawing_state
}

pub fn (styles &CanvasTextDrawingStyles) font() string {
	return styles.state.drawing_state.font_string
}

fn canvas_font_size_in_css_pixels(font_value css.StyleValue, resolution_context css.LengthResolutionContext) ?f64 {
	shorthand := if font_value is css.ShorthandStyleValue {
		font_value
	} else {
		return none
	}
	font_size := shorthand.longhand(.font_size)?
	return match font_size {
		css.LengthStyleValue {
			font_size.length().to_px(resolution_context).to_double()
		}
		css.CalculatedStyleValue {
			length := font_size.resolve_length(css.CalculationResolutionContext{
				length_resolution_context: resolution_context
			})?
			length.to_px(resolution_context).to_double()
		}
		css.PercentageStyleValue {
			resolution_context.font_metrics.font_size.to_double() * font_size.percentage().as_fraction()
		}
		else {
			return none
		}
	}
}

pub fn (mut styles CanvasTextDrawingStyles) set_font(font string) {
	trimmed := font.trim_space()
	if trimmed == '' || trimmed in ['inherit', 'initial', 'unset', 'revert', 'revert-layer'] {
		return
	}
	parsed := css.parse_css_value_logic(.font, trimmed) or { return }
	// CanvasTextDrawingStyles.cpp uses ResolutionContext::for_document(), not
	// for_window(): a canvas can have a valid node document without a Window.
	resolution_context := if document := styles.state.font_resolution_document() {
		css.LengthResolutionContext.for_document(document)
	} else {
		css.LengthResolutionContext.default()
	}
	if resolved_size := canvas_font_size_in_css_pixels(parsed, resolution_context) {
		if resolved_size > 0 {
			styles.state.drawing_state.font_size_px = resolved_size
		}
	}
	styles.state.drawing_state.font_string = trimmed
	styles.state.drawing_state.current_font_cascade_list = none
	styles.state.drawing_state.font_environment_generation = 0
	refresh_canvas_font_cascade(mut styles.state)
}

fn canvas_font_family_names(font_value css.StyleValue) []string {
	shorthand := if font_value is css.ShorthandStyleValue {
		font_value
	} else {
		return []
	}
	family_value := shorthand.longhand(.font_family) or { return [] }
	families := family_value.as_value_list() or { return [] }
	mut result := []string{cap: families.size()}
	for family in families.values() {
		mut name := family.serialize(.normal).trim_space()
		if name.len >= 2 && ((name[0] == `"` && name[name.len - 1] == `"`)
			|| (name[0] == `'` && name[name.len - 1] == `'`)) {
			name = name[1..name.len - 1]
		}
		if name != '' {
			result << name
		}
	}
	return result
}

fn canvas_font_weight(font_value css.StyleValue) f64 {
	shorthand := if font_value is css.ShorthandStyleValue {
		font_value
	} else {
		return 400
	}
	weight := shorthand.longhand(.font_weight) or { return 400 }
	return match weight.to_keyword() {
		.normal { 400 }
		.bold { 700 }
		.invalid {
			if weight.is_number() { css.number_from_style_value(weight, none) } else { 400 }
		}
		else { 400 }
	}
}

fn canvas_font_slope(font_value css.StyleValue) int {
	shorthand := if font_value is css.ShorthandStyleValue {
		font_value
	} else {
		return 0
	}
	style := shorthand.longhand(.font_style) or { return 0 }
	font_style := style.as_font_style() or { return 0 }
	return font_style.to_font_slope()
}

fn canvas_font_width(font_value css.StyleValue) css.Percentage {
	shorthand := if font_value is css.ShorthandStyleValue {
		font_value
	} else {
		return css.Percentage{ value_: 100 }
	}
	width := shorthand.longhand(.font_width) or { return css.Percentage{ value_: 100 } }
	if width.is_percentage() {
		return width.as_percentage().percentage()
	}
	percentage := match width.to_keyword() {
		.ultra_condensed { 50.0 }
		.extra_condensed { 62.5 }
		.condensed { 75.0 }
		.semi_condensed { 87.5 }
		.semi_expanded { 112.5 }
		.expanded { 125.0 }
		.extra_expanded { 150.0 }
		.ultra_expanded { 200.0 }
		else { 100.0 }
	}
	return css.Percentage{ value_: percentage }
}

fn refresh_canvas_font_cascade(mut state CanvasState) {
	document := state.font_resolution_document() or { return }
	style_computer := css.css_style_computer_for(document)
	mut font_computer := unsafe { &css.FontComputer(style_computer.font_computer()) }
	if state.drawing_state.current_font_cascade_list != none
		&& state.drawing_state.font_environment_generation == font_computer.environment_generation() {
		return
	}
	parsed := css.parse_css_value_logic(.font, state.drawing_state.font_string) or { return }
	families := canvas_font_family_names(parsed)
	if families.len == 0 {
		return
	}
	computed := font_computer.compute_font_for_style_values(families,
		css.CSSPixels.nearest_value_for(state.drawing_state.font_size_px), canvas_font_slope(parsed),
		canvas_font_weight(parsed), canvas_font_width(parsed), .auto_, map[string]f64{},
		css.FontFeatureData{})
	// The font computer owns its cached cascade. Shaping resolves pending faces
	// in place, so the drawing state keeps its own list.
	mut cascade := css.FontCascadeList.create()
	cascade.extend(computed)
	state.drawing_state.current_font_cascade_list = cascade
	state.drawing_state.font_environment_generation = font_computer.environment_generation()
}

pub fn (styles &CanvasTextDrawingStyles) text_align() CanvasTextAlign {
	return styles.state.drawing_state.text_align
}

pub fn (mut styles CanvasTextDrawingStyles) set_text_align(value CanvasTextAlign) {
	styles.state.drawing_state.text_align = value
}

pub fn (styles &CanvasTextDrawingStyles) text_baseline() CanvasTextBaseline {
	return styles.state.drawing_state.text_baseline
}

pub fn (mut styles CanvasTextDrawingStyles) set_text_baseline(value CanvasTextBaseline) {
	styles.state.drawing_state.text_baseline = value
}

pub fn (styles &CanvasTextDrawingStyles) direction() CanvasDirection {
	return styles.state.drawing_state.direction
}

pub fn (mut styles CanvasTextDrawingStyles) set_direction(value CanvasDirection) {
	styles.state.drawing_state.direction = value
}

pub fn (styles &CanvasTextDrawingStyles) letter_spacing() string {
	return styles.state.drawing_state.letter_spacing_string
}

fn parse_canvas_letter_spacing(value string) ?f64 {
	trimmed := value.trim_space()
	if trimmed == '0' { return 0.0 }
	if !trimmed.ends_with('px') { return none }
	number := strconv.atof64(trimmed[..trimmed.len - 2]) or { return none }
	return number
}

pub fn (mut styles CanvasTextDrawingStyles) set_letter_spacing(value string) {
	pixels := parse_canvas_letter_spacing(value) or { return }
	styles.state.drawing_state.letter_spacing_px = pixels
	styles.state.drawing_state.letter_spacing_string = if pixels == 0 {
		'0px'
	} else {
		'${pixels}px'
	}
}

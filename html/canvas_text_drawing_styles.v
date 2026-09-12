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

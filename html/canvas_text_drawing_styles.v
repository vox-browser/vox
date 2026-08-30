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

pub fn (mut styles CanvasTextDrawingStyles) set_font(font string) {
	trimmed := font.trim_space()
	if trimmed == '' || trimmed in ['inherit', 'initial', 'unset', 'revert', 'revert-layer'] {
		return
	}
	if css.parse_css_value_logic(.font, trimmed) == none {
		return
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

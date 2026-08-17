// Copyright (c) 2020-2025, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Canvas/CanvasFillStrokeStyles.{h,cpp}.
module html

import css
import dom

pub struct CanvasPatternStyleValue {
pub:
	pattern &CanvasPattern = unsafe { nil }
}

pub type CanvasFillStrokeStyleValue = CanvasGradient | CanvasPatternStyleValue | string

@[heap]
pub struct CanvasFillStrokeStyles {
mut:
	state &CanvasState
}

pub fn CanvasFillStrokeStyles.create(state &CanvasState) &CanvasFillStrokeStyles {
	return &CanvasFillStrokeStyles{
		state: state
	}
}

fn css_color_to_dom(color css.Color) dom.Color {
	return dom.Color{
		r: color.r
		g: color.g
		b: color.b
		a: color.a
	}
}

fn fill_or_stroke_style_from_value(value CanvasFillStrokeStyleValue) ?FillOrStrokeStyle {
	return match value {
		string {
			color := css.parse_color_string(value as string) or { return none }
			FillOrStrokeStyle.from_color(css_color_to_dom(color))
		}
		CanvasGradient {
			FillOrStrokeStyle.from_gradient(value as CanvasGradient)
		}
		CanvasPatternStyleValue {
			pattern := (value as CanvasPatternStyleValue).pattern
			if pattern == unsafe { nil } { return none }
			FillOrStrokeStyle.from_pattern(pattern)
		}
	}
}

fn fill_or_stroke_style_to_value(style FillOrStrokeStyle) CanvasFillStrokeStyleValue {
	return match style.kind {
		.color {
			CanvasFillStrokeStyleValue('rgba(${style.color.r}, ${style.color.g}, ${style.color.b}, ${f64(style.color.a) / 255.0})')
		}
		.gradient {
			CanvasFillStrokeStyleValue(style.gradient or { CanvasGradient{} })
		}
		.pattern {
			CanvasFillStrokeStyleValue(CanvasPatternStyleValue{
				pattern: style.pattern or { unsafe { nil } }
			})
		}
	}
}

pub fn (mut styles CanvasFillStrokeStyles) set_fill_style(value CanvasFillStrokeStyleValue) {
	style := fill_or_stroke_style_from_value(value) or { return }
	styles.state.drawing_state.fill_style = style
}

pub fn (styles &CanvasFillStrokeStyles) fill_style() CanvasFillStrokeStyleValue {
	return fill_or_stroke_style_to_value(styles.state.drawing_state.fill_style)
}

pub fn (mut styles CanvasFillStrokeStyles) set_stroke_style(value CanvasFillStrokeStyleValue) {
	style := fill_or_stroke_style_from_value(value) or { return }
	styles.state.drawing_state.stroke_style = style
}

pub fn (styles &CanvasFillStrokeStyles) stroke_style() CanvasFillStrokeStyleValue {
	return fill_or_stroke_style_to_value(styles.state.drawing_state.stroke_style)
}

pub fn (_ &CanvasFillStrokeStyles) create_radial_gradient(x0 f64, y0 f64, r0 f64, x1 f64, y1 f64, r1 f64) !CanvasGradient {
	return CanvasGradient.create_radial(x0, y0, r0, x1, y1, r1)
}

pub fn (_ &CanvasFillStrokeStyles) create_linear_gradient(x0 f64, y0 f64, x1 f64, y1 f64) CanvasGradient {
	return CanvasGradient.create_linear(x0, y0, x1, y1)
}

pub fn (_ &CanvasFillStrokeStyles) create_conic_gradient(start_angle f64, x f64, y f64) CanvasGradient {
	return CanvasGradient.create_conic(start_angle, x, y)
}

pub fn (_ &CanvasFillStrokeStyles) create_pattern(image CanvasImageSource, repetition string) !CanvasPatternCreateResult {
	return CanvasPattern.create(image, repetition)
}

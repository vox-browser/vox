// Copyright (c) 2022, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2023, MacDue <macdue@dueutil.tech>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/CanvasGradient.cpp.
module html

import css

pub enum CanvasGradientKind {
	linear
	radial
	conic
}

pub struct CanvasColorStop {
pub:
	offset f64
	color  css.Color
}

@[heap]
struct CanvasGradientColorStops {
mut:
	values []CanvasColorStop
}

pub struct CanvasGradient {
pub:
	kind        CanvasGradientKind
	x0          f64
	y0          f64
	r0          f64
	x1          f64
	y1          f64
	r1          f64
	start_angle f64
mut:
	color_stops_record_ &CanvasGradientColorStops = unsafe { nil }
pub mut:
	color_stops []CanvasColorStop
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-createradialgradient
pub fn CanvasGradient.create_radial(x0 f64, y0 f64, r0 f64, x1 f64, y1 f64, r1 f64) !CanvasGradient {
	if r0 < 0 {
		return error('IndexSizeError: The r0 passed is less than 0')
	}
	if r1 < 0 {
		return error('IndexSizeError: The r1 passed is less than 0')
	}
	return CanvasGradient{
		color_stops_record_: &CanvasGradientColorStops{}
		kind:                .radial
		x0:                  x0
		y0:                  y0
		r0:                  r0
		x1:                  x1
		y1:                  y1
		r1:                  r1
	}
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-createlineargradient
pub fn CanvasGradient.create_linear(x0 f64, y0 f64, x1 f64, y1 f64) CanvasGradient {
	return CanvasGradient{
		color_stops_record_: &CanvasGradientColorStops{}
		kind:                .linear
		x0:                  x0
		y0:                  y0
		x1:                  x1
		y1:                  y1
	}
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-createconicgradient
pub fn CanvasGradient.create_conic(start_angle f64, x f64, y f64) CanvasGradient {
	return CanvasGradient{
		color_stops_record_: &CanvasGradientColorStops{}
		kind:                .conic
		x0:                  x
		y0:                  y
		start_angle:         start_angle
	}
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-canvasgradient-addcolorstop
pub fn (mut gradient CanvasGradient) add_color_stop(offset f64, color string) ! {
	if offset < 0 || offset > 1 {
		return error('IndexSizeError: CanvasGradient color stop offset out of bounds')
	}
	mut parser := css.Parser.with_context(css.ParsingParams{
		value_context: [css.ValueParsingContext(css.SpecialContext.canvas_context_generic_value)]
	}, color)
	parsed_value := parser.parse_css_value(.color) or {
		return error('SyntaxError: Could not parse color for CanvasGradient')
	}
	if !parsed_value.has_color() {
		return error('SyntaxError: Could not parse color for CanvasGradient')
	}
	parsed_color := parsed_value.to_color(css.ColorResolutionContext{}) or { panic('CanvasGradient color did not resolve') }
	if gradient.color_stops_record_ == unsafe { nil } {
		gradient.color_stops_record_ = &CanvasGradientColorStops{ values: gradient.color_stops.clone() }
	}
	// Gfx::GradientPaintStyle stores float positions and sorts after insertion.
	mut record := gradient.color_stops_record_
	record.values << CanvasColorStop{f64(f32(offset)), parsed_color}
	record.values.sort(a.offset < b.offset)
	gradient.color_stops = record.values.clone()
}

pub fn (gradient &CanvasGradient) to_gfx_paint_style() CanvasGfxPaintStyle {
	return CanvasGfxPaintStyle{
		kind:     .gradient
		gradient: *gradient
	}
}

pub fn (gradient &CanvasGradient) color_stops_for_painting() []CanvasColorStop {
	if gradient.color_stops_record_ != unsafe { nil } {
		return gradient.color_stops_record_.values.clone()
	}
	return gradient.color_stops.clone()
}

// GC::CanvasGradient identity survives value transport through the host bridge.
pub fn (gradient CanvasGradient) is_same_gradient(other CanvasGradient) bool {
	return gradient.color_stops_record_ != unsafe { nil }
		&& voidptr(gradient.color_stops_record_) == voidptr(other.color_stops_record_)
}

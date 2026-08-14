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
		kind: .radial
		x0:   x0
		y0:   y0
		r0:   r0
		x1:   x1
		y1:   y1
		r1:   r1
	}
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-createlineargradient
pub fn CanvasGradient.create_linear(x0 f64, y0 f64, x1 f64, y1 f64) CanvasGradient {
	return CanvasGradient{
		kind: .linear
		x0:   x0
		y0:   y0
		x1:   x1
		y1:   y1
	}
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-createconicgradient
pub fn CanvasGradient.create_conic(start_angle f64, x f64, y f64) CanvasGradient {
	return CanvasGradient{
		kind:        .conic
		x0:          x
		y0:          y
		start_angle: start_angle
	}
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-canvasgradient-addcolorstop
pub fn (mut gradient CanvasGradient) add_color_stop(offset f64, color string) ! {
	if offset < 0 || offset > 1 {
		return error('IndexSizeError: CanvasGradient color stop offset out of bounds')
	}
	parsed_color := css.parse_color_string(color) or {
		return error('SyntaxError: Could not parse color for CanvasGradient')
	}
	gradient.color_stops << CanvasColorStop{offset, parsed_color}
}

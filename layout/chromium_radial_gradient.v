module layout

import css
import math

// Keep Blink's float geometry before the ordinary normalized transport loses
// its rounding. The native painter uses it only for this same image size.
pub struct CSSRadialGradientGeometry {
pub:
	width    f32
	height   f32
	center_x f32
	center_y f32
	radius_x f32
	radius_y f32
}

fn chromium_gradient_position(value css.StyleValue, context css.LengthResolutionContext,
	basis f32) f32 {
	if value.is_percentage() {
		return f32(value.as_percentage().percentage().value() / 100) * basis
	}
	return f32(typed_gradient_length_percentage_px(value, context, f64(basis)) or { 0 })
}

fn chromium_radial_extent(extent css.RadialExtent, cx f32, cy f32, width f32,
	height f32, circle bool) (f32, f32) {
	near := extent == .closest_side || extent == .closest_corner
	x1 := f32(math.abs(cx))
	x2 := f32(math.abs(cx - width))
	y1 := f32(math.abs(cy))
	y2 := f32(math.abs(cy - height))
	dx := if near { f32(math.min(x1, x2)) } else { f32(math.max(x1, x2)) }
	dy := if near { f32(math.min(y1, y2)) } else { f32(math.max(y1, y2)) }
	if extent == .closest_side || extent == .farthest_side {
		if circle {
			r := if near { f32(math.min(dx, dy)) } else { f32(math.max(dx, dy)) }
			return r, r
		}
		return dx, dy
	}
	mut corner_x := -cx
	mut corner_y := -cy
	mut distance := corner_x * corner_x + corner_y * corner_y
	for corner in [[width, f32(0)]!, [width, height]!, [f32(0), height]!] {
		x := corner[0] - cx
		y := corner[1] - cy
		d := x * x + y * y
		if (near && d < distance) || (!near && d > distance) {
			corner_x = x
			corner_y = y
			distance = d
		}
	}
	if circle {
		r := f32(math.sqrt(f64(distance)))
		return r, r
	}
	aspect := dx / dy
	if aspect == 0 || math.is_nan(f64(aspect)) || math.is_inf(f64(aspect), 0) {
		return 0, 0
	}
	// Match EllipseRadius's left-to-right float products and final sqrtf.
	y_squared := corner_y * corner_y
	y_scaled := y_squared * aspect
	y_term := y_scaled * aspect
	x_term := corner_x * corner_x
	r_squared := x_term + y_term
	rx := f32(math.sqrt(f64(r_squared)))
	return rx, rx / aspect
}

fn chromium_resolve_radial_gradient_geometry(gradient css.RadialGradientStyleValue,
	context css.LengthResolutionContext, width f64, height f64, radius_x f64,
	radius_y f64) ?CSSRadialGradientGeometry {
	w := f32(width)
	h := f32(height)
	position := gradient.position_.with_resolved_keywords()
	cx := chromium_gradient_position(position.edge_x().offset(), context, w)
	cy := chromium_gradient_position(position.edge_y().offset(), context, h)
	mut rx := f32(radius_x)
	mut ry := f32(radius_y)
	if size := gradient.size_.value.as_radial_size() {
		components := size.components()
		if components.len > 0 {
			first := components[0]
			if first is css.RadialExtentComponent {
				rx, ry = chromium_radial_extent(first.extent, cx, cy, w, h,
					gradient.ending_shape_ == .circle)
			}
		}
	}
	if w <= 0 || h <= 0 || rx <= 0 || ry <= 0 { return none }
	for value in [w, h, cx, cy, rx, ry] {
		if math.is_nan(f64(value)) || math.is_inf(f64(value), 0) { return none }
	}
	return CSSRadialGradientGeometry{w, h, cx, cy, rx, ry}
}

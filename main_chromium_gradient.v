module main

import css
import layout
import math

// The SVG GPU shader's straight-component interpolation is also the CSS
// premultiplied result when alpha is constant or all visible RGB components
// are constant (invisible RGB is normalized below). Preserve original stops for these sRGB linear gradients rather
// than quantizing an intermediate set of samples to eight bits.
fn chromium_linear_gradient_stop_data(gradient layout.LinearGradient, opacity f64) ?[]f32 {
	if gradient.kind != 'linear' || gradient.radial { return none }
	if method := gradient.interpolation_method {
		if method is css.RectangularColorSpace {
			if method != .srgb { return none }
		} else { return none }
	}
	mut stops := gradient.stops.clone()
	if stops.len == 0 {
		for index, color in gradient.colors {
			stops << layout.GradientStop{color, if gradient.colors.len > 1 {
				f64(index) / f64(gradient.colors.len - 1)
			} else { 0.0 }}
		}
	}
	if stops.len == 0 { return none }
	first := stops[0].color
	// A fully transparent stop contributes no RGB in premultiplied CSS.
	mut visible_color := first
	for stop in stops {
		if stop.color.a != 0 { visible_color = stop.color; break }
	}
	mut same_alpha := true
	mut same_rgb := true
	mut previous := f64(0)
	for stop in stops {
		if math.is_nan(stop.offset) || math.is_inf(stop.offset, 0)
			|| stop.offset < previous || stop.offset > 1 { return none }
		previous = stop.offset
		same_alpha = same_alpha && stop.color.a == first.a
		same_rgb = same_rgb && (stop.color.a == 0 || (stop.color.r == visible_color.r
			&& stop.color.g == visible_color.g && stop.color.b == visible_color.b))
	}
	if !same_alpha && !same_rgb { return none }
	mut data := []f32{cap: stops.len * 5}
	for stop in stops {
		color := if same_rgb && stop.color.a == 0 { visible_color } else { stop.color }
		data << f32(color.r) / 255
		data << f32(color.g) / 255
		data << f32(color.b) / 255
		data << f32(clamp(f64(stop.color.a) / 255 * opacity, 0.0, 1.0))
		data << f32(stop.offset)
	}
	return data
}

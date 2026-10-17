module main

import css
import layout
import math

// The SVG GPU shader's straight-component interpolation is also the CSS
// premultiplied result when alpha is constant or all RGB components are
// constant. Preserve original stops for these sRGB linear gradients rather
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
	mut same_alpha := true
	mut same_rgb := true
	mut previous := f64(0)
	for stop in stops {
		if math.is_nan(stop.offset) || math.is_inf(stop.offset, 0)
			|| stop.offset < previous || stop.offset > 1 { return none }
		previous = stop.offset
		same_alpha = same_alpha && stop.color.a == first.a
		same_rgb = same_rgb && stop.color.r == first.r && stop.color.g == first.g
			&& stop.color.b == first.b
	}
	if !same_alpha && !same_rgb { return none }
	mut data := []f32{cap: stops.len * 5}
	for stop in stops {
		data << f32(stop.color.r) / 255
		data << f32(stop.color.g) / 255
		data << f32(stop.color.b) / 255
		data << f32(clamp(f64(stop.color.a) / 255 * opacity, 0.0, 1.0))
		data << f32(stop.offset)
	}
	return data
}

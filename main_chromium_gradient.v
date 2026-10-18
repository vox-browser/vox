module main

import css
import layout
import math
import painting

fn C.tanf(f32) f32

// Blink's EndPointsFromAngle retains float intermediates. Keep the original
// CSS angle so normalization to unit coordinates does not change their final
// rounding when the gradient is expanded to its tile.
fn chromium_linear_gradient_points(gradient layout.LinearGradient, tile painting.Rect) [4]f32 {
	if source_angle := gradient.css_angle_degrees {
		mut angle := f32(math.fmod(f64(f32(source_angle)), 360))
		if angle < 0 { angle += 360 }
		width := f32(tile.width)
		height := f32(tile.height)
		mut points := [f32(0), 0, 0, 0]!
		match angle {
			0 {
				points = [f32(0), height, 0, 0]!
			}
			90 {
				points = [f32(0), 0, width, 0]!
			}
			180 {
				points = [f32(0), 0, 0, height]!
			}
			270 {
				points = [width, f32(0), 0, 0]!
			}
			else {
				radians := (f32(90) - angle) * (f32(math.pi) / f32(180))
				slope := C.tanf(radians)
				perpendicular := f32(-1) / slope
				half_width := width / 2
				half_height := height / 2
				corner_x := if angle < 180 { half_width } else { -half_width }
				corner_y := if angle < 90 || angle >= 270 { half_height } else { -half_height }
				projected_corner := perpendicular * corner_x
				intercept := corner_y - projected_corner
				end_x := intercept / (slope - perpendicular)
				projected_end := perpendicular * end_x
				end_y := projected_end + intercept
				points = [half_width - end_x, half_height + end_y, half_width + end_x,
					half_height - end_y]!
			}
		}

		return points
	}
	return [f32(tile.x + gradient.x1 * tile.width), f32(tile.y + gradient.y1 * tile.height),
		f32(tile.x + gradient.x2 * tile.width), f32(tile.y + gradient.y2 * tile.height)]!
}

// The SVG GPU shader's straight-component interpolation is also the CSS
// premultiplied result when alpha is constant or all visible RGB components
// are constant (invisible RGB is normalized below). Preserve original stops for these sRGB linear gradients rather
// than quantizing an intermediate set of samples to eight bits.
fn chromium_linear_gradient_stop_data(gradient layout.LinearGradient, opacity f64) ?[]f32 {
	if gradient.kind != 'linear' || gradient.radial { return none }
	if method := gradient.interpolation_method {
		if method is css.RectangularColorSpace {
			if method != .srgb { return none }
		} else {
			return none
		}
	}
	mut stops := gradient.stops.clone()
	if stops.len == 0 {
		for index, color in gradient.colors {
			stops << layout.GradientStop{color, if gradient.colors.len > 1 {
				f64(index) / f64(gradient.colors.len - 1)
			} else {
				0.0
			}}
		}
	}
	if stops.len == 0 { return none }
	first := stops[0].color
	// A fully transparent stop contributes no RGB in premultiplied CSS.
	mut visible_color := first
	for stop in stops {
		if stop.color.a != 0 {
			visible_color = stop.color
			break
		}
	}
	mut same_alpha := true
	mut same_rgb := true
	mut previous := f64(0)
	for stop in stops {
		if math.is_nan(stop.offset) || math.is_inf(stop.offset, 0) || stop.offset < previous
			|| stop.offset > 1 {
			return none
		}
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

module main

import css
import layout
import math
import painting
import platform

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
// are constant (invisible RGB is normalized below). Preserve original stops for these sRGB gradients rather
// than quantizing an intermediate set of samples to eight bits.
$if test {
	fn chromium_linear_gradient_stop_data(gradient layout.LinearGradient, opacity f64) ?[]f32 {
		mut data := []f32{}
		if !chromium_linear_gradient_stop_data_into(gradient, opacity, mut data) { return none }
		return data
	}
}

fn chromium_linear_gradient_stop_data_into(gradient layout.LinearGradient, opacity f64,
	mut data []f32) bool {
	if gradient.kind != 'linear' || gradient.radial {
		data.clear()
		return false
	}
	return chromium_gradient_stop_data_into(gradient, opacity, mut data)
}

fn chromium_gradient_stop_data_into(gradient layout.LinearGradient, opacity f64,
	mut data []f32) bool {
	persistent := platform.enter_persistent_if(platform.transient_arena_entered())
	defer { platform.leave_persistent(persistent) }
	data.clear()
	analysis := chromium_gradient_stop_analysis(gradient) or { return false }
	for index in 0 .. analysis.count {
		stop := chromium_gradient_stop(gradient.stops, gradient.colors, index)
		color := if analysis.same_rgb && stop.color.a == 0 { analysis.visible_color } else { stop.color }
		data << f32(color.r) / 255
		data << f32(color.g) / 255
		data << f32(color.b) / 255
		data << f32(clamp(f64(stop.color.a) / 255 * opacity, 0.0, 1.0))
		data << f32(stop.offset)
	}
	return true
}

struct ChromiumGradientStopAnalysis {
	count         int
	same_rgb      bool
	visible_color css.Color
}

// Whether the original stops can be drawn as they are (see above), without
// building their data: the checks run several times for every gradient draw.
fn chromium_gradient_stop_analysis(gradient layout.LinearGradient) ?ChromiumGradientStopAnalysis {
	if gradient.kind != 'linear' && gradient.kind != 'radial' { return none }
	if method := gradient.interpolation_method {
		if method is css.RectangularColorSpace {
			if method != .srgb { return none }
		} else {
			return none
		}
	}
	count := if gradient.stops.len > 0 { gradient.stops.len } else { gradient.colors.len }
	if count == 0 { return none }
	first := chromium_gradient_stop(gradient.stops, gradient.colors, 0).color
	// A fully transparent stop contributes no RGB in premultiplied CSS.
	mut visible_color := first
	for index in 0 .. count {
		stop := chromium_gradient_stop(gradient.stops, gradient.colors, index)
		if stop.color.a != 0 {
			visible_color = stop.color
			break
		}
	}
	mut same_alpha := true
	mut same_rgb := true
	mut previous := f64(0)
	for index in 0 .. count {
		stop := chromium_gradient_stop(gradient.stops, gradient.colors, index)
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
	return ChromiumGradientStopAnalysis{count, same_rgb, visible_color}
}

// The stop at `index`: the gradient's own stops, or its colors spread evenly.
// Indexing rather than collecting them keeps the gradient itself off the heap.
fn chromium_gradient_stop(stops []layout.GradientStop, colors []css.Color, index int) layout.GradientStop {
	if stops.len > 0 {
		return stops[index]
	}
	return layout.GradientStop{colors[index], if colors.len > 1 {
		f64(index) / f64(colors.len - 1)
	} else {
		0.0
	}}
}

// Send the background's own clip into the same GPU draw as its gradient.
// A later CoreGraphics clip applies a different fractional corner coverage.
fn chromium_gradient_uses_gpu_clip(command layout.PaintCommand, gradient layout.LinearGradient) bool {
	return command.gradient_background_layer
		&& chromium_gradient_has_gpu_geometry(gradient)
		&& chromium_gradient_stop_analysis(gradient) != none
}

fn chromium_gradient_has_gpu_geometry(gradient layout.LinearGradient) bool {
	if gradient.kind == 'radial' || gradient.radial {
		return gradient.radius_x > 0 && gradient.radius_y > 0
	}
	return gradient.kind == 'linear' && (gradient.x1 != gradient.x2 || gradient.y1 != gradient.y2)
}

fn chromium_gradient_clip_data(command layout.PaintCommand) [12]f32 {
	// Read the payload directly: an accessor call on this by-value command
	// makes current V move the command to the heap.
	if command.image_data == unsafe { nil } {
		return [12]f32{}
	}
	image := command.image_data
	r := image.image_clip_radii
	return [f32(image.image_clip_x), f32(image.image_clip_y), f32(image.image_clip_width),
		f32(image.image_clip_height), f32(r.top_left.x), f32(r.top_left.y), f32(r.top_right.x),
		f32(r.top_right.y), f32(r.bottom_right.x), f32(r.bottom_right.y), f32(r.bottom_left.x),
		f32(r.bottom_left.y)]!
}

fn chromium_gradient_gpu_ancestor_clip_index(command &layout.PaintCommand) int {
	if command.kind != 'fill_gradient' || !command.has_clip || command.clip_list == unsafe { nil } {
		return -1
	}
	gradient := command.gradient or { return -1 }
	if !chromium_gradient_uses_gpu_clip(*command, gradient) { return -1 }
	transform := normalized_paint_transform(command.transform)
	for index := command.clip_list.items.len - 1; index >= 0; index-- {
		clip := command.clip_list.items[index]
		if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask
			|| normalized_paint_transform(clip.transform) != transform {
			continue
		}
		r := clip.corner_radii
		if r.top_left.x > 0 || r.top_left.y > 0 || r.top_right.x > 0 || r.top_right.y > 0
			|| r.bottom_right.x > 0 || r.bottom_right.y > 0 || r.bottom_left.x > 0
			|| r.bottom_left.y > 0 {
			return index
		}
	}
	return -1
}

fn chromium_paint_clip_data(clip layout.PaintClip) [12]f32 {
	r := clip.corner_radii
	return [f32(clip.rect.x), f32(clip.rect.y), f32(clip.rect.width), f32(clip.rect.height),
		f32(r.top_left.x), f32(r.top_left.y), f32(r.top_right.x), f32(r.top_right.y),
		f32(r.bottom_right.x), f32(r.bottom_right.y), f32(r.bottom_left.x), f32(r.bottom_left.y)]!
}

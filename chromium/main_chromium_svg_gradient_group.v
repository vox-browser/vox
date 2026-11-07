module main

import layout
import math
import painting

// Adjacent gradient fills must retain their multisample coverage until the
// last fill. Resolving each path separately exposes the background at seams.
// Keep effects, strokes and nonrectangular clips on the ordinary replay path.
fn chromium_svg_gradient_fill_supported(command &layout.PaintCommand) bool {
	if command.kind != 'draw_svg_path' || command.opacity != 1 || command.group_opacity != 1
		|| command.svg_data == unsafe { nil } || command.stroke_color != ''
		|| command.clip_outs.len != 0 || command.recording_clip != none {
		return false
	}
	data := command.svg_data
	if data.path_data.len < layout.compatibility_clip_path_segment_stride
		|| data.stroke_dasharray.len != 0 || data.fill_pattern != none
		|| data.stroke_pattern != none || data.svg_gradient_data == none {
		return false
	}
	if command.stroke_linear_gradient() != none || command.stroke_radial_gradient() != none {
		return false
	}
	if command.fill_linear_gradient() == none && command.fill_radial_gradient() == none {
		return false
	}
	if command.has_clip && command.clip_list != unsafe { nil } {
		for clip in command.clip_list.items {
			matrix := normalized_paint_transform(clip.transform)
			if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask
				|| clip.corner_radii != layout.BoxRadii{} || matrix[1] != 0 || matrix[2] != 0 {
				return false
			}
		}
	}
	return true
}

fn chromium_svg_gradient_run_end(commands []layout.PaintCommand, layers []int, start int) int {
	if start < 0 || start >= commands.len || layers.len != commands.len
		|| !chromium_svg_gradient_fill_supported(&commands[start]) {
		return start
	}
	first := &commands[start]
	mut end := start + 1
	for end < commands.len && end - start < 32768 {
		next := &commands[end]
		if layers[end] != layers[start] || !chromium_svg_gradient_fill_supported(next)
			|| next.has_clip != first.has_clip || next.clip_x != first.clip_x
			|| next.clip_y != first.clip_y || next.clip_width != first.clip_width
			|| next.clip_height != first.clip_height
			|| voidptr(next.clip_list) != voidptr(first.clip_list) {
			break
		}
		end++
	}
	return if end - start >= 2 { end } else { start }
}

fn chromium_svg_gradient_stops(gradient painting.SVGGradientPaintStyle) []f32 {
	if gradient.color_stops.len == 0 { return []f32{} }
	mut stops := []f32{cap: math.max(2, gradient.color_stops.len) * 5}
	for index in 0 .. math.max(2, gradient.color_stops.len) {
		stop := gradient.color_stops[math.min(index, gradient.color_stops.len - 1)]
		stops << f32(stop.color.r) / 255
		stops << f32(stop.color.g) / 255
		stops << f32(stop.color.b) / 255
		stops << f32(stop.color.a) / 255
		stops << if gradient.color_stops.len == 1 { f32(index) } else { f32(stop.position) }
	}
	return stops
}

fn (mut app BrowserApp) draw_chromium_svg_gradient_group(start int, page_y f32) int {
	$if macos {
		if !app.ctx.native_rendering || app.page_zoom != 1 || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium {
			return start
		}
		end := chromium_svg_gradient_run_end(app.paint_commands,
			app.chromium_raster_plan.command_layers, start)
		if end == start { return start }
		mut paths := []C.VoxGraphitePath{cap: end - start}
		// Retain every stop allocation through the synchronous native batch call.
		mut stop_storage := [][]f32{cap: end - start}
		mut left := math.inf(1)
		mut top := math.inf(1)
		mut right := math.inf(-1)
		mut bottom := math.inf(-1)
		for index in start .. end {
			command := &app.paint_commands[index]
			data := command.svg_data
			bounds := chromium_msaa_trigger_rect(*command) or { return start }
			left = math.min(left, bounds.x)
			top = math.min(top, bounds.y)
			right = math.max(right, bounds.x + bounds.width)
			bottom = math.max(bottom, bounds.y + bounds.height)
			mut kind := 1
			mut points := [6]f32{}
			mut gradient := painting.SVGGradientPaintStyle{}
			if linear := command.fill_linear_gradient() {
				gradient = linear.gradient
				points = [f32(linear.start_point.x), f32(linear.start_point.y),
					f32(linear.end_point.x), f32(linear.end_point.y), f32(0), f32(0)]!
			} else if radial := command.fill_radial_gradient() {
				kind = 2
				gradient = radial.gradient
				points = [f32(radial.start_center.x), f32(radial.start_center.y),
					f32(radial.start_radius), f32(radial.end_center.x), f32(radial.end_center.y),
					f32(radial.end_radius)]!
			}
			if gradient.color_stops.len == 0 { return start }
			stop_storage << chromium_svg_gradient_stops(gradient)
			stops := stop_storage.last()
			matrix := multiply_paint_transforms(command.transform, data.path_transform)
			local := gradient.gradient_transform or { painting.Affine{} }
			// SVG spread enumeration is pad/repeat/reflect; Skia is clamp/repeat/mirror.
			paths << C.VoxGraphitePath{
				matrix:             [f32(matrix[0]), f32(matrix[2]), f32(matrix[4]), f32(matrix[1]),
					f32(matrix[3]), f32(matrix[5]), f32(0), f32(0), f32(1)]!
				segments:           data.path_data.data
				segment_count:      data.path_data.len / layout.compatibility_clip_path_segment_stride
				even_odd:           int(data.fill_even_odd)
				gradient:           kind
				tile_mode:          int(gradient.spread_method)
				linear_color_space: int(gradient.color_space == .linear_srgb)
				stop_count:         stops.len / 5
				gradient_points:    points
				gradient_matrix:    [f32(local.a), f32(local.c), f32(local.e), f32(local.b),
					f32(local.d), f32(local.f), f32(0), f32(0), f32(1)]!
				opacity:            f32(data.fill_opacity)
				stops:              stops.data
			}
		}
		first := &app.paint_commands[start]
		if first.has_clip {
			left = math.max(left, first.clip_x)
			top = math.max(top, first.clip_y)
			right = math.min(right, first.clip_x + first.clip_width)
			bottom = math.min(bottom, first.clip_y + first.clip_height)
		}
		if right <= left || bottom <= top { return end }
		app.flush_rounded_rect_underlay(0, page_y, int(app.ctx.height))
		identity := [f32(1), 0, 0, 1, 0, 0]!
		if C.native_draw_svg_path_batch(paths.data, paths.len, &identity[0], f32(left),
			f32(top), f32(right - left), f32(bottom - top), 0, page_y, 0,
			f32(app.ctx.width), f32(app.ctx.height), unsafe { nil }) != 0 {
			return end
		}
	}
	return start
}

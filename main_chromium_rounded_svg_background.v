module main

import layout
import math
import painting

fn C.native_draw_svg_path_batch_with_rounded_ancestor(&C.VoxGraphitePath, int, &f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, &f32) int

fn svg_background_positive_axis_matrix(value [6]f64) ?[6]f64 {
	matrix := normalized_paint_transform(value)
	if matrix[0] <= 0 || matrix[3] <= 0 || matrix[1] != 0 || matrix[2] != 0 { return none }
	return matrix
}

// Accept a single closed rectangle, not just the bounding box of an arbitrary
// clip path. SVG clipPath components are a union, so multiple components keep
// the ordinary mask replay even if their combined bounds are rectangular.
fn svg_background_rectangle_path(data []f32) ?painting.Rect {
	stride := layout.compatibility_clip_path_segment_stride
	if data.len != stride * 5 && data.len != stride * 6 { return none }
	if data[0] != 0 || data[data.len - stride] != 5 { return none }
	mut points := []painting.Point{cap: 5}
	for offset := 0; offset < data.len - stride; offset += stride {
		if offset > 0 && data[offset] != 1 { return none }
		points << painting.Point{f64(data[offset + 1]), f64(data[offset + 2])}
	}
	if points.len == 5 {
		if points[4] != points[0] { return none }
		points.delete_last()
	}
	mut left := points[0].x
	mut top := points[0].y
	mut right := left
	mut bottom := top
	for point in points {
		left = math.min(left, point.x)
		top = math.min(top, point.y)
		right = math.max(right, point.x)
		bottom = math.max(bottom, point.y)
	}
	if right <= left || bottom <= top { return none }
	for i, point in points {
		next := points[(i + 1) % 4]
		if (point.x != left && point.x != right) || (point.y != top && point.y != bottom)
			|| (point.x == next.x) == (point.y == next.y) {
			return none
		}
	}
	// Opposite corners must differ in both axes; this excludes retraced edges.
	if points[0].x == points[2].x || points[0].y == points[2].y
		|| points[1].x == points[3].x || points[1].y == points[3].y {
		return none
	}
	return painting.Rect{left, top, right - left, bottom - top}
}

fn svg_background_map_rect(rect painting.Rect, matrix [6]f64) painting.Rect {
	return painting.Rect{rect.x * matrix[0] + matrix[4], rect.y * matrix[3] + matrix[5], rect.width * matrix[0], rect.height * matrix[3]}
}

fn svg_background_rectangular_clip(clip layout.PaintClip) ?painting.Rect {
	if clip.is_svg_content_mask { return none }
	if clip.is_svg_mask {
		if clip.path_components.len != 1 { return none }
		part := clip.path_components[0]
		matrix := svg_background_positive_axis_matrix(part.transform)?
		return svg_background_map_rect(svg_background_rectangle_path(part.path_data)?, matrix)
	}
	if clip.path_components.len != 0 || clip.corner_radii != layout.BoxRadii{} { return none }
	matrix := svg_background_positive_axis_matrix(clip.transform)?
	rect := if clip.is_path {
		svg_background_rectangle_path(clip.path_data)?
	} else {
		painting.Rect{clip.rect.x, clip.rect.y, clip.rect.width, clip.rect.height}
	}
	return svg_background_map_rect(rect, matrix)
}

fn svg_background_rect_contains(outer painting.Rect, inner painting.Rect) bool {
	return outer.x <= inner.x && outer.y <= inner.y && outer.right() >= inner.right()
		&& outer.bottom() >= inner.bottom()
}

// All outer clips must either contain the complete image or duplicate its
// rounded boundary. Only then can that boundary be applied once inside Skia.
fn chromium_svg_background_outer_clip(command &layout.PaintCommand) ?[12]f32 {
	if command.kind != 'draw_background_image' || command.opacity != 1
		|| command.clip_outs.len != 0 || command.recording_clip != none
		|| command.image_data == unsafe { nil } {
		return none
	}
	matrix := svg_background_positive_axis_matrix(command.transform)?
	image := command.image_data
	if image.background_blend_mode != .normal || image.image_attachment == 'fixed' { return none }
	rect := painting.Rect{image.image_clip_x, image.image_clip_y, image.image_clip_width, image.image_clip_height}
	if rect.width <= 0 || rect.height <= 0 || image.image_clip_radii == layout.BoxRadii{} {
		return none
	}
	if command.has_clip {
		if command.clip_list != unsafe { nil } && command.clip_list.items.len > 0 {
			for clip in command.clip_list.items {
				if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask
					|| normalized_paint_transform(clip.transform) != matrix {
					return none
				}
				clip_rect := painting.Rect{clip.rect.x, clip.rect.y, clip.rect.width, clip.rect.height}
				if clip.corner_radii == layout.BoxRadii{} {
					if !svg_background_rect_contains(clip_rect, rect) { return none }
				} else if clip_rect != rect || clip.corner_radii != image.image_clip_radii {
					return none
				}
			}
		} else if !svg_background_rect_contains(painting.Rect{command.clip_x, command.clip_y, command.clip_width, command.clip_height}, svg_background_map_rect(rect, matrix)) {
			return none
		}
	}
	r := image.image_clip_radii
	return [f32(rect.x), f32(rect.y), f32(rect.width), f32(rect.height), f32(r.top_left.x),
		f32(r.top_left.y), f32(r.top_right.x), f32(r.top_right.y), f32(r.bottom_right.x),
		f32(r.bottom_right.y), f32(r.bottom_left.x), f32(r.bottom_left.y)]!
}

// Called only after validating the complete outer clip list above. Coincident
// rounded overflow clips share one coverage stage until a mask isolates them
// from the child's own rounded background clip.
fn chromium_svg_background_has_rounded_ancestor(command &layout.PaintCommand) bool {
	if !command.has_clip || command.clip_list == unsafe { nil } { return false }
	return command.clip_list.items.any(it.corner_radii != layout.BoxRadii{})
}

fn svg_background_local_clip(rect painting.Rect, matrix [6]f64) [12]f32 {
	// Invert before converting to Skia's floats so the page origin cannot
	// perturb an otherwise coincident path and rectangular clip edge.
	return [f32((rect.x - matrix[4]) / matrix[0]),
		f32((rect.y - matrix[5]) / matrix[3]), f32(rect.width / matrix[0]),
		f32(rect.height / matrix[3]), 0, 0, 0, 0, 0, 0, 0, 0]!
}

fn chromium_svg_background_path_clips(command &layout.PaintCommand,
	masks []painting.Rect) ?C.VoxGraphitePath {
	if command.kind != 'draw_svg_path' || command.opacity != 1 || command.group_opacity != 1
		|| command.color == '' || (command.stroke_color != '' && command.stroke_width > 0)
		|| command.clip_outs.len > 0 || command.recording_clip != none
		|| command.svg_data == unsafe { nil } {
		return none
	}
	svg := command.svg_data
	if svg.path_data.len == 0 || svg.svg_gradient_data != none || svg.fill_pattern != none
		|| svg.stroke_pattern != none || svg.stroke_dasharray.len > 0 {
		return none
	}
	matrix := svg_background_positive_axis_matrix(multiply_paint_transforms(command.transform, svg.path_transform))?
	mut inner := ?painting.Rect(none)
	// Display-list lowering removes SVG masks from each path's clip list and
	// emits balanced layer commands instead. Retain those active clips here.
	for rect in masks {
		inner = if previous := inner { previous.intersection(rect) } else { rect }
	}
	if command.has_clip {
		if command.clip_list != unsafe { nil } && command.clip_list.items.len > 0 {
			for clip in command.clip_list.items {
				rect := svg_background_rectangular_clip(clip)?
				inner = if previous := inner { previous.intersection(rect) } else { rect }
			}
		} else {
			rect := painting.Rect{command.clip_x, command.clip_y, command.clip_width, command.clip_height}
			inner = if previous := inner { previous.intersection(rect) } else { rect }
		}
	}
	mut descriptor := C.VoxGraphitePath{
		matrix:            [f32(matrix[0]), 0, f32(matrix[4]), 0, f32(matrix[3]), f32(matrix[5]),
			0, 0, 1]!
		segments:          svg.path_data.data
		segment_count:     svg.path_data.len / layout.compatibility_clip_path_segment_stride
		even_odd:          int(svg.fill_even_odd)
	}
	if rect := inner {
		descriptor.has_clip = 1
		descriptor.clip = svg_background_local_clip(rect, matrix)
	}
	return descriptor
}

fn (mut app BrowserApp) draw_chromium_rounded_svg_background(command &layout.PaintCommand,
	page_x f32, page_y f32) bool {
	$if macos {
		if !app.ctx.native_rendering || app.page_zoom != 1
			|| !rounded_svg_background_effects_supported(app.paint_effect_depth, app.paint_svg_mask_depth)
			|| app.document == unsafe { nil } || app.document.font_rendering_policy() != .chromium {
			return false
		}
		mut outer := chromium_svg_background_outer_clip(command) or { return false }
		image := command.image_data
		natural := svg_background_natural_metrics(image) or { return false }
		background := image.background_layer_data or { return false }
		area := painting.Rect{command.x, command.y, command.width, command.height}
		layer := background.resolve_image(image.image_url, area, natural) or { return false }
		bounds := painting.Rect{image.image_clip_x, image.image_clip_y, image.image_clip_width, image.image_clip_height}
		plan := painting.background_tile_plan(layer,
			painting.Point{command.image_scroll_offset_x, command.image_scroll_offset_y}, bounds)
		if plan.repeat_x || plan.repeat_y { return false }
		replay := chromium_svg_background_replay(plan.first_tile, normalized_paint_transform(command.transform))
		origin_x := math.floor(plan.first_tile.x + .5)
		origin_y := math.floor(plan.first_tile.y + .5)
		if !svg_background_rect_contains(painting.Rect{origin_x, origin_y, f64(replay.viewport_width), f64(replay.viewport_height)}, bounds) {
			return false
		}
		outer[0] -= f32(origin_x)
		outer[1] -= f32(origin_y)
		commands := svg_background_paint_commands(image, replay.viewport_width, replay.viewport_height) or { return false }
		if commands.len == 0 || commands.len > 32768 { return false }
		mut paths := []C.VoxGraphitePath{cap: commands.len + 1}
		// Compose the backing color and SVG before applying their rounded boundary.
		// Per-path antialiasing would blend the backing color into the image edge.
		mut color_rect := []f32{len: 5 * layout.compatibility_clip_path_segment_stride}
		if underlay := app.rounded_rect_underlay {
			if underlay.transform != command.transform || underlay.opacity != 1
				|| underlay.x != bounds.x || underlay.y != bounds.y
				|| underlay.width != bounds.width || underlay.height != bounds.height {
				return false
			}
			stride := layout.compatibility_clip_path_segment_stride
			for i, point in [painting.Point{0, 0}, painting.Point{f64(replay.viewport_width), 0},
				painting.Point{f64(replay.viewport_width), f64(replay.viewport_height)},
				painting.Point{0, f64(replay.viewport_height)}] {
				color_rect[i * stride] = if i == 0 { f32(0) } else { f32(1) }
				color_rect[i * stride + 1] = f32(point.x)
				color_rect[i * stride + 2] = f32(point.y)
			}
			color_rect[4 * stride] = 5
			color := app.paint_colors.color(underlay.color, 1)
			paths << C.VoxGraphitePath{
				matrix:            [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
				segments:          color_rect.data
				segment_count:     5
				red:               color.r
				green:             color.g
				blue:              color.b
				alpha:             color.a
			}
		}
		mut masks := []painting.Rect{}
		for nested in commands {
			if nested.kind == 'begin_svg_mask_layer' {
				masks << svg_background_rectangular_clip(nested.mask_clip()) or { return false }
				continue
			}
			if nested.kind == 'end_svg_mask_layer' {
				if masks.len == 0 { return false }
				masks.delete_last()
				continue
			}
			mut path := chromium_svg_background_path_clips(&nested, masks) or { return false }
			color := app.paint_colors.color_with_retained(nested.color, 1, nested.retained_svg_fill_color())
			path.red = color.r
			path.green = color.g
			path.blue = color.b
			path.alpha = color.a
			path.has_float_alpha = 1
			path.opacity = f32(f64(color.a) / 255 * nested.svg_data.fill_opacity)
			paths << path
		}
		if masks.len != 0 { return false }
		m := replay.transform
		matrix := [f32(m[0]), f32(m[1]), f32(m[2]), f32(m[3]), f32(m[4]), f32(m[5])]!
		independent_ancestor := app.paint_svg_mask_depth == 1
			&& chromium_svg_background_has_rounded_ancestor(command)
		success := if independent_ancestor {
			C.native_draw_svg_path_batch_with_rounded_ancestor(paths.data, paths.len, &matrix[0], 0, 0,
				f32(replay.viewport_width), f32(replay.viewport_height), page_x, page_y, 0,
				f32(app.ctx.width), f32(app.ctx.height), &outer[0])
		} else {
			C.native_draw_svg_path_batch(paths.data, paths.len, &matrix[0], 0, 0,
			f32(replay.viewport_width), f32(replay.viewport_height), page_x, page_y, 0,
			f32(app.ctx.width), f32(app.ctx.height), &outer[0])
		}
		if success == 0 {
			return false
		}
		app.rounded_rect_underlay = none
		app.rounded_rect_underlay_source = none
		return true
	}
	return false
}

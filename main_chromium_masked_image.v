module main

import layout
import math
import painting
import gg

fn C.native_draw_rounded_masked_image(&gg.Image, &f32, &f32, &f32, f32, f32, f32, f32, gg.Color, int) int

fn chromium_image_mask_gradient_is_opaque(gradient painting.SVGGradientPaintStyle) bool {
	if gradient.repeat_length != none || gradient.color_stops.len < 2
		|| !gradient.color_stops.all(it.color.a == 255 && math.is_finite(it.position)) { return false }
	if matrix := gradient.gradient_transform {
		for value in [matrix.a, matrix.b, matrix.c, matrix.d, matrix.e, matrix.f] {
			if !math.is_finite(value) { return false }
		}
		if matrix.a * matrix.d - matrix.b * matrix.c == 0 { return false }
	}
	return true
}

fn chromium_image_mask_is_opaque(clip layout.PaintClip) bool {
	if !clip.is_svg_content_mask || clip.mask_luminance || clip.mask_operations.len != 1 {
		return false
	}
	op := clip.mask_operations[0]
	if op.kind != .path || !op.has_fill || op.has_stroke || op.fill_opacity != 1
		|| op.opacity != 1 || op.fill_pattern != none
		|| normalized_paint_transform(op.transform) != [f64(1), 0, 0, 1, 0, 0]! {
		return false
	}
	rect := svg_background_rectangle_path(op.path_data) or { return false }
	if rect != painting.Rect{clip.rect.x, clip.rect.y, clip.rect.width, clip.rect.height} {
		return false
	}
	if gradient := op.fill_linear_gradient {
		for value in [gradient.start_point.x, gradient.start_point.y, gradient.end_point.x, gradient.end_point.y] {
			if !math.is_finite(value) { return false }
		}
		return gradient.start_point != gradient.end_point
			&& chromium_image_mask_gradient_is_opaque(gradient.gradient)
	}
	if gradient := op.fill_radial_gradient {
		if !math.is_finite(gradient.end_center.x) || !math.is_finite(gradient.end_center.y) { return false }
		return gradient.start_radius == 0 && gradient.end_radius > 0
			&& math.is_finite(gradient.end_radius)
			&& gradient.start_center == gradient.end_center
			&& chromium_image_mask_gradient_is_opaque(gradient.gradient)
	}
	return false
}

// Only remove clips whose geometry is proved redundant with the GPU content
// clip, or with the independent mask supplied by this complete scope.
fn chromium_masked_image_clips_match(command &layout.PaintCommand, mask layout.PaintClip) bool {
	if !command.has_clip { return true }
	if command.clip_list == unsafe { nil } || command.clip_list.items.len == 0 { return false }
	for clip in command.clip_list.items {
		if normalized_paint_transform(clip.transform) != [f64(1), 0, 0, 1, 0, 0]! {
			return false
		}
		if clip.is_svg_content_mask {
			if clip.cache_key != mask.cache_key || clip.scope_id != mask.scope_id { return false }
			continue
		}
		if clip.is_path || clip.is_svg_mask { return false }
		if clip.corner_radii != layout.BoxRadii{} {
			if clip.rect != mask.rect || clip.corner_radii != mask.corner_radii { return false }
		} else if clip.rect.x > mask.rect.x || clip.rect.y > mask.rect.y
			|| clip.rect.x + clip.rect.width < mask.rect.x + mask.rect.width
			|| clip.rect.y + clip.rect.height < mask.rect.y + mask.rect.height {
			return false
		}
	}
	return true
}

fn chromium_masked_image_end(commands []layout.PaintCommand, layers []int, start int) int {
	if start < 0 || start + 3 >= commands.len
		|| (layers.len != 0 && layers.len != commands.len) { return start }
	if commands[start].kind != 'begin_svg_mask_layer'
		|| commands[start + 1].kind !in ['fill_rect', 'fill_rounded_rect']
		|| commands[start + 2].kind != 'draw_replaced_image'
		|| commands[start + 3].kind != 'end_svg_mask_layer' { return start }
	mask := commands[start].mask_clip()
	end_mask := commands[start + 3].mask_clip()
	if !chromium_image_mask_is_opaque(mask) || mask.corner_radii == layout.BoxRadii{}
		|| mask != end_mask || normalized_paint_transform(mask.transform) != [f64(1), 0, 0, 1, 0, 0]! {
		return start
	}
	r := mask.rect
	for value in [r.x, r.y, r.width, r.height] {
		if !math.is_finite(value) { return start }
	}
	if r.width <= 0 || r.height <= 0 { return start }
	for i in start .. start + 4 {
		command := unsafe { &commands[i] }
		if (layers.len != 0 && layers[i] != layers[start]) || command.opacity != 1
			|| command.group_opacity != 1 || command.blur != 0 || command.outer_shadow
			|| command.clip_outs.len != 0 || command.recording_clip != none
			|| normalized_paint_transform(command.transform) != [f64(1), 0, 0, 1, 0, 0]!
			|| !chromium_masked_image_clips_match(command, mask) { return start }
		if command.local_border_data != unsafe { nil }
			&& command.local_border_data.corner_shapes != [f64(1), 1, 1, 1]! { return start }
	}
	background := commands[start + 1]
	image := commands[start + 2]
	if [background.x, background.y, background.width, background.height] != [r.x, r.y, r.width, r.height]
		|| [image.x, image.y, image.width, image.height] != [r.x, r.y, r.width, r.height] { return start }
	paintable := image.image_paintable or { return start }
	for i, corner in [mask.corner_radii.top_left, mask.corner_radii.top_right,
		mask.corner_radii.bottom_right, mask.corner_radii.bottom_left] {
		if !math.is_finite(corner.x) || !math.is_finite(corner.y) || corner.x < 0 || corner.y < 0 {
			return start
		}
		// ImagePaintable resolves its corner radii to integer device pixels.
		// Do not replace a fractional CSS mask by that quantized content clip.
		if corner.x != math.floor(corner.x) || corner.y != math.floor(corner.y) { return start }
		own := [paintable.border_radii.top_left, paintable.border_radii.top_right,
			paintable.border_radii.bottom_right, paintable.border_radii.bottom_left][i]
		if own.horizontal != corner.x || own.vertical != corner.y { return start }
		if background.kind == 'fill_rect' {
			if background.radius != corner.x || background.radius != corner.y { return start }
		} else if background.corner_radii != mask.corner_radii { return start }
	}
	return start + 4
}

fn (mut app BrowserApp) draw_chromium_masked_image(start int, page_x f32, page_y f32) int {
	$if macos {
		if !app.ctx.native_rendering || app.page_zoom != 1 || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium { return start }
		end := chromium_masked_image_end(app.paint_commands, app.chromium_raster_plan.command_layers, start)
		if end == start { return start }
		command := unsafe { &app.paint_commands[start + 2] }
		image_data := command.image()
		mut image := &gg.Image{}
		bitmap := replaced_image_bitmap_for_renderer(command, true)
		if decoded := bitmap {
			if decoded.width <= 0 || decoded.height <= 0 || decoded.pitch != decoded.width * 4
				|| decoded.data.len < decoded.pitch * decoded.height { return start }
			image = &gg.Image{width: decoded.width, height: decoded.height,
				nr_channels: native_bitmap_channel_marker(decoded, false), ok: true, data: decoded.data.data}
		} else {
			image = app.background_image(image_data.image_url) or { return start }
		}
		paintable := command.image_paintable or { return start }
		converter := painting.new_device_pixel_converter(1) or { return start }
		result := paintable.paint(image_data.image_url, painting.IntRect{0, 0, image.width, image.height}, converter) or { return start }
		clip := result.bitmap.clip_rect
		mask := app.paint_commands[start].mask_clip()
		if [f64(clip.x), clip.y, clip.width, clip.height] !=
			[mask.rect.x, mask.rect.y, mask.rect.width, mask.rect.height] { return start }
		replay := replaced_image_replay_rects(result.bitmap.destination, clip, image.width, image.height, true) or { return start }
		if paint_command_image_allows_force_dark(*command, f64(result.bitmap.destination.width),
			f64(result.bitmap.destination.height), image) { return start }
		d := replay.destination
		s := replay.source
		rects := [f32(d.x), f32(d.y), f32(d.width), f32(d.height), s[0], s[1], s[2], s[3]]!
		clipping := replaced_image_gpu_clip_data(command, clip, result.clip_radii, -1)
		matrix := [f32(1), 0, 0, 1, 0, 0]!
		background := app.paint_commands[start + 1]
		app.flush_rounded_rect_underlay(page_x, page_y, int(app.ctx.height))
		app.set_chromium_image_resource_identity(image_data.image_url)
		drawn := C.native_draw_rounded_masked_image(image, &rects[0], &clipping[0], &matrix[0],
			page_x, page_y, f32(app.ctx.width), f32(app.ctx.height),
			app.paint_colors.color(background.color, background.opacity), int(result.bitmap.scaling == .nearest_neighbor))
		app.set_chromium_image_resource_identity('')
		if drawn != 0 { return end }
	}
	return start
}

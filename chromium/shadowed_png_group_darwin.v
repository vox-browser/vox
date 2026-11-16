module main

import gg
import layout
import math
import os
import painting

const scaled_png_shadow_group_diagnostic = os.getenv('VOX_DIAGNOSTIC_SCALED_PNG_SHADOW_GROUP') == '1'

fn C.native_draw_shadowed_png(&u8, i32, i32, i32, i32, i32, f32, f32, f32, f32, &f32, f32, f32, f32, f32, f32, &C.VoxGraphiteShape) i32

fn shadowed_png_group_eligible(commands []layout.PaintCommand, layers []int, index int) bool {
	return shadowed_png_group_eligible_with_scale(commands, layers, index, scaled_png_shadow_group_diagnostic)
}

fn shadowed_png_group_eligible_with_scale(commands []layout.PaintCommand, layers []int, index int,
	allow_scaled bool) bool {
	if index < 0 || index + 1 >= commands.len || layers.len != commands.len { return false }
	s := &commands[index]
	image := &commands[index + 1]
	if s.kind != 'paint_outer_box_shadow' || s.blur != 0 || s.box_shadow_data == unsafe { nil }
		|| image.kind != 'draw_replaced_image' || image.image_data == unsafe { nil }
		|| layers[index] != 0 || layers[index + 1] != 0 || !s.shares_paint_box_with(image) {
		return false
	}
	matrix := normalized_paint_transform(s.transform)
	if matrix.any(!math.is_finite(it)) || (matrix != [f64(1), 0, 0, 1, 0, 0]!
		&& (!allow_scaled || matrix[0] <= 0 || matrix[0] != matrix[3]
			|| matrix[1] != 0 || matrix[2] != 0)) { return false }
	for c in [s, image] {
		if c.opacity != 1 || c.group_opacity != 1 || chromium_contoured_box_supported(c) || c.outer_shadow || c.has_clip || c.clip_list != unsafe { nil }
			|| c.recording_clip != none || c.clip_outs.len != 0 || c.apply_force_dark_to_image
			|| normalized_paint_transform(c.transform) != matrix {
			return false
		}
	}
	return true
}

fn transformed_png_shadow_rect(rect [12]f32, matrix [6]f64) [12]f32 {
	mut result := rect
	result[0] = f32(f64(rect[0]) * matrix[0] + matrix[4])
	result[1] = f32(f64(rect[1]) * matrix[3] + matrix[5])
	for i in 2 .. 12 { result[i] = f32(f64(rect[i]) * matrix[0]) }
	return result
}

fn (mut app BrowserApp) draw_shadowed_png_group(index int, page_y f32, window_height int) int {
	if !shadowed_png_group_eligible(app.paint_commands, app.chromium_raster_plan.command_layers, index) {
		return index
	}
	command := &app.paint_commands[index + 1]
	matrix := normalized_paint_transform(command.transform)
	if matrix != [f64(1), 0, 0, 1, 0, 0]! && app.scroll_y != 0 { return index }
	data := command.image()
	mut image := &gg.Image{}
	if bitmap := replaced_image_pixels_for_renderer(command, true) {
		if bitmap.width <= 0 || bitmap.height <= 0 || bitmap.pitch != bitmap.width * 4 || bitmap.data.len < bitmap.pitch * bitmap.height {
			return index
		}
		image = &gg.Image{ width: bitmap.width, height: bitmap.height, nr_channels: native_bitmap_channel_marker(bitmap, false), ok: true, data: bitmap.data.data }
	} else {
		image = app.background_image(data.image_url) or { return index }
	}
	paintable := command.image_paintable or { return index }
	converter := painting.new_device_pixel_converter(1) or { return index }
	result := paintable.paint(data.image_url, painting.IntRect{0, 0, image.width, image.height}, converter) or { return index }
	if result.bitmap.scaling == .nearest_neighbor { return index }
	destination := result.bitmap.destination
	clip := result.bitmap.clip_rect
	replay := replaced_image_replay_rects(destination, clip, image.width, image.height, true) or { return index }
	if replay.source != [f32(0), 0, f32(image.width), f32(image.height)]! {
		return index
	}
	shadow := &app.paint_commands[index]
	b := shadow.box_shadow()
	clipping := replaced_image_gpu_clip_data(command, clip, result.clip_radii, -1)
	geometry := sampled_png_paint_geometry(destination, clipping, matrix) or { return index }
	content := transformed_png_shadow_rect(document_shadow_rect(b.content_rect.x, b.content_rect.y,
		b.content_rect.width, b.content_rect.height, b.content_radii), matrix)
	if content != geometry.clip {
		return index
	}
	mut decode_extent := [f64(geometry.width), f64(geometry.height)]!
	$if vox_diagnostic_png_render_density ? {
		if os.getenv('VOX_DIAGNOSTIC_PNG_RENDER_DENSITY') == '1' {
			decode_extent = sampled_png_decode_extent(decode_extent,
				app.document.rendering_device_pixel_ratio(), app.document.display_device_pixel_ratio()) or { return index }
		}
	}
	upload := app.sampled_png_decode(data.image_url, image, decode_extent[0], decode_extent[1]) or { return index }
	fill := app.paint_colors.color(shadow.color, 1)
	color := chromium_retained_paint_color(*shadow) or {
		[f32(fill.r) / 255, f32(fill.g) / 255, f32(fill.b) / 255, f32(fill.a) / 255]!
	}
	shape := C.VoxGraphiteShape{
		rect:            transformed_png_shadow_rect(document_shadow_rect(shadow.x, shadow.y, shadow.width, shadow.height, shadow.corner_radii), matrix)
		underlay_rect:   geometry.clip
		fill:            9
		anti_alias:      1
		has_float_color: 1
		float_color:     color
	}
	app.flush_rounded_rect_underlay(0, page_y, window_height)
	decoded := upload.image
	previous_color_scope := select_document_png_color_space()
	defer { document_png_p3_scope = previous_color_scope }
	if matrix != [f64(1), 0, 0, 1, 0, 0]! && document_png_space_is_p3() == 0 { return index }
	drawn := C.native_draw_shadowed_png(decoded.data, i32(decoded.width), i32(decoded.height), i32(image.width), i32(image.height), i32(upload.gpu_mips), geometry.x, geometry.y, geometry.width, geometry.height, &geometry.clip[0], 0, page_y, 0, f32(app.ctx.width), f32(app.ctx.height), &shape)
	if drawn != 0 && scaled_png_shadow_group_diagnostic {
		eprintln('VOX_SCALED_PNG_SHADOW_GROUP scale=${matrix[0]} source=${image.width}x${image.height} decode=${decoded.width}x${decoded.height} p3=${document_png_space_is_p3()}')
	}
	return if drawn != 0 { index + 2 } else { index }
}

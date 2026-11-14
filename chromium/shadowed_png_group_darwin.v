module main

import gg
import layout
import painting

fn C.native_draw_shadowed_png(&u8, i32, i32, i32, i32, i32, f32, f32, f32, f32, &f32, f32, f32, f32, f32, f32, &C.VoxGraphiteShape) i32

fn shadowed_png_group_eligible(commands []layout.PaintCommand, layers []int, index int) bool {
	if index < 0 || index + 1 >= commands.len || layers.len != commands.len { return false }
	s := &commands[index]
	image := &commands[index + 1]
	if s.kind != 'paint_outer_box_shadow' || s.blur != 0 || s.box_shadow_data == unsafe { nil }
		|| image.kind != 'draw_replaced_image' || image.image_data == unsafe { nil }
		|| layers[index] != 0 || layers[index + 1] != 0 || !s.shares_paint_box_with(image) {
		return false
	}
	for c in [s, image] {
		if c.opacity != 1 || c.group_opacity != 1 || chromium_contoured_box_supported(c) || c.outer_shadow || c.has_clip || c.clip_list != unsafe { nil }
			|| c.recording_clip != none || c.clip_outs.len != 0 || c.apply_force_dark_to_image
			|| normalized_paint_transform(c.transform) != [f64(1), 0, 0, 1, 0, 0]! {
			return false
		}
	}
	return true
}

fn (mut app BrowserApp) draw_shadowed_png_group(index int, page_y f32, window_height int) int {
	if !shadowed_png_group_eligible(app.paint_commands, app.chromium_raster_plan.command_layers, index) {
		return index
	}
	command := &app.paint_commands[index + 1]
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
	upload := app.sampled_png_decode(data.image_url, image, f64(destination.width), f64(destination.height)) or { return index }
	shadow := &app.paint_commands[index]
	b := shadow.box_shadow()
	clipping := replaced_image_gpu_clip_data(command, clip, result.clip_radii, -1)
	if document_shadow_rect(b.content_rect.x, b.content_rect.y, b.content_rect.width, b.content_rect.height, b.content_radii) != clipping {
		return index
	}
	fill := app.paint_colors.color(shadow.color, 1)
	color := chromium_retained_paint_color(*shadow) or {
		[f32(fill.r) / 255, f32(fill.g) / 255, f32(fill.b) / 255, f32(fill.a) / 255]!
	}
	shape := C.VoxGraphiteShape{
		rect:            document_shadow_rect(shadow.x, shadow.y, shadow.width, shadow.height, shadow.corner_radii)
		underlay_rect:   clipping
		fill:            9
		anti_alias:      1
		has_float_color: 1
		float_color:     color
	}
	app.flush_rounded_rect_underlay(0, page_y, window_height)
	decoded := upload.image
	drawn := C.native_draw_shadowed_png(decoded.data, i32(decoded.width), i32(decoded.height), i32(image.width), i32(image.height), i32(upload.gpu_mips), f32(destination.x), f32(destination.y), f32(destination.width), f32(destination.height), &clipping[0], 0, page_y, 0, f32(app.ctx.width), f32(app.ctx.height), &shape)
	return if drawn != 0 { index + 2 } else { index }
}

module main

import css
import gg
import layout
import math
import painting

// An opaque background and its rounded image share multisample coverage in
// Chromium. Resolving the background first changes the image's edge colors.
fn chromium_rounded_image_pair_end(commands []layout.PaintCommand, layers []int, start int) int {
	if start < 0 || start + 1 >= commands.len || layers.len != commands.len { return start }
	background := unsafe { &commands[start] }
	image := unsafe { &commands[start + 1] }
	if background.kind !in ['fill_rect', 'fill_rounded_rect'] || background.underlays_next
		|| image.kind != 'draw_replaced_image' || image.apply_force_dark_to_image {
		return start
	}
	color := css.parse_color_string(background.color) or { return start }
	if color.a != 255 || (background.srgb_color_data != unsafe { nil }
		&& background.srgb_color_data.components[3] != 1) {
		return start
	}
	if retained := chromium_retained_paint_color(*background) {
		// The existing image-background API transports byte colors. Retain
		// ordinary float-color replay when that would discard color precision.
		if retained != [f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255, f32(1)]! {
			return start
		}
	}
	for i in start .. start + 2 {
		command := unsafe { &commands[i] }
		if layers[i] != 0 || command.fixed_to_viewport || command.opacity != 1
			|| command.group_opacity != 1 || command.blur != 0 || command.outer_shadow
			|| command.visual_layer_data != none || command.recording_clip != none
			|| command.clip_outs.len != 0 || command.scrollbar_axis != ''
			|| normalized_paint_transform(command.transform) != [f64(1), 0, 0, 1, 0, 0]! {
			return start
		}
		for value in [command.x, command.y, command.width, command.height] {
			if !math.is_finite(value) { return start }
		}
		if command.width <= 0 || command.height <= 0 { return start }
		if command.local_border_data != unsafe { nil }
			&& command.local_border_data.corner_shapes != [f64(1), 1, 1, 1]! {
			return start
		}
		if command.has_clip && (command.clip_list == unsafe { nil }
			|| command.clip_list.items.len == 0 || command.clip_width <= 0
			|| command.clip_height <= 0) {
			return start
		}
		if command.has_clip {
			for value in [command.clip_x, command.clip_y, command.clip_width, command.clip_height] {
				if !math.is_finite(value) { return start }
			}
		}
		if command.clip_list != unsafe { nil } {
			for clip in command.clip_list.items {
				if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask
					|| normalized_paint_transform(clip.transform) != [f64(1), 0, 0, 1, 0, 0]! {
					return start
				}
				for value in [clip.rect.x, clip.rect.y, clip.rect.width, clip.rect.height] {
					if !math.is_finite(value) { return start }
				}
				if clip.rect.width <= 0 || clip.rect.height <= 0 { return start }
				// A retained enclosing rectangle remains on the native context.
				// Rounded ancestors must coincide after the same device snapping.
				if clip.corner_radii != layout.BoxRadii{} {
					converter := painting.new_device_pixel_converter(1) or { return start }
					r := converter.rounded_device_rect(painting.Rect{clip.rect.x, clip.rect.y, clip.rect.width, clip.rect.height})
					if [f64(r.x), r.y, r.width, r.height] !=
						[background.x, background.y, background.width, background.height]
						|| clip.corner_radii != chromium_rounded_image_background_radii(background) {
						return start
					}
				} else if clip.rect.x > background.x || clip.rect.y > background.y
					|| clip.rect.x + clip.rect.width < background.x + background.width
					|| clip.rect.y + clip.rect.height < background.y + background.height {
					return start
				}
			}
		}
	}
	paintable := image.image_paintable or { return start }
	if paintable.is_svg_image { return start }
	for value in [paintable.image_rect.x, paintable.image_rect.y, paintable.image_rect.width,
		paintable.image_rect.height] {
		if !math.is_finite(value) { return start }
	}
	converter := painting.new_device_pixel_converter(1) or { return start }
	result := paintable.paint('', painting.IntRect{0, 0, 1, 1}, converter) or { return start }
	clip := replaced_image_gpu_clip_data(image, result.bitmap.clip_rect, result.clip_radii,
		replaced_image_gpu_ancestor_clip_index(image))
	if clip[..4] != [f32(background.x), f32(background.y), f32(background.width),
		f32(background.height)] {
		return start
	}
	radii := chromium_rounded_image_background_radii(background)
	mut rounded := false
	for i, corner in [radii.top_left, radii.top_right, radii.bottom_right, radii.bottom_left] {
		if !math.is_finite(corner.x) || !math.is_finite(corner.y)
			|| corner.x < 0 || corner.y < 0 || clip[4 + i * 2] != f32(corner.x)
			|| clip[5 + i * 2] != f32(corner.y) {
			return start
		}
		rounded = rounded || corner.x > 0 || corner.y > 0
	}
	return if rounded { start + 2 } else { start }
}

fn chromium_rounded_image_background_radii(command &layout.PaintCommand) layout.BoxRadii {
	if command.kind == 'fill_rounded_rect' { return command.corner_radii }
	radius := layout.CornerRadius{command.radius, command.radius}
	return layout.BoxRadii{radius, radius, radius, radius}
}

fn (mut app BrowserApp) draw_chromium_rounded_image_pair(start int, page_y f32, window_height int) int {
	$if macos {
		if !app.ctx.native_rendering || app.page_zoom != 1 || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium
			|| app.paint_effect_depth != 0 || app.paint_svg_mask_depth != 0 {
			return start
		}
		end := chromium_rounded_image_pair_end(app.paint_commands, app.chromium_raster_plan.command_layers, start)
		if end == start { return start }
		image := unsafe { &app.paint_commands[start + 1] }
		if bitmap := replaced_image_bitmap_for_renderer(image, true) {
			if bitmap.width <= 0 || bitmap.height <= 0 || bitmap.pitch != bitmap.width * 4
				|| bitmap.data.len < bitmap.pitch * bitmap.height {
				return start
			}
		} else {
			loaded := app.background_image(image.image().image_url) or { return start }
			if loaded.width <= 0 || loaded.height <= 0 { return start }
		}
		app.flush_rounded_rect_underlay(0, page_y, window_height)
		background := app.paint_commands[start]
		C.native_set_image_background(app.paint_colors.color(background.color, 1))
		defer { C.native_set_image_background(gg.rgba(0, 0, 0, 0)) }
		app.draw_command(image, 0, page_y, window_height)
		return end
	}
	return start
}

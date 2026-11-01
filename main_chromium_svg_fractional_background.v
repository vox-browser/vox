module main

import layout
import math
import painting

struct ChromiumSVGFractionalBackground {
	commands []layout.PaintCommand
	tile     painting.Rect
	clip     painting.Rect
}

fn chromium_svg_fractional_background(command &layout.PaintCommand) ?ChromiumSVGFractionalBackground {
	if command.kind != 'draw_background_image' || command.image_data == unsafe { nil }
		|| command.opacity != 1 || command.group_opacity != 1 || command.outer_shadow
		|| command.blur != 0 || command.clip_outs.len != 0 || command.apply_force_dark_to_image {
		return none
	}
	image := command.image_data
	background := image.background_layer_data or { return none }
	if image.background_blend_mode != .normal
		|| image.image_attachment == 'fixed' || image.image_clip_radii != layout.BoxRadii{}
		|| !chromium_shared_recording_clips_supported(command) {
		return none
	}
	natural := svg_background_natural_metrics(image) or { return none }
	layer := background.resolve_image(image.image_url,
		painting.Rect{command.x, command.y, command.width, command.height}, natural) or { return none }
	clip := painting.Rect{image.image_clip_x, image.image_clip_y, image.image_clip_width, image.image_clip_height}
	plan := painting.background_tile_plan(layer,
		painting.Point{command.image_scroll_offset_x, command.image_scroll_offset_y}, clip)
	tile := plan.first_tile
	if !plan.repeat_x || !plan.repeat_y || tile.width <= 0 || tile.height <= 0
		|| tile.width > 8192 || tile.height > 8192 || tile.width * tile.height > 4 * 1024 * 1024
		|| clip.width <= 0 || clip.height <= 0 {
		return none
	}
	// Integral tiles retain the existing vector path. Fractional SVG tiles
	// require a separately sampled picture to preserve their container size.
	if tile.width == math.round(tile.width) && tile.height == math.round(tile.height) {
		return none
	}
	for value in [tile.x, tile.y, tile.width, tile.height, clip.x, clip.y, clip.width, clip.height] {
		if math.is_nan(value) || math.is_inf(value, 0) { return none }
	}
	commands := svg_background_paint_commands_for_viewport(image, tile.width, tile.height) or { return none }
	if commands.len == 0 || commands.len > 32768 { return none }
	for index in 0 .. commands.len {
		_ = chromium_svg_background_path_clips(&commands[index], []) or { return none }
	}
	return ChromiumSVGFractionalBackground{commands, tile, clip}
}

fn C.native_draw_svg_cover_pattern(&C.VoxGraphitePath, int, &f32, &f32, &f32,
	f32, f32, f32, f32, f32) int

fn (mut app BrowserApp) draw_chromium_svg_fractional_background(command &layout.PaintCommand,
	page_x f32, page_y f32, scroll_y f64) bool {
	$if macos {
		if !app.ctx.native_rendering || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium {
			return false
		}
		pattern := chromium_svg_fractional_background(command) or { return false }
		mut paths := []C.VoxGraphitePath{cap: pattern.commands.len}
		for index in 0 .. pattern.commands.len {
			nested := unsafe { &pattern.commands[index] }
			mut path := chromium_svg_background_path_clips(nested, []) or { return false }
			color := app.paint_colors.color_with_retained(nested.color, 1, nested.retained_svg_fill_color())
			precise := nested.retained_svg_solid_components(false)
			components := precise or { [f64(color.r) / 255, color.g / 255.0, color.b / 255.0,
				color.a / 255.0]! }
			path.red = color.r
			path.green = color.g
			path.blue = color.b
			path.alpha = color.a
			path.has_float_color = int(precise != none)
			path.float_color = [f32(components[0]), f32(components[1]), f32(components[2]),
				f32(components[3])]!
			path.has_float_alpha = 1
			path.opacity = f32(components[3] * nested.svg_data.fill_opacity)
			paths << path
		}
		matrix := normalized_paint_transform(command.transform)
		outer := [f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]),
			f32(matrix[5])]!
		converter := painting.new_device_pixel_converter(1) or { return false }
		origin := converter.rounded_device_rect(pattern.tile)
		tile := [f32(origin.x), f32(origin.y), f32(pattern.tile.width), f32(pattern.tile.height)]!
		r := converter.rounded_device_rect(pattern.clip)
		clip := [f32(r.x), f32(r.y), f32(r.width), f32(r.height), f32(0), 0, 0, 0, 0, 0, 0, 0]!
		app.flush_rounded_rect_underlay(page_x, page_y, int(app.ctx.height))
		return C.native_draw_svg_cover_pattern(paths.data, paths.len, &outer[0], &tile[0], &clip[0],
			page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height)) != 0
	}
	return false
}

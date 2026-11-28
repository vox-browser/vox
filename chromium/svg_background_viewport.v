module main

import layout
import math
import painting

// Keep the image viewport in the path's GPU clip stack. Reapplying it in
// Quartz after readback discards antialiasing samples of contained fills.
fn chromium_svg_background_viewport_path(command &layout.PaintCommand,
	width f64, height f64) ?C.VoxGraphitePath {
	if width <= 0 || height <= 0 || !math.is_finite(width) || !math.is_finite(height) {
		return none
	}
	mut path := chromium_svg_background_path_clips(command, [])?
	matrix := multiply_paint_transforms(command.transform, command.svg_data.path_transform)
	if path.matrix.any(!math.is_finite(it))
		|| (path.has_clip != 0 && path.clip.any(!math.is_finite(it))) {
		return none
	}
	path.has_ancestor_clip = 1
	path.ancestor_clip = svg_background_local_clip(painting.Rect{0, 0, width, height}, matrix)
	if path.ancestor_clip.any(!math.is_finite(it)) { return none }
	return path
}

fn chromium_svg_background_viewport_outer_supported(source &layout.PaintCommand) bool {
	return source.kind == 'draw_background_image' && source.opacity == 1
		&& source.group_opacity == 1 && source.blur == 0 && !source.outer_shadow
		&& !source.apply_force_dark_to_image
}

fn chromium_svg_background_viewport_uses_msaa(commands []layout.PaintCommand) bool {
	for index in 0 .. commands.len {
		if _ := chromium_msaa_trigger_rect(&commands[index]) { return true }
	}
	return false
}

fn (mut app BrowserApp) draw_chromium_svg_background_viewport(source &layout.PaintCommand,
	commands []layout.PaintCommand,
	replay ChromiumSVGBackgroundReplay, page_x f32, page_y f32, scroll_y f64) bool {
	$if macos {
		if !chromium_svg_background_viewport_outer_supported(source)
			|| !app.ctx.native_rendering || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium
			|| commands.len == 0 || commands.len > 32768
			|| !chromium_svg_background_viewport_uses_msaa(commands) {
			return false
		}
		w, h := replay.content_width(), replay.content_height()
		if w <= 0 || h <= 0 || w > 8192 || h > 8192 || w * h > 4 * 1024 * 1024 {
			return false
		}
		m := svg_background_positive_axis_matrix(replay.transform) or { return false }
		if m.any(!math.is_finite(it)) { return false }
		mut paths := []C.VoxGraphitePath{cap: commands.len}
		for command in commands {
			mut path := chromium_svg_background_viewport_path(&command, w, h) or { return false }
			color := app.paint_colors.color_with_retained(command.color, 1, command.retained_svg_fill_color())
			precise := command.retained_svg_solid_components(false)
			components := precise or {
				[f64(color.r) / 255, color.g / 255.0, color.b / 255.0, color.a / 255.0]!
			}
			path.red = color.r
			path.green = color.g
			path.blue = color.b
			path.alpha = color.a
			path.has_float_color = int(precise != none)
			path.float_color = [f32(components[0]), f32(components[1]), f32(components[2]),
				f32(components[3])]!
			path.has_float_alpha = 1
			path.opacity = f32(components[3] * command.svg_data.fill_opacity)
			paths << path
		}
		// The batch's safety enclosure includes the coverage fringe. Each path
		// retains the actual image viewport independently of that enclosure.
		pad_x, pad_y := f64(1) / m[0], f64(1) / m[3]
		outer := [f32(m[0]), f32(m[1]), f32(m[2]), f32(m[3]), f32(m[4]), f32(m[5])]!
		app.flush_rounded_rect_underlay(page_x, page_y, int(app.ctx.height))
		return C.native_draw_svg_path_batch(paths.data, paths.len, &outer[0], f32(-pad_x),
			f32(-pad_y), f32(w + pad_x * 2), f32(h + pad_y * 2), page_x, page_y,
			f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height), unsafe { nil }) != 0
	}
	return false
}

module main

import layout
import math

// A rectangular SVG clip can share the paths' multisample coverage. Applying
// a separately rasterized alpha mask multiplies coincident edge coverage.
// Validate the entire scope before replacing any of its ordinary replay.
fn chromium_svg_rectangular_mask_end(commands []layout.PaintCommand, layers []int,
	start int) int {
	if start < 0 || start >= commands.len || (layers.len != 0 && layers.len != commands.len)
		|| commands[start].kind != 'begin_svg_mask_layer' {
		return start
	}
	first := &commands[start]
	clip := first.mask_clip()
	if !clip.is_svg_mask || clip.is_svg_content_mask { return start }
	rect := svg_background_rectangular_clip(clip) or { return start }
	for index := start; index < commands.len && index - start < 32768; index++ {
		command := &commands[index]
		if layers.len != 0 && layers[index] != layers[start] { return start }
		if index > start && command.kind == 'draw_svg_path' {
			_ := chromium_svg_background_path_clips(command, [rect]) or { return start }
			continue
		}
		if command.opacity != 1 || command.group_opacity != 1 || command.has_clip
			|| command.clip_outs.len != 0 || command.recording_clip != none
			|| normalized_paint_transform(command.transform) != [f64(1), 0, 0, 1, 0, 0]! {
			return start
		}
		if index == start { continue }
		if command.kind != 'end_svg_mask_layer' || index == start + 1 { return start }
		end_clip := command.mask_clip()
		if !end_clip.is_svg_mask || end_clip.is_svg_content_mask
			|| end_clip.cache_key != clip.cache_key || end_clip.scope_id != clip.scope_id
			|| end_clip.rect != clip.rect || end_clip.transform != clip.transform {
			return start
		}
		end_rect := svg_background_rectangular_clip(end_clip) or { return start }
		return if end_rect == rect { index + 1 } else { start }
	}
	return start
}

fn (mut app BrowserApp) draw_chromium_svg_rectangular_mask(commands []layout.PaintCommand,
	layers []int, start int, page_x f32, page_y f32) int {
	$if macos {
		if !app.ctx.native_rendering || app.page_zoom != 1 || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium {
			return start
		}
		end := chromium_svg_rectangular_mask_end(commands, layers, start)
		if end == start { return start }
		rect := svg_background_rectangular_clip(commands[start].mask_clip()) or { return start }
		mut paths := []C.VoxGraphitePath{cap: end - start - 2}
		mut left := math.inf(1)
		mut top := math.inf(1)
		mut right := math.inf(-1)
		mut bottom := math.inf(-1)
		for index in start + 1 .. end - 1 {
			command := &commands[index]
			mut path := chromium_svg_background_path_clips(command, [rect]) or { return start }
			bounds := chromium_msaa_trigger_rect(*command) or { return start }
			left = math.min(left, bounds.x)
			top = math.min(top, bounds.y)
			right = math.max(right, bounds.x + bounds.width)
			bottom = math.max(bottom, bounds.y + bounds.height)
			color := app.paint_colors.color_with_retained(command.color, 1,
				command.retained_svg_fill_color())
			path.red = color.r
			path.green = color.g
			path.blue = color.b
			path.alpha = color.a
			path.has_float_alpha = 1
			path.opacity = f32(f64(color.a) / 255 * command.svg_data.fill_opacity)
			paths << path
		}
		if right <= left || bottom <= top { return end }
		app.flush_rounded_rect_underlay(page_x, page_y, int(app.ctx.height))
		identity := [f32(1), 0, 0, 1, 0, 0]!
		if C.native_draw_svg_path_batch(paths.data, paths.len, &identity[0], f32(left),
			f32(top), f32(right - left), f32(bottom - top), page_x, page_y, 0,
			f32(app.ctx.width), f32(app.ctx.height), unsafe { nil }) != 0 {
			return end
		}
	}
	return start
}

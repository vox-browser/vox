module main

import layout
import math

fn C.native_begin_deferred_inset_decorations(f32, f32, f32, f32, f32, f32, f32, f32) int
fn C.native_end_deferred_inset_decorations() int

// These consecutive decorations belong to one box and one root raster tile.
// Resolve their antialias coverage together, including the shadow between the
// background and border. Other paint operations retain ordinary replay.
fn chromium_inset_decoration_end(commands []layout.PaintCommand, layers []int, index int) int {
	if index < 0 || index + 2 >= commands.len || layers.len != commands.len
		|| layers[index] != 0 { return index }
	background := unsafe { &commands[index] }
	if background.kind !in ['fill_rect', 'fill_rounded_rect'] || background.outer_shadow
		|| background.opacity != 1 || background.width <= 0 || background.height <= 0
		|| background.clip_outs.len > 0 || !chromium_shared_recording_clips_supported(background) {
		return index
	}
	mut end := index + 1
	for end < commands.len && end <= index + 8 {
		command := unsafe { &commands[end] }
		if command.kind != 'paint_inner_box_shadow' { break }
		if command.box_shadow_data == unsafe { nil } { return index }
		end++
	}
	if end == index + 1 || end >= commands.len || commands[end].kind != 'paint_uniform_border' {
		return index
	}
	for i in index + 1 .. end + 1 {
		command := unsafe { &commands[i] }
		if layers[i] != 0 || !command.shares_paint_box_with(background)
			|| command.opacity != 1 || command.clip_outs.len > 0
			|| normalized_paint_transform(command.transform) != normalized_paint_transform(background.transform)
			|| !chromium_shared_recording_clips_supported(command) { return index }
	}
	return end + 1
}

fn (mut app BrowserApp) draw_chromium_inset_decorations(index int, page_y f32, window_height int) int {
	$if macos {
		if !app.ctx.native_rendering || app.page_zoom != 1 || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium { return index }
		end := chromium_inset_decoration_end(app.paint_commands,
			app.chromium_raster_plan.command_layers, index)
		if end == index { return index }
		app.flush_rounded_rect_underlay(0, page_y, window_height)
		points := transformed_rect_points(app.paint_commands[index], 0, page_y, app.scroll_y)
		mut left := points[0]
		mut top := points[1]
		mut right := left
		mut bottom := top
		for i := 2; i < points.len; i += 2 {
			left = math.min(left, points[i])
			top = math.min(top, points[i + 1])
			right = math.max(right, points[i])
			bottom = math.max(bottom, points[i + 1])
		}
		if C.native_begin_deferred_inset_decorations(left, top, right - left, bottom - top,
			f32(app.ctx.width), f32(app.ctx.height), page_y, f32(app.scroll_y)) == 0 { return index }
		for i in index .. end {
			app.draw_command(app.paint_commands[i], 0, page_y, window_height)
		}
		if C.native_end_deferred_inset_decorations() == 0 {
			// The native transaction restores the prefix before retrying.
			for i in index .. end { app.draw_command(app.paint_commands[i], 0, page_y, window_height) }
			app.flush_rounded_rect_underlay(0, page_y, window_height)
		}
		return end
	}
	return index
}

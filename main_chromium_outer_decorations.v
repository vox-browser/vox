module main

import layout
import math

// Consecutive outer shadows and the border of one transparent box share
// coverage in Chromium's raster pass. Preserve that order in one picture.
fn chromium_outer_decoration_end(commands []layout.PaintCommand, layers []int, index int) int {
	if index < 0 || index >= commands.len || layers.len != commands.len
		|| layers[index] != 0 || commands[index].kind != 'paint_outer_box_shadow' {
		return index
	}
	mut end := index
	for end < commands.len && end < index + 8
		&& commands[end].kind == 'paint_outer_box_shadow' { end++ }
	if end >= commands.len || commands[end].kind != 'paint_uniform_border' { return index }
	first := unsafe { &commands[index] }
	matrix := normalized_paint_transform(first.transform)
	for value in matrix {
		if math.is_nan(value) || math.is_inf(value, 0) { return index }
	}
	for i in index .. end + 1 {
		command := unsafe { &commands[i] }
		if layers[i] != 0 || !command.shares_paint_box_with(first)
			|| command.opacity != 1 || command.outer_shadow || command.clip_outs.len > 0
			|| normalized_paint_transform(command.transform) != matrix
			|| !chromium_shared_recording_clips_supported(command)
			|| command.width <= 0 || command.height <= 0 { return index }
		for value in [command.x, command.y, command.width, command.height, command.blur] {
			if math.is_nan(value) || math.is_inf(value, 0) { return index }
		}
		if command.blur < 0 || (i < end && command.box_shadow_data == unsafe { nil }) {
			return index
		}
	}
	return end + 1
}

fn (mut app BrowserApp) draw_chromium_outer_decorations(index int, page_y f32, window_height int) int {
	$if macos {
		if !app.ctx.native_rendering || app.page_zoom != 1 || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium
			|| app.viewport_width <= 4 || app.viewport_height <= 4 { return index }
		end := chromium_outer_decoration_end(app.paint_commands,
			app.chromium_raster_plan.command_layers, index)
		if end == index { return index }
		app.flush_rounded_rect_underlay(0, page_y, window_height)
		// The recording includes the document viewport and its complete raster
		// tiles. Including browser chrome would give the first row a negative
		// document coordinate and select the differently sized fallback target.
		// The native constructor adds two guard pixels around this rectangle.
		if C.native_begin_inset_decorations(2, page_y + 2,
			f32(app.viewport_width - 4), f32(app.viewport_height - 4),
			f32(app.ctx.width), f32(app.ctx.height), page_y, 0) == 0 { return index }
		for i in index .. end { app.draw_command(app.paint_commands[i], 0, page_y, window_height) }
		C.native_end_inset_decorations()
		return end
	}
	return index
}

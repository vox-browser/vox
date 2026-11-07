module main

import layout
import math

fn chromium_text_coverage_leaf_supported(command &layout.PaintCommand) bool {
	if command.opacity != 1 || command.group_opacity != 1 || command.blur != 0
		|| command.outer_shadow || command.underlays_next || command.scrollbar_axis != ''
		|| !chromium_shared_recording_clips_supported(command)
		|| !chromium_svg_compositor_clip_outs_supported(command) { return false }
	for value in [command.x, command.y, command.width, command.height, command.font_size] {
		if math.is_nan(value) || math.is_inf(value, 0) { return false }
	}
	matrix := normalized_paint_transform(command.transform)
	for value in matrix {
		if math.is_nan(value) || math.is_inf(value, 0) { return false }
	}
	return command.width > 0 && command.height > 0
		&& matrix[1] == 0 && matrix[2] == 0 && matrix[0] > 0 && matrix[3] > 0
}

fn chromium_text_coverage_pair_supported(commands []layout.PaintCommand, layers []int, index int) bool {
	if index < 0 || index + 1 >= commands.len || layers.len != commands.len
		|| layers[index] < 0 || layers[index + 1] != layers[index] { return false }
	fill := unsafe { &commands[index] }
	text := unsafe { &commands[index + 1] }
	if fill.kind !in ['fill_rect', 'fill_rounded_rect'] || text.kind != 'draw_text'
		|| !chromium_text_coverage_leaf_supported(fill)
		|| !chromium_text_coverage_leaf_supported(text)
		|| normalized_paint_transform(fill.transform) != normalized_paint_transform(text.transform) {
		return false
	}
	run := text.glyph_run or { return false }
	return run.face() != .emoji && run.glyph_indices().len > 0
}

// Retain coverage at a split underline, or between a generated icon and its
// rounded backing. Resolving each leaf to bytes loses their shared samples.
fn chromium_rounded_glyph_background_run_end(commands []layout.PaintCommand, layers []int, index int) int {
	if index < 0 || index >= commands.len || layers.len != commands.len || layers[index] < 0 { return index }
	mut backgrounds := []int{}
	mut cursor := index
	for cursor < commands.len && backgrounds.len < 16 {
		command := unsafe { &commands[cursor] }
		if command.kind !in ['fill_rect', 'fill_rounded_rect']
			|| (command.radius <= 0 && command.corner_radii == layout.BoxRadii{})
			|| layers[cursor] != layers[index] || command.clip_outs.len != 0
			|| !chromium_text_coverage_leaf_supported(command) { break }
		if cursor > index {
			previous := unsafe { &commands[cursor - 1] }
			if command.x < previous.x + previous.width
				|| command.y >= previous.y + previous.height || previous.y >= command.y + command.height
				|| normalized_paint_transform(command.transform) != normalized_paint_transform(previous.transform) { break }
		}
		backgrounds << cursor
		cursor++
	}
	if backgrounds.len == 0 { return index }
	mut end := index
	for cursor < commands.len && cursor - index < 64 {
		text := unsafe { &commands[cursor] }
		if text.kind != 'draw_text' || layers[cursor] != layers[index]
			|| !chromium_text_coverage_leaf_supported(text) { break }
		run := text.glyph_run or { break }
		if run.face() == .emoji { break }
		if run.glyph_indices().len == 1 {
			for background_index in backgrounds {
				background := unsafe { &commands[background_index] }
				if background.x >= text.x && background.y >= text.y
					&& background.x + background.width <= text.x + text.width
					&& background.y + background.height <= text.y + text.height
					&& normalized_paint_transform(background.transform) == normalized_paint_transform(text.transform) {
					end = cursor + 1
				}
			}
		}
		cursor++
	}
	return end
}

fn chromium_text_coverage_run_end(commands []layout.PaintCommand, layers []int, index int) int {
	background_end := chromium_rounded_glyph_background_run_end(commands, layers, index)
	if background_end > index { return background_end }
	if !chromium_text_coverage_pair_supported(commands, layers, index) { return index }
	first := unsafe { &commands[index] }
	text := unsafe { &commands[index + 1] }
	if first.radius > 0 || first.corner_radii != layout.BoxRadii{}
		|| first.kind != 'fill_rect' || !first.antialiased_rect || first.x != text.x
		|| first.width != text.width { return index }
	mut end := index + 2
	for end + 1 < commands.len && end - index < 64 {
		if !chromium_text_coverage_pair_supported(commands, layers, end)
			|| layers[end] != layers[index] { break }
		next := unsafe { &commands[end] }
		next_text := unsafe { &commands[end + 1] }
		previous := unsafe { &commands[end - 2] }
		if next.kind != 'fill_rect' || !next.antialiased_rect || next.radius != 0
			|| next.corner_radii != layout.BoxRadii{} || next.y != first.y
			|| next.height != first.height || next.color != first.color
			|| next.x != previous.x + previous.width || next.x != next_text.x
			|| next.width != next_text.width
			|| normalized_paint_transform(next.transform) != normalized_paint_transform(first.transform) { break }
		end += 2
	}
	return if end >= index + 4 { end } else { index }
}

fn (mut app BrowserApp) draw_chromium_text_coverage_run(index int, page_y f32, window_height int) int {
	$if macos {
		if !app.ctx.native_rendering || app.page_zoom != 1 || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium
			|| app.viewport_width <= 4 || app.viewport_height <= 4 { return index }
		end := chromium_text_coverage_run_end(app.paint_commands,
			app.chromium_raster_plan.command_layers, index)
		if end == index { return index }
		app.flush_rounded_rect_underlay(0, page_y, window_height)
		if C.native_begin_deferred_inset_decorations(2, page_y + 2,
			f32(app.viewport_width - 4), f32(app.viewport_height - 4),
			f32(app.ctx.width), f32(app.ctx.height), page_y, f32(app.scroll_y)) == 0 { return index }
		for i in index .. end { app.draw_command(app.paint_commands[i], 0, page_y, window_height) }
		app.flush_rounded_rect_underlay(0, page_y, window_height)
		if C.native_end_deferred_inset_decorations() == 0 {
			for i in index .. end { app.draw_command(app.paint_commands[i], 0, page_y, window_height) }
		}
		return end
	}
	return index
}

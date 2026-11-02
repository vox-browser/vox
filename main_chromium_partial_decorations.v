module main

import css
import layout
import math
import os

const partial_decoration_trace = os.getenv('VOX_PARTIAL_DECORATION_TRACE') != ''

fn C.native_begin_inset_decorations(f32, f32, f32, f32, f32, f32, f32, f32) int

// A child header can cover the same rounded edge as its parent's background
// and partial border. Resolve these consecutive decorations in one pass so
// the border's multisample coverage survives until the header is drawn.
fn chromium_partial_decoration_end(commands []layout.PaintCommand, layers []int, index int) int {
	if index < 0 || index + 2 >= commands.len || layers.len != commands.len { return index }
	background := unsafe { &commands[index] }
	border := unsafe { &commands[index + 1] }
	header := unsafe { &commands[index + 2] }
	if background.kind != 'fill_rounded_rect' || border.kind != 'paint_partial_rounded_border'
		|| header.kind != 'fill_rounded_rect' || border.points.len != 4
		|| !background.shares_paint_box_with(border) { return index }
	matrix := normalized_paint_transform(background.transform)
	owner := layers[index]
	if owner < 0 { return index }
	for i in index .. index + 3 {
		command := unsafe { &commands[i] }
		if layers[i] != owner || command.opacity != 1 || command.outer_shadow || command.blur != 0
			|| command.underlays_next || command.clip_outs.len > 0
			|| normalized_paint_transform(command.transform) != matrix
			|| !chromium_shared_recording_clips_supported(command) { return index }
		for value in [command.x, command.y, command.width, command.height] {
			if math.is_nan(value) || math.is_inf(value, 0) { return index }
		}
		if command.width <= 0 || command.height <= 0 { return index }
		color := css.parse_color_string(command.color) or { return index }
		if color.a != 255 { return index }
	}
	for value in matrix {
		if math.is_nan(value) || math.is_inf(value, 0) { return index }
	}
	for value in border.points {
		if value < 0 || math.is_nan(value) || math.is_inf(value, 0) { return index }
	}
	top, right, bottom, left := border.points[0] / 2, border.points[1] / 2,
		border.points[2] / 2, border.points[3] / 2
	if [background.x, background.y, background.width, background.height] !=
		[border.x + left, border.y + top, border.width - left - right, border.height - top - bottom]
		|| [header.x, header.y, header.width] != [border.x, border.y, border.width]
		|| header.height > border.height { return index }
	outer := border.corner_radii
	back := background.corner_radii
	for i, radius in [outer.top_left, outer.top_right, outer.bottom_right, outer.bottom_left] {
		expected := layout.CornerRadius{
			x: math.max(0.0, radius.x - if i in [0, 3] { left } else { right })
			y: math.max(0.0, radius.y - if i < 2 { top } else { bottom })
		}
		if expected != [back.top_left, back.top_right, back.bottom_right, back.bottom_left][i] { return index }
	}
	if header.corner_radii.top_left != outer.top_left || header.corner_radii.top_right != outer.top_right
		|| header.corner_radii.bottom_left != layout.CornerRadius{}
		|| header.corner_radii.bottom_right != layout.CornerRadius{} { return index }
	return index + 3
}

// Positioned headers paint after their siblings' block backgrounds. Retain a
// bounded run through those headers, preserving every intervening root draw.
fn chromium_partial_decoration_run_end(commands []layout.PaintCommand, layers []int, index int) int {
	adjacent := chromium_partial_decoration_end(commands, layers, index)
	if adjacent > index { return adjacent }
	if index < 0 || index + 2 >= commands.len || layers.len != commands.len
		|| commands[index].kind != 'fill_rounded_rect'
		|| commands[index + 1].kind != 'paint_partial_rounded_border' { return index }
	owner := layers[index]
	if owner < 0 || layers[index + 1] != owner { return index }
	if partial_decoration_trace { eprintln('VOX_PARTIAL_DECORATION_TRACE start=${index} owner=${owner}') }
	first := unsafe { &commands[index + 1] }
	mut parents := [index]
	mut matched := [false]
	mut remaining := 1
	mut group_depth := 0
	for scan in index + 2 .. math.min(commands.len, index + 256) {
		if layers[scan] < 0 { continue }
		if layers[scan] != owner {
			if partial_decoration_trace { eprintln('VOX_PARTIAL_DECORATION_TRACE reject layer at=${scan} owner=${layers[scan]}') }
			return index
		}
		command := unsafe { &commands[scan] }
		if command.opacity != 1 || command.outer_shadow
			|| !chromium_shared_recording_clips_supported(command) {
			if partial_decoration_trace { eprintln('VOX_PARTIAL_DECORATION_TRACE reject state at=${scan} kind=${command.kind}') }
			return index
		}
		for value in [command.x, command.y, command.width, command.height, command.blur] {
			if math.is_nan(value) || math.is_inf(value, 0) { return index }
		}
		if command.kind == 'begin_skia_command_group' {
			group_depth++
			if group_depth > 1 { return index }
			continue
		}
		if command.kind == 'end_skia_command_group' {
			if group_depth != 1 { return index }
			group_depth--
			continue
		}
		if command.kind !in ['fill_rect', 'fill_rounded_rect', 'paint_partial_rounded_border',
			'paint_uniform_border', 'stroke_rounded_rect', 'fill_ellipse', 'stroke_ellipse',
			'draw_text', 'draw_text_shadow', 'paint_inner_box_shadow', 'draw_svg_path'] {
			if partial_decoration_trace { eprintln('VOX_PARTIAL_DECORATION_TRACE reject kind at=${scan} kind=${command.kind}') }
			return index
		}
		if command.kind == 'paint_inner_box_shadow' && command.box_shadow_data == unsafe { nil } { return index }
		if command.kind == 'draw_svg_path' && !chromium_svg_compositor_path_supported(command) { return index }
		if command.kind in ['draw_text', 'draw_text_shadow'] && command.glyph_run == none { return index }
		if command.kind != 'fill_rounded_rect' { continue }
		if scan + 1 < commands.len && layers[scan + 1] == owner
			&& commands[scan + 1].kind == 'paint_partial_rounded_border'
			&& commands[scan + 1].x == first.x && commands[scan + 1].width == first.width {
			if parents.len >= 8 { return index }
			parents << scan
			matched << false
			remaining++
			continue
		}
		for parent_index, start in parents {
			if matched[parent_index] { continue }
			// Only header candidates copy these three command records;
			// their retained payloads remain owned by the display list.
			triple := [commands[start], commands[start + 1], *command]
			if chromium_partial_decoration_end(triple, [owner, owner, owner], 0) != 3 { continue }
			matched[parent_index] = true
			remaining--
			break
		}
		if remaining == 0 && group_depth == 0 {
			if partial_decoration_trace { eprintln('VOX_PARTIAL_DECORATION_TRACE matched end=${scan + 1} parents=${parents.len}') }
			return scan + 1
		}
	}
	if partial_decoration_trace { eprintln('VOX_PARTIAL_DECORATION_TRACE unmatched=${remaining}') }
	return index
}

fn (mut app BrowserApp) begin_chromium_partial_decoration_run(index int, end int, page_y f32) bool {
	$if macos {
		mut left := f64(app.viewport_width)
		mut top := f64(page_y + f32(app.viewport_height))
		mut right := 0.0
		mut bottom := f64(page_y)
		first := unsafe { &app.paint_commands[index + 1] }
		for i in index .. end {
			command := unsafe { &app.paint_commands[i] }
			if command.kind != 'paint_partial_rounded_border' || command.x != first.x
				|| command.width != first.width { continue }
			points := transformed_rect_points(*command, 0, page_y, app.scroll_y)
			for k := 0; k < points.len; k += 2 {
				left = math.min(left, points[k])
				top = math.min(top, points[k + 1])
				right = math.max(right, points[k])
				bottom = math.max(bottom, points[k + 1])
			}
		}
		left = math.max(2, left)
		top = math.max(f64(page_y) + 2, top)
		right = math.min(f64(app.viewport_width) - 2, right)
		bottom = math.min(f64(page_y) + app.viewport_height - 2, bottom)
		if right <= left || bottom <= top { return false }
		// Gap draws keep their ordinary pixels. Publication only replaces the
		// bounded decorations; a failed recording retains the complete prefix.
		return C.native_begin_inset_decorations(f32(left), f32(top), f32(right - left), f32(bottom - top),
			f32(app.ctx.width), f32(app.ctx.height), page_y, f32(app.scroll_y)) != 0
	}
	return false
}

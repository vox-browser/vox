module main

import css
import layout
import math

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

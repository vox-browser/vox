module main

import layout
import math

// One box's background, unblurred inset shadows and border retain a common
// sample pass. Clips requiring separate command replay keep the existing path.
fn inset_group_end(commands []layout.PaintCommand, layers []int, start int) int {
	if start < 0 || start + 2 >= commands.len || layers.len != commands.len || layers[start] < 0 {
		return start
	}
	if commands[start].kind !in ['fill_rect', 'fill_rounded_rect'] { return start }
	mut border := start + 1
	for border < commands.len && border <= start + 8 && commands[border].kind == 'paint_inner_box_shadow' {
		border++
	}
	if border == start + 1 || border >= commands.len || commands[border].kind != 'paint_uniform_border' {
		return start
	}
	pair := [commands[start], commands[border]]
	if chromium_rounded_background_pair_end(pair, [0, 0], 0) != 2 { return start }
	first := &commands[start]
	matrix := normalized_paint_transform(first.transform)
	for i in start .. border + 1 {
		c := &commands[i]
		if layers[i] != layers[start] || !c.shares_paint_box_with(first)
			|| normalized_paint_transform(c.transform) != matrix || c.opacity != 1 || c.group_opacity != 1
			|| c.disable_antialias || c.has_clip || c.clip_list != unsafe { nil }
			|| c.recording_clip != none || c.clip_outs.len != 0 || c.outer_shadow
			|| c.scrollbar_axis != '' || chromium_contoured_box_supported(c) {
			return start
		}
		for v in [c.x, c.y, c.width, c.height, c.stroke_width] {
			if math.is_nan(v) || math.is_inf(v, 0) { return start }
		}
		for v in matrix { if math.is_nan(v) || math.is_inf(v, 0) { return start } }
		if i > start && i < border {
			if _ := unblurred_inner_shadow_shape(*c) {} else { return start }
		}
	}
	return border + 1
}

fn (mut app BrowserApp) draw_inset_group(start int, page_y f32, window_height int) int {
	end := inset_group_end(app.paint_commands, app.chromium_raster_plan.command_layers, start)
	if end == start { return start }
	mut shapes := []C.VoxGraphiteShape{cap: end - start}
	for i in start .. end {
		c := &app.paint_commands[i]
		fill := app.paint_colors.color(c.color, 1)
		precise := chromium_retained_paint_color(*c)
		shadow := i > start && i < end - 1
		if !shadow {
			if fill.a != 255 { return start }
			if p := precise {
				if p[3] != 1 { return start }
			}
		}
		mut shape := C.VoxGraphiteShape{}
		if shadow {
			shape = unblurred_inner_shadow_shape(*c) or { return start }
		} else {
			mut radii := c.corner_radii
			if c.kind == 'fill_rect' {
				r := layout.CornerRadius{c.radius, c.radius}
				radii = layout.BoxRadii{ top_left: r, top_right: r, bottom_right: r, bottom_left: r }
			}
			shape = C.VoxGraphiteShape{
				rect:       document_shadow_rect(c.x, c.y, c.width, c.height, radii)
				fill:       if i == start { 1 } else { 0 }
				thickness:  f32(c.stroke_width)
				anti_alias: 1
			}
		}
		shape.red = fill.r
		shape.green = fill.g
		shape.blue = fill.b
		shape.alpha = fill.a
		shape.has_float_color = i32(precise != none)
		shape.float_color = precise or { [f32(0), 0, 0, 0]! }
		shape.force_msaa = 1
		shapes << shape
	}
	app.flush_rounded_rect_underlay(0, page_y, window_height)
	m := normalized_paint_transform(app.paint_commands[start].transform)
	matrix := [f32(m[0]), f32(m[1]), f32(m[2]), f32(m[3]), f32(m[4]), page_y + f32(m[5])]!
	return if C.native_draw_document_shape_group(shapes.data, i32(shapes.len), &matrix[0],
		f32(app.ctx.width), f32(app.ctx.height), 0, page_y, 0) != 0 {
		end
	} else {
		start
	}
}

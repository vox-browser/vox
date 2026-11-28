module main

import layout
import math

// Adjacent opaque sides of one transformed border share a multisample pass.
// Resolving each side before painting the next loses coverage at their join,
// particularly when their raster layer is transparent.
fn solid_border_group_end(commands []layout.PaintCommand, layers []int, start int) int {
	if start < 0 || start >= commands.len || layers.len != commands.len || layers[start] < 0 {
		return start
	}
	first := &commands[start]
	data := first.local_border_data
	if data == unsafe { nil } || !data.has_local_geometry || data.solid_side_count !in [
		2,
		3,
	] {
		return start
	}
	end := start + data.solid_side_count
	if end > commands.len || (start > 0
		&& voidptr(commands[start - 1].local_border_data) == voidptr(data)) {
		return start
	}
	matrix := normalized_paint_transform(first.transform)
	for value in matrix { if !math.is_finite(value) { return start } }
	for i in start .. end {
		c := &commands[i]
		if voidptr(c.local_border_data) != voidptr(data) || layers[i] != layers[start]
			|| c.kind != 'fill_rect' || !c.antialiased_rect || c.disable_antialias
			|| c.color != first.color || c.opacity != 1 || c.group_opacity != 1
			|| c.radius != 0 || c.outer_shadow || c.blur != 0 || c.underlays_next
			|| c.has_clip || c.clip_list != unsafe { nil } || c.recording_clip != none
			|| c.clip_outs.len != 0 || c.scrollbar_axis != ''
			|| normalized_paint_transform(c.transform) != matrix
			|| c.width <= 0 || c.height <= 0 {
			return start
		}
		for value in [c.x, c.y, c.width, c.height] {
			if !math.is_finite(value) { return start }
		}
	}
	return end
}

fn (mut app BrowserApp) draw_solid_border_group(start int, page_y f32) int {
	if !app.ctx.native_rendering || app.page_zoom != 1 || app.document == unsafe { nil }
		|| app.document.font_rendering_policy() != .chromium || app.paint_effect_depth != 0 {
		return start
	}
	end := solid_border_group_end(app.paint_commands, app.chromium_raster_plan.command_layers, start)
	if end == start { return start }
	mut shapes := []C.VoxGraphiteShape{cap: end - start}
	for i in start .. end {
		c := &app.paint_commands[i]
		color := app.paint_colors.color(c.color, 1)
		precise := chromium_retained_paint_color(*c)
		if color.a != 255 { return start }
		if p := precise {
			if p[3] != 1 { return start }
		}
		shapes << C.VoxGraphiteShape{
			rect:            document_shadow_rect(c.x, c.y, c.width, c.height, layout.BoxRadii{})
			fill:            1
			anti_alias:      1
			force_msaa:      1
			red:             color.r
			green:           color.g
			blue:            color.b
			alpha:           color.a
			has_float_color: i32(precise != none)
			float_color:     precise or { [f32(0), 0, 0, 0]! }
		}
	}
	app.flush_rounded_rect_underlay(0, page_y, app.ctx.height)
	m := normalized_paint_transform(app.paint_commands[start].transform)
	matrix := [f32(m[0]), f32(m[1]), f32(m[2]), f32(m[3]), f32(m[4]), page_y + f32(m[5])]!
	return if C.native_draw_document_shape_group(shapes.data, i32(shapes.len), &matrix[0],
		f32(app.ctx.width), f32(app.ctx.height), 0, page_y, 0) != 0 {
		end
	} else {
		start
	}
}

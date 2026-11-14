module main

import layout

// These two opaque paints need one resolve even when the legacy native
// decoration transaction is unavailable. Keep complex clips on their replay path.
fn rounded_background_group_end(commands []layout.PaintCommand, layers []int, start int) int {
	end := chromium_rounded_background_pair_end(commands, layers, start)
	if end != start + 2 { return start }
	for i in start .. end {
		c := &commands[i]
		if c.has_clip || c.clip_list != unsafe { nil } || c.recording_clip != none
			|| c.clip_outs.len != 0 || c.disable_antialias || c.group_opacity != 1
			|| c.scrollbar_axis != '' || chromium_contoured_box_supported(c) {
			return start
		}
	}
	return end
}

fn (mut app BrowserApp) draw_rounded_background_group(start int, page_y f32) int {
	end := rounded_background_group_end(app.paint_commands, app.chromium_raster_plan.command_layers, start)
	if end == start { return start }
	mut shapes := []C.VoxGraphiteShape{cap: 2}
	for i in start .. end {
		c := &app.paint_commands[i]
		fill := app.paint_colors.color(c.color, 1)
		if fill.a != 255 { return start }
		precise := chromium_retained_paint_color(*c)
		mut radii := c.corner_radii
		if c.kind == 'fill_rect' {
			corner := layout.CornerRadius{c.radius, c.radius}
			radii = layout.BoxRadii{ top_left: corner, top_right: corner, bottom_right: corner, bottom_left: corner }
		}
		shapes << C.VoxGraphiteShape{
			rect:            document_shadow_rect(c.x, c.y, c.width, c.height, radii)
			fill:            if i == start { 1 } else { 0 }
			thickness:       f32(c.stroke_width)
			anti_alias:      1
			force_msaa:      1
			red:             fill.r
			green:           fill.g
			blue:            fill.b
			alpha:           fill.a
			has_float_color: i32(precise != none)
			float_color:     precise or { [f32(0), 0, 0, 0]! }
		}
	}
	app.flush_rounded_rect_underlay(0, page_y, app.ctx.height)
	m := normalized_paint_transform(app.paint_commands[start].transform)
	matrix := [f32(m[0]), f32(m[1]), f32(m[2]), f32(m[3]), f32(m[4]), page_y + f32(m[5])]!
	return if C.native_draw_document_shape_group(shapes.data, 2, &matrix[0], f32(app.ctx.width),
		f32(app.ctx.height), 0, page_y, 0) != 0 {
		end
	} else {
		start
	}
}

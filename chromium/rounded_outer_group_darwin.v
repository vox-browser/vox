module main

import layout
import math

// Rounded opaque backgrounds still need their outer shadows' samples alive
// until the border has been drawn. Independent leaf resolves round corners.
fn rounded_outer_group_end(commands []layout.PaintCommand, layers []int, start int) int {
	if start < 0 || start >= commands.len || layers.len != commands.len
		|| commands[start].kind != 'paint_outer_box_shadow' {
		return start
	}
	mut bg := start
	for bg < commands.len && bg < start + 8 && commands[bg].kind == 'paint_outer_box_shadow' {
		bg++
	}
	if bg + 1 >= commands.len || commands[bg].kind !in ['fill_rect', 'fill_rounded_rect']
		|| commands[bg].underlays_next || commands[bg + 1].kind != 'paint_uniform_border' {
		return start
	}
	if chromium_rounded_background_pair_end(commands, layers, bg) != bg + 2 { return start }
	first := &commands[start]
	for i in start .. bg + 2 {
		c := &commands[i]
		if layers[i] != 0 || !c.shares_paint_box_with(first)
			|| normalized_paint_transform(c.transform) != normalized_paint_transform(first.transform)
			|| c.opacity != 1 || c.outer_shadow || c.has_clip || c.clip_list != unsafe { nil }
			|| c.recording_clip != none || c.clip_outs.len > 0 || c.disable_antialias
			|| c.width <= 0 || c.height <= 0 || c.blur < 0 {
			return start
		}
		if i < bg && c.box_shadow_data == unsafe { nil } { return start }
		for v in [c.x, c.y, c.width, c.height, c.blur, c.stroke_width] {
			if math.is_nan(v) || math.is_inf(v, 0) { return start }
		}
		for v in normalized_paint_transform(c.transform) {
			if math.is_nan(v) || math.is_inf(v, 0) { return start }
		}
	}
	return bg + 2
}

fn (mut app BrowserApp) draw_rounded_outer_group(start int, page_y f32, window_height int) int {
	end := rounded_outer_group_end(app.paint_commands, app.chromium_raster_plan.command_layers, start)
	if end == start { return start }
	if app.paint_colors.color(app.paint_commands[end - 1].color, 1).a != 255 { return start }
	app.flush_rounded_rect_underlay(0, page_y, window_height)
	mut shapes := []C.VoxGraphiteShape{}
	for i in start .. end {
		c := &app.paint_commands[i]
		fill := app.paint_colors.color(c.color, 1)
		precise := chromium_retained_paint_color(*c)
		mut radii := c.corner_radii
		if c.kind == 'fill_rect' {
			radii = layout.BoxRadii{
				top_left:     layout.CornerRadius{c.radius, c.radius}
				top_right:    layout.CornerRadius{c.radius, c.radius}
				bottom_left:  layout.CornerRadius{c.radius, c.radius}
				bottom_right: layout.CornerRadius{c.radius, c.radius}
			}
		}
		shadow := c.kind == 'paint_outer_box_shadow'
		mut shape := C.VoxGraphiteShape{
			rect:            document_shadow_rect(c.x, c.y, c.width, c.height, radii)
			fill:            if shadow {
				if c.blur > 0 { 10 } else { 9 }
			} else if i == end - 1 {
				0
			} else {
				1
			}
			thickness:       f32(if shadow { c.blur } else { c.stroke_width })
			anti_alias:      1
			force_msaa:      1
			red:             fill.r
			green:           fill.g
			blue:            fill.b
			alpha:           fill.a
			has_float_color: i32(precise != none)
			float_color:     precise or { [f32(0), 0, 0, 0]! }
		}
		if shadow {
			b := c.box_shadow()
			shape.underlay_rect = document_shadow_rect(b.content_rect.x, b.content_rect.y, b.content_rect.width, b.content_rect.height, b.content_radii)
		}
		shapes << shape
	}
	m := normalized_paint_transform(app.paint_commands[start].transform)
	matrix := [f32(m[0]), f32(m[1]), f32(m[2]), f32(m[3]), f32(m[4]), page_y + f32(m[5])]!
	return if C.native_draw_document_shape_group(shapes.data, i32(shapes.len), &matrix[0], f32(app.ctx.width), f32(app.ctx.height), 0, page_y, 0) != 0 {
		end
	} else {
		start
	}
}

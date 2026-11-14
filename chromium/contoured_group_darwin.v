module main

import ggshape
import layout
import math

fn C.native_draw_document_shape_group(&C.VoxGraphiteShape, i32, &f32, f32, f32, f32, f32, f32) i32

// A contour's shadows and background/border retain their samples until one
// resolve. Only adjacent paints with the same owner, transform and rectangular
// clip can share this pass; other commands use ordinary replay.
fn contoured_group_end(commands []layout.PaintCommand, layers []int, start int) int {
	if start < 0 || start >= commands.len || layers.len != commands.len { return start }
	first := &commands[start]
	if first.kind != 'paint_outer_box_shadow' || !chromium_contoured_box_supported(first) {
		return start
	}
	mut end := start
	for end < commands.len && end - start < 8 && commands[end].kind == 'paint_outer_box_shadow' {
		end++
	}
	if end < commands.len && commands[end].kind in ['fill_rect', 'fill_rounded_rect'] && commands[end].underlays_next {
		end++
	}
	if end >= commands.len || commands[end].kind != 'paint_uniform_border' { return start }
	for i in start .. end + 1 {
		c := &commands[i]
		for value in [c.x, c.y, c.width, c.height, c.blur, c.stroke_width, c.opacity, c.group_opacity] {
			if math.is_nan(value) || math.is_inf(value, 0) { return start }
		}
		if c.width <= 0 || c.height <= 0 || c.group_opacity <= 0
			|| (c.kind == 'paint_outer_box_shadow' && c.box_shadow_data == unsafe { nil })
			|| (c.kind == 'paint_uniform_border' && c.stroke_width <= 0) {
			return start
		}
		for value in normalized_paint_transform(c.transform) {
			if math.is_nan(value) || math.is_inf(value, 0) { return start }
		}
		if layers[i] != layers[start] || !c.shares_paint_box_with(first) || !chromium_contoured_box_supported(c)
			|| c.local_border_data.corner_shapes != first.local_border_data.corner_shapes
			|| normalized_paint_transform(c.transform) != normalized_paint_transform(first.transform)
			|| c.clip_outs.len != 0 || c.recording_clip != none || c.outer_shadow || c.blur < 0
			|| c.has_clip != first.has_clip || c.clip_x != first.clip_x || c.clip_y != first.clip_y
			|| c.clip_width != first.clip_width || c.clip_height != first.clip_height {
			return start
		}
		if c.clip_list != unsafe { nil } {
			for clip in c.clip_list.items {
				m := normalized_paint_transform(clip.transform)
				if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask || clip.corner_radii != layout.BoxRadii{} || m[1] != 0 || m[2] != 0 {
					return start
				}
			}
		}
	}
	return end + 1
}

fn (mut app BrowserApp) draw_contoured_group(start int, page_y f32) int {
	if !app.ctx.native_rendering || app.document == unsafe { nil } || app.page_zoom != 1 || app.document.font_rendering_policy() != .chromium {
		return start
	}
	commands := app.paint_commands
	end := contoured_group_end(commands, app.chromium_raster_plan.command_layers, start)
	if end == start { return start }
	mut shapes := []C.VoxGraphiteShape{}
	mut background := ?layout.PaintCommand(none)
	for i in start .. end {
		mut command := commands[i]
		if command.group_opacity > 0 {
			command.opacity /= command.group_opacity
		} else {
			command.opacity = 1
		}
		if command.kind in ['fill_rect', 'fill_rounded_rect'] {
			background = command
			continue
		}
		shadow := command.kind == 'paint_outer_box_shadow'
		fill := app.paint_colors.color(command.color, command.opacity)
		precise := chromium_retained_paint_color(command)
		mut shape := C.VoxGraphiteShape{
			rect:                  contoured_box_rect(&command)
			fill:                  if shadow { 13 } else { 12 }
			thickness:             f32(if shadow { command.blur } else { command.stroke_width })
			anti_alias:            1
			force_msaa:            1
			red:                   fill.r
			green:                 fill.g
			blue:                  fill.b
			alpha:                 fill.a
			has_float_color:       i32(precise != none)
			float_color:           precise or { [f32(0), 0, 0, 0]! }
			contour_parameters:    [f32(command.local_border_data.corner_shapes[0]),
				f32(command.local_border_data.corner_shapes[1]),
				f32(command.local_border_data.corner_shapes[2]),
				f32(command.local_border_data.corner_shapes[3])]!
			has_contour_reference: 1
			contour_reference:     contoured_box_reference(command.local_border_data)
		}
		if shadow {
			box := command.box_shadow()
			shape.underlay_rect = document_shadow_rect(box.content_rect.x, box.content_rect.y, box.content_rect.width, box.content_rect.height, box.content_radii)
		} else if bg := background {
			color := app.paint_colors.color(bg.color, bg.opacity)
			precise_bg := chromium_retained_paint_color(bg)
			shape.has_underlay = 1
			shape.underlay_rect = contoured_background_in_border_space(&bg, &command)
			shape.underlay_rgba = [color.r, color.g, color.b, color.a]!
			shape.has_float_underlay_color = i32(precise_bg != none)
			shape.underlay_float_color = precise_bg or { [f32(0), 0, 0, 0]! }
		}
		shapes << shape
	}
	app.flush_rounded_rect_underlay(0, page_y, int(app.ctx.height))
	first := &commands[start]
	m := normalized_paint_transform(first.transform)
	matrix := [f32(m[0]), f32(m[1]), f32(m[2]), f32(m[3]), f32(m[4]), page_y + f32(m[5])]!
	C.native_begin_clip()
	defer { C.native_end_clip() }
	if first.has_clip {
		C.native_add_corner_rounded_clip(f32(first.clip_x), f32(first.clip_y), f32(first.clip_width), f32(first.clip_height), 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, page_y, 0, f32(app.ctx.height))
	}
	return if C.native_draw_document_shape_group(shapes.data, i32(shapes.len), &matrix[0], f32(app.ctx.width), f32(app.ctx.height), 0, page_y, 0) != 0 {
		end
	} else {
		start
	}
}

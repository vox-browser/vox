module main

import layout
import math

// Keep rectangular ancestor clips in each shape's local sample stack. Resolving
// a background, partial border and header separately rounds their shared edge.
// Other clip geometry and transforms retain ordinary replay.
fn rounded_background_local_clip(command &layout.PaintCommand) ?[4]f32 {
	if !command.has_clip || command.clip_list == unsafe { nil }
		|| command.clip_list.items.len == 0 || command.recording_clip != none
		|| command.clip_width <= 0 || command.clip_height <= 0
		|| [command.clip_x, command.clip_y, command.clip_width, command.clip_height].any(!math.is_finite(it)) {
		return none
	}
	mut bounds := [math.inf(-1), math.inf(-1), math.inf(1), math.inf(1)]!
	for clip in command.clip_list.items {
		if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask
			|| clip.path_components.len != 0 || clip.corner_radii != layout.BoxRadii{}
			|| normalized_paint_transform(clip.transform) != normalized_paint_transform(command.transform) {
			return none
		}
		r := clip.rect
		if [r.x, r.y, r.width, r.height, r.x + r.width, r.y + r.height].any(!math.is_finite(it))
			|| r.width <= 0 || r.height <= 0 {
			return none
		}
		bounds[0] = math.max(bounds[0], r.x)
		bounds[1] = math.max(bounds[1], r.y)
		bounds[2] = math.min(bounds[2], r.x + r.width)
		bounds[3] = math.min(bounds[3], r.y + r.height)
	}
	result := [f32(bounds[0]), f32(bounds[1]), f32(bounds[2]), f32(bounds[3])]!
	if result.any(!math.is_finite(it)) || result[0] >= result[2] || result[1] >= result[3] {
		return none
	}
	return result
}

// Opaque decorations need one resolve even when the legacy native transaction
// is unavailable. Restrict clip transfer to the partial-border triple.
fn rounded_background_group_end(commands []layout.PaintCommand, layers []int, start int) int {
	end := chromium_rounded_background_pair_end(commands, layers, start)
	if end != start + 2 && end != start + 3 { return start }
	for i in start .. end {
		c := &commands[i]
		if layers[i] != 0 || c.recording_clip != none
			|| c.clip_outs.len != 0 || c.disable_antialias || c.group_opacity != 1
			|| c.scrollbar_axis != '' || chromium_contoured_box_supported(c) {
			return start
		}
		if c.has_clip || c.clip_list != unsafe { nil } {
			if end != start + 3 || rounded_background_local_clip(c) == none { return start }
		}
	}
	return end
}

fn (mut app BrowserApp) draw_rounded_background_group(start int, page_y f32) int {
	end := rounded_background_group_end(app.paint_commands, app.chromium_raster_plan.command_layers, start)
	if end == start { return start }
	return if app.draw_rounded_background_commands(app.paint_commands[start..end], page_y) {
		end
	} else {
		start
	}
}

fn (mut app BrowserApp) draw_rounded_background_commands(commands []layout.PaintCommand, page_y f32) bool {
	mut shapes := []C.VoxGraphiteShape{cap: commands.len}
	for i in 0 .. commands.len {
		c := &commands[i]
		fill := app.paint_colors.color(c.color, 1)
		if fill.a != 255 { return false }
		precise := chromium_retained_paint_color(*c)
		clip := rounded_background_local_clip(c)
		mut radii := c.corner_radii
		if c.kind == 'fill_rect' {
			corner := layout.CornerRadius{c.radius, c.radius}
			radii = layout.BoxRadii{ top_left: corner, top_right: corner, bottom_right: corner, bottom_left: corner }
		}
		shapes << C.VoxGraphiteShape{
			rect:               document_shadow_rect(c.x, c.y, c.width, c.height, radii)
			fill:               match c.kind {
				'paint_uniform_border' { 0 }
				'paint_partial_rounded_border' { 8 }
				else { 1 }
			}
			border_widths:      if c.kind == 'paint_partial_rounded_border' {
				[f32(c.points[0]), f32(c.points[1]), f32(c.points[2]), f32(c.points[3])]!
			} else {
				[4]f32{}
			}
			thickness:          f32(c.stroke_width)
			anti_alias:         1
			force_msaa:         1
			has_intersect_clip: i32(clip != none)
			intersect_clip:     clip or { [4]f32{} }
			red:                fill.r
			green:              fill.g
			blue:               fill.b
			alpha:              fill.a
			has_float_color:    i32(precise != none)
			float_color:        precise or { [f32(0), 0, 0, 0]! }
		}
	}
	app.flush_rounded_rect_underlay(0, page_y, app.ctx.height)
	m := normalized_paint_transform(commands[0].transform)
	matrix := [f32(m[0]), f32(m[1]), f32(m[2]), f32(m[3]), f32(m[4]), page_y + f32(m[5])]!
	return C.native_draw_document_shape_group(shapes.data, shapes.len, &matrix[0], f32(app.ctx.width),
		f32(app.ctx.height), 0, page_y, 0) != 0
}

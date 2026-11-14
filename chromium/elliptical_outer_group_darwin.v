module main

import layout
import math

fn C.native_draw_document_shape_group(&C.VoxGraphiteShape, i32, &f32, f32, f32, f32, f32, f32) i32

// An elliptical box's shadows and border retain their samples through one
// resolve. Only adjacent paints with one owner, transform and clip list can
// share the pass; unsupported paints retain ordinary replay.
fn elliptical_outer_group_end(commands []layout.PaintCommand, layers []int, start int) int {
	if start < 0 || start >= commands.len || layers.len != commands.len { return start }
	first := &commands[start]
	if first.kind != 'paint_outer_box_shadow' || chromium_contoured_box_supported(first) {
		return start
	}
	mut end := start
	for end < commands.len && end - start < 8 && commands[end].kind == 'paint_outer_box_shadow' {
		end++
	}
	if end >= commands.len || commands[end].kind != 'paint_uniform_border' { return start }
	border := commands[end]
	transform := normalized_paint_transform(first.transform)
	if transform[1] == 0 || transform[2] == 0 { return start }
	a := transform[0] * transform[0] + transform[1] * transform[1]
	b := transform[2] * transform[2] + transform[3] * transform[3]
	if a <= 0 || math.abs(a - b) > a * .00001 || math.abs(transform[0] * transform[2] + transform[1] * transform[3]) > a * .00001 {
		return start
	}
	if border.corner_radii.top_left.x == border.corner_radii.top_left.y { return start }
	for i in start .. end + 1 {
		c := &commands[i]
		for radius in [c.corner_radii.top_left, c.corner_radii.top_right, c.corner_radii.bottom_right,
			c.corner_radii.bottom_left] {
			if math.abs(radius.x - c.width * .5) > .00001 || math.abs(radius.y - c.height * .5) > .00001 {
				return start
			}
		}
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
		if layers[i] != layers[start] || !c.shares_paint_box_with(first) || chromium_contoured_box_supported(c)
			|| c.opacity != 1 || c.group_opacity != 1 || c.disable_antialias
			|| !chromium_shared_recording_clips_supported(c)
			|| voidptr(c.clip_list) != voidptr(first.clip_list)
			|| normalized_paint_transform(c.transform) != normalized_paint_transform(first.transform)
			|| c.clip_outs.len != 0 || c.recording_clip != none || c.outer_shadow || c.blur < 0
			|| c.has_clip != first.has_clip || c.clip_x != first.clip_x || c.clip_y != first.clip_y
			|| c.clip_width != first.clip_width || c.clip_height != first.clip_height {
			return start
		}
		if c.clip_list != unsafe { nil } {
			for clip in c.clip_list.items {
				m := normalized_paint_transform(clip.transform)
				if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask || m[1] != 0 || m[2] != 0 {
					return start
				}
			}
		}
	}
	return end + 1
}

fn (mut app BrowserApp) draw_elliptical_outer_group(start int, page_y f32) int {
	if !app.ctx.native_rendering || app.document == unsafe { nil } || app.page_zoom != 1 || app.document.font_rendering_policy() != .chromium {
		return start
	}
	commands := app.paint_commands
	end := elliptical_outer_group_end(commands, app.chromium_raster_plan.command_layers, start)
	if end == start { return start }
	mut shapes := []C.VoxGraphiteShape{}
	filter_clip := chromium_recorded_filter_clip(&commands[start])
	for i in start .. end {
		mut command := commands[i]
		if command.group_opacity > 0 {
			command.opacity /= command.group_opacity
		} else {
			command.opacity = 1
		}
		shadow := command.kind == 'paint_outer_box_shadow'
		fill := app.paint_colors.color(command.color, command.opacity)
		precise := chromium_retained_paint_color(command)
		mut shape := C.VoxGraphiteShape{
			rect:            document_shadow_rect(command.x, command.y, command.width, command.height, command.corner_radii)
			fill:            if shadow {
				if command.blur > 0 { 10 } else { 9 }
			} else {
				6
			}
			thickness:       f32(if shadow { command.blur } else { command.stroke_width })
			anti_alias:      1
			force_msaa:      1
			red:             fill.r
			green:           fill.g
			blue:            fill.b
			alpha:           fill.a
			has_float_color: i32(precise != none)
			float_color:     precise or { [f32(0), 0, 0, 0]! }
			border_widths:   [f32(command.stroke_width), f32(command.stroke_width),
				f32(command.stroke_width), f32(command.stroke_width)]!
		}
		if shadow {
			box := command.box_shadow()
			shape.underlay_rect = document_shadow_rect(box.content_rect.x, box.content_rect.y, box.content_rect.width, box.content_rect.height, box.content_radii)
		}
		if shape.fill == 10 {
			if clip := filter_clip {
				shape.has_filter_clip = 2
				shape.filter_clip = clip
			}
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
		if first.clip_list != unsafe { nil } && first.clip_list.items.len > 0 {
			for clip in first.clip_list.items {
				r := clip.corner_radii
				mclip := normalized_paint_transform(clip.transform)
				C.native_add_corner_rounded_clip(f32(clip.rect.x), f32(clip.rect.y), f32(clip.rect.width), f32(clip.rect.height), f32(r.top_left.x), f32(r.top_left.y), f32(r.top_right.x), f32(r.top_right.y), f32(r.bottom_right.x), f32(r.bottom_right.y), f32(r.bottom_left.x), f32(r.bottom_left.y), f32(mclip[0]), f32(mclip[1]), f32(mclip[2]), f32(mclip[3]), f32(mclip[4]), f32(mclip[5]), 0, page_y, 0, f32(app.ctx.height))
			}
		} else {
			C.native_add_corner_rounded_clip(f32(first.clip_x), f32(first.clip_y), f32(first.clip_width), f32(first.clip_height), 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, page_y, 0, f32(app.ctx.height))
		}
	}

	return if C.native_draw_document_shape_group(shapes.data, i32(shapes.len), &matrix[0], f32(app.ctx.width), f32(app.ctx.height), 0, page_y, 0) != 0 {
		end
	} else {
		start
	}
}

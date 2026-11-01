module main

import gg
import layout

fn C.native_set_contoured_box_reference(&f32)

fn C.native_draw_contoured_box_srgb(&f32, &f32, &f32, &f32, f32, f32, f32, f32, f32, gg.Color, i32, f32) i32

fn chromium_contoured_box_supported(command &layout.PaintCommand) bool {
	data := command.local_border_data
	return data != unsafe { nil } && data.corner_shapes != [f64(1), 1, 1, 1]!
		&& data.corner_shapes.all(it >= 0)
}

fn chromium_contoured_path_required(command &layout.PaintCommand) bool {
	if !chromium_contoured_box_supported(command)
		|| command.local_border_data.corner_shapes.all(it >= 10) {
		return false
	}
	return if command.kind == 'fill_rect' {
		command.radius > 0
	} else {
		command.corner_radii != layout.BoxRadii{}
	}
}

fn contoured_box_rect(command &layout.PaintCommand) [12]f32 {
	r := command.corner_radii
	return if command.kind == 'fill_rect' {
		[f32(command.x), f32(command.y), f32(command.width), f32(command.height), f32(command.radius),
			f32(command.radius), f32(command.radius), f32(command.radius), f32(command.radius),
			f32(command.radius), f32(command.radius), f32(command.radius)]!
	} else {
		[f32(command.x), f32(command.y), f32(command.width), f32(command.height), f32(r.top_left.x),
			f32(r.top_left.y), f32(r.top_right.x), f32(r.top_right.y), f32(r.bottom_right.x),
			f32(r.bottom_right.y), f32(r.bottom_left.x), f32(r.bottom_left.y)]!
	}
}

fn contoured_box_reference(data &layout.PaintLocalBorderData) [12]f32 {
	r := data.shape_border_radii
	box := data.shape_border_rect
	return [f32(box.x), f32(box.y), f32(box.width), f32(box.height), f32(r.top_left.x),
		f32(r.top_left.y), f32(r.top_right.x), f32(r.top_right.y), f32(r.bottom_right.x),
		f32(r.bottom_right.y), f32(r.bottom_left.x), f32(r.bottom_left.y)]!
}

fn contoured_background_in_border_space(background &layout.PaintCommand,
	border &layout.PaintCommand) [12]f32 {
	mut rect := contoured_box_rect(background)
	if background.local_border_data != unsafe { nil } && border.local_border_data != unsafe { nil } {
		rect[0] += f32(border.local_border_data.shape_border_rect.x - background.local_border_data.shape_border_rect.x)
		rect[1] += f32(border.local_border_data.shape_border_rect.y - background.local_border_data.shape_border_rect.y)
	}
	return rect
}

fn (mut app BrowserApp) draw_chromium_corner_shape(command &layout.PaintCommand,
	source &layout.PaintCommand, matrix [6]f64, page_x f32, page_y f32, scroll_y f64,
	window_height int) bool {
	$if macos {
		data := command.local_border_data
		if !app.ctx.native_rendering || app.document == unsafe { nil } || app.page_zoom != 1
			|| app.document.font_rendering_policy() != .chromium
			|| !chromium_contoured_box_supported(command)
			|| command.kind !in ['fill_rect', 'fill_rounded_rect', 'paint_uniform_border',
				'paint_outer_box_shadow'] {
			return false
		}
		if command.kind in ['fill_rect', 'fill_rounded_rect'] && command.underlays_next {
			app.rounded_rect_underlay = *command
			app.rounded_rect_underlay_source = *source
			return true
		}
		mode := if command.kind == 'paint_uniform_border' {
			1
		} else if command.kind == 'paint_outer_box_shadow' {
			2
		} else {
			0
		}
		mut pending_source := ?layout.PaintCommand(none)
		if mode == 1 {
			if background := app.rounded_rect_underlay {
				rect := contoured_background_in_border_space(&background, command)
				C.native_set_rounded_rect_underlay(&rect[0], app.paint_colors.color(background.color, background.opacity))
				set_native_chromium_underlay_color(background)
				pending_source = app.rounded_rect_underlay_source
				app.rounded_rect_underlay = none
				app.rounded_rect_underlay_source = none
			}
		}
		target := contoured_box_rect(command)
		parameters := [f32(data.corner_shapes[0]), f32(data.corner_shapes[1]),
			f32(data.corner_shapes[2]), f32(data.corner_shapes[3])]!
		transform := [f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]),
			f32(matrix[5])]!
		mut cutout := [12]f32{}
		if mode == 2 {
			shadow := command.box_shadow()
			r := shadow.content_radii
			cutout = [f32(shadow.content_rect.x), f32(shadow.content_rect.y),
				f32(shadow.content_rect.width), f32(shadow.content_rect.height), f32(r.top_left.x),
				f32(r.top_left.y), f32(r.top_right.x), f32(r.top_right.y), f32(r.bottom_right.x),
				f32(r.bottom_right.y), f32(r.bottom_left.x), f32(r.bottom_left.y)]!
		}
		reference := contoured_box_reference(data)
		C.native_set_contoured_box_reference(&reference[0])
		set_native_chromium_paint_color(*command)
		if C.native_draw_contoured_box_srgb(&target[0], &parameters[0], &cutout[0], &transform[0],
			page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height),
			app.paint_colors.color(command.color, command.opacity), i32(mode),
			f32(if mode == 2 { command.blur } else { command.stroke_width })) != 0 {
			return true
		}
		if background := pending_source {
			app.draw_command(layout.PaintCommand{ ...background, underlays_next: false }, page_x, page_y, window_height)
		}
	}
	return false
}

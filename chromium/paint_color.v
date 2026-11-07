module main

import layout

fn C.native_set_unrounded_paint_color(&f32)
fn C.native_set_rounded_rect_underlay_color(&f32)

fn chromium_retained_paint_color(command layout.PaintCommand) ?[4]f32 {
	data := command.srgb_color_data
	if data == unsafe { nil } || data.serialized != command.color {
		return none
	}
	return [f32(data.components[0]), f32(data.components[1]), f32(data.components[2]),
		f32(data.components[3] * command.opacity)]!
}

fn set_native_chromium_paint_color(command layout.PaintCommand) {
	$if macos {
		if color := chromium_retained_paint_color(command) {
			C.native_set_unrounded_paint_color(&color[0])
		} else {
			C.native_set_unrounded_paint_color(unsafe { nil })
		}
	}
}

fn set_native_chromium_underlay_color(command layout.PaintCommand) {
	$if macos {
		if color := chromium_retained_paint_color(command) {
			C.native_set_rounded_rect_underlay_color(&color[0])
		} else {
			C.native_set_rounded_rect_underlay_color(unsafe { nil })
		}
	}
}

module main

import layout

fn C.native_set_unrounded_paint_color(&f32)

fn set_native_chromium_paint_color(command layout.PaintCommand) {
	$if macos {
		data := command.srgb_color_data
		if data != unsafe { nil } && data.serialized == command.color {
			color := [f32(data.components[0]), f32(data.components[1]), f32(data.components[2]),
				f32(data.components[3] * command.opacity)]!
			C.native_set_unrounded_paint_color(&color[0])
		} else {
			C.native_set_unrounded_paint_color(unsafe { nil })
		}
	}
}

module layout

import html
import math

fn test_fractional_border_colors_survive_block_paint_lowering() {
	for chromium in [false, true] {
		for declaration in ['border-bottom:1px solid hsl(210 8% 90%)',
			'border:1px solid hsl(210 8% 90%);border-radius:8px'] {
			mut document := html.parse_document('<!doctype html><style>
				body{margin:0}div{position:absolute;left:10px;top:20px;width:120px;height:30px;${declaration}}
			</style><div></div>')
			defer { document.finalize() }
			if chromium { document.set_font_rendering_policy(.chromium) }
			root := layout_document_typed_in_viewport(document, 320, 240)
			commands := root.paint_commands().filter(it.force_dark_role_set && it.force_dark_role == .border)
			assert commands.len == 1
			data := commands[0].srgb_color_data
			if !chromium {
				assert data == unsafe { nil }
				continue
			}
			assert data != unsafe { nil }
			assert data.serialized == commands[0].color
			assert math.abs(data.components[0] - .892) < 1e-8
			assert math.abs(data.components[1] - .9) < 1e-8
			assert math.abs(data.components[2] - .908) < 1e-8
			assert data.components[3] == 1
			if declaration.starts_with('border-bottom') {
				assert commands[0].kind == 'fill_rect'
				assert commands[0].x == 10 && commands[0].y == 50
				assert commands[0].width == 120 && commands[0].height == 1
			}
		}
	}
}

fn test_byte_translucent_and_different_precision_borders_keep_their_paint_paths() {
	for declaration in ['border:1px solid #e3e6e8', 'border:1px solid rgb(227.46 229.5 231.54 / .5)',
		'border:1px solid hsl(210 8% 90%);border-right-color:rgb(227 230 232)'] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0}div{width:120px;height:30px;${declaration}}
		</style><div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 320, 240)
		commands := root.paint_commands().filter(it.force_dark_role_set && it.force_dark_role == .border)
		assert commands.len > 0
		assert commands.all(it.srgb_color_data == unsafe { nil })
	}
}

fn test_dashed_border_strokes_retain_computed_color_and_alpha_precision() {
	for side in ['top', 'right', 'bottom', 'left'] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0}div{width:120px;height:30px;border-${side}:1px dashed rgb(34.25 34 34 / .201)}
		</style><div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 320, 240)
		commands := root.paint_commands().filter(it.force_dark_role_set && it.force_dark_role == .border)
		assert commands.len == 1
		command := commands[0]
		assert command.kind == 'draw_svg_path'
		components := command.retained_svg_solid_components(true) or { panic('missing precise stroke') }
		assert math.abs(components[0] * 255 - 34.25) < 1e-8
		assert math.abs(components[1] * 255 - 34) < 1e-8
		assert components[3] == 0.201
		assert command.svg().stroke_dasharray.len == 2
	}
}

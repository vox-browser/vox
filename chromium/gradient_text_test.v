module main

import html
import layout

fn test_chromium_gradient_text_retains_only_complete_gradient_and_glyph_inputs() {
	for tag in ['span', 'div'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0;font:64px Arial}' + tag + '{background:linear-gradient(90deg,#79a8f3,#c9ddff);background-clip:text;color:transparent}</style><' + tag + '>Gradient text</' + tag + '>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		list := document.record_display_list() or { panic('missing retained paint') }
		commands := layout.display_list_commands(list)
		mut checked := 0
		for index, command in commands {
			if command.kind != 'begin_background_text_clip' { continue }
			if commands[index + 1].kind == 'end_background_text_clip' {
				assert !chromium_gradient_text_input_supported(commands, index)
				continue
			}
			assert chromium_gradient_text_input_supported(commands, index)
			assert !chromium_gradient_text_input_supported(commands[..index + 2], index)
			mut mixed := commands.clone()
			mixed[index + 1] = layout.PaintCommand{ kind: 'fill_rect' }
			assert !chromium_gradient_text_input_supported(mixed, index)
			mut empty := commands.clone()
			empty[index] = layout.PaintCommand{ kind: 'begin_background_text_clip' }
			assert !chromium_gradient_text_input_supported(empty, index)
			mut nested := commands.clone()
			nested.insert(index + 1, layout.PaintCommand{ kind: 'begin_css_filter_layer' })
			assert !chromium_gradient_text_input_supported(nested, index)
			checked++
		}
		assert checked == 1
	}
	assert !chromium_gradient_text_input_supported([], 0)
	assert !chromium_gradient_text_input_supported([], -1)
}

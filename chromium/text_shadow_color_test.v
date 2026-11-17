module main

import dom
import html
import layout

fn test_text_shadow_commands_keep_fractional_author_colors_in_layer_order() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := html.parse_document('<!doctype html><style>span{font:14px Arial;
			text-shadow:0 1px 1px rgb(10.5 20.25 30.75 / 25%),0 2px 1px rgb(50.5 60.25 70.75 / 40%)}
		</style><span>Submit</span>')
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		root := layout.layout_document_typed_in_viewport(document, 200, 100)
		commands := root.paint_commands().filter(it.kind == 'draw_text_shadow')
		count := commands.len
		assert count == 2
		for index, command in commands {
			data := command.srgb_color_data
			if policy == .libweb {
				assert data == unsafe { nil }
				continue
			}
			assert data != unsafe { nil }
			assert data.serialized == command.color
			expected := if index == 0 {
				[50.5 / 255, 60.25 / 255, 70.75 / 255, .4]!
			} else {
				[10.5 / 255, 20.25 / 255, 30.75 / 255, .25]!
			}
			assert data.components == expected
		}
	}
}

fn test_single_text_shadow_preserves_modern_alpha_and_legacy_quantization() {
	for index, color in ['rgba(0,0,0,.5)', 'rgb(0 0 0 / .5)'] {
		mut document := html.parse_document('<!doctype html><span style="font:14px Arial;text-shadow:0 1px 1px ${color}">Submit</span>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		root := layout.layout_document_typed_in_viewport(document, 200, 100)
		commands := root.paint_commands().filter(it.kind == 'draw_text_shadow')
		count := commands.len
		assert count == 1
		data := commands[0].srgb_color_data
		assert data != unsafe { nil }
		expected_alpha := if index == 0 { 128.0 / 255 } else { .5 }
		assert data.components == [f64(0), 0, 0, expected_alpha]!
	}
}

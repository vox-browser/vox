module layout

import html
import math

fn test_chromium_foreground_preserves_modern_alpha_and_fractional_channels() {
	for chromium in [true, false] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0;font:16px/24px Arial}
			#modern{color:rgb(51 51 51 / 59%)}
			#legacy{color:rgba(51,51,51,.59)}
			#fractional{color:rgb(10.5 20.25 30.75 / 59%)}
			#opaque{color:rgb(51 51 51)}
		</style><div id="modern"><span>Modern</span></div><div id="legacy">Legacy</div>
		<div id="fractional">Fractional</div><div id="opaque">Opaque</div>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		mut root := layout_document_typed_in_viewport(document, 800, 600)
		commands := root.paint_commands().filter(it.kind == 'draw_text')
		modern := commands.filter(it.text == 'Modern')[0]
		legacy := commands.filter(it.text == 'Legacy')[0]
		fractional := commands.filter(it.text == 'Fractional')[0]
		opaque := commands.filter(it.text == 'Opaque')[0]
		assert opaque.srgb_color_data == unsafe { nil }
		if chromium {
			assert legacy.srgb_color_data != unsafe { nil }
			assert legacy.srgb_color_data.components[3] == 150.0 / 255
			assert modern.srgb_color_data != unsafe { nil }
			assert modern.srgb_color_data.serialized == modern.color
			assert modern.srgb_color_data.components[0] == 51.0 / 255
			assert math.abs(modern.srgb_color_data.components[3] - .59) < 1e-8
			assert fractional.srgb_color_data != unsafe { nil }
			assert fractional.srgb_color_data.components[0] == 10.5 / 255
			assert fractional.srgb_color_data.components[1] == 20.25 / 255
			assert fractional.srgb_color_data.components[2] == 30.75 / 255
		} else {
			assert legacy.srgb_color_data == unsafe { nil }
			assert modern.srgb_color_data == unsafe { nil }
			assert fractional.srgb_color_data == unsafe { nil }
		}
	}
}

fn test_fractional_foreground_hover_refresh_keeps_the_retained_color_snapshot() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;font:16px/24px Arial}
		a{display:block;color:rgb(51 51 51 / 58.83%)}
		a:hover{color:rgb(51 51 51 / 59.01%)}
	</style><a id="link"><span>Author</span></a>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 320, 240)
	link := document.get_element_by_id('link')?
	mut result := document_layout_result(document)?
	before_list := document.record_display_list()?
	before_scene := retain_display_list_scene(before_list)
	defer { release_display_list_scene(before_scene) }
	before_commands := display_list_commands(before_list)
	before := before_commands.filter(it.kind == 'draw_text')[0]
	assert before.srgb_color_data != unsafe { nil }
	children := result.paint_tree.children.data
	document.set_hovered_node(link.as_node())
	document.update_layout(.event_handler_handle_mouse_move)
	after_list := document.record_display_list()?
	after_commands := display_list_commands(after_list)
	after := after_commands.filter(it.kind == 'draw_text')[0]
	assert after.srgb_color_data != unsafe { nil }
	assert result.paint_tree.children.data == children
	assert before.color == after.color
	assert math.abs(before.srgb_color_data.components[3] - .5883) < 1e-8
	assert math.abs(after.srgb_color_data.components[3] - .5901) < 1e-8
}

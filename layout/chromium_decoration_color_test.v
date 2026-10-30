module layout

import html
import math

fn test_chromium_underlines_preserve_current_and_explicit_fractional_colors() {
	for chromium in [true, false] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0;font:13px/24px Arial}
			div{text-decoration:underline}
			#current{color:rgb(10.5 20.25 30.75)}
			#explicit{color:black;text-decoration-color:rgb(40.5 50.25 60.75 / 59%)}
			#legacy{color:black;text-decoration-color:rgba(40,50,60,.59)}
			#integer{color:rgb(10 20 30)}
		</style><div id="current">Current</div><div id="explicit">Explicit</div>
		<div id="legacy">Legacy</div><div id="integer">Integer</div>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		root := layout_document_typed_in_viewport(document, 400, 200)
		underlines := root.paint_commands().filter(it.kind == 'fill_rect' && it.antialiased_rect)
		if !chromium {
			assert underlines.len == 0
			current := document.get_element_by_id('current')?
			node := unsafe { &Node(current.as_node().unsafe_layout_node()?.real_layout_handle()) }
			fragment := TextFragment{layout_handle:voidptr(node)}
			assert chromium_decoration_srgb_color(&fragment,
				node.computed_values().text_decoration_color().serialize()) == unsafe { nil }
			continue
		}
		assert underlines.len == 4
		assert underlines[2].srgb_color_data == unsafe { nil }
		assert underlines[3].srgb_color_data == unsafe { nil }
		for index, channels in [[f64(10.5),20.25,30.75], [f64(40.5),50.25,60.75]] {
			data := underlines[index].srgb_color_data
			assert data != unsafe { nil }
			assert data.serialized == underlines[index].color
			for channel in 0 .. 3 {
				assert math.abs(data.components[channel] * 255 - channels[channel]) < 1e-6
			}
		}
		assert math.abs(underlines[1].srgb_color_data.components[3] - .59) < 1e-8
	}
}

fn test_underline_color_snapshots_survive_hover_and_reject_synthetic_overrides() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;font:13px/24px Arial}
		a{display:block;color:rgb(10.1 20.1 30.1);text-decoration:underline}
		a:hover{color:rgb(10.4 20.4 30.4)}
	</style><a id="link">A link</a>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 320, 240)
	before_list := document.record_display_list()?
	before_scene := retain_display_list_scene(before_list)
	defer { release_display_list_scene(before_scene) }
	before := display_list_commands(before_list).filter(it.kind == 'fill_rect' && it.antialiased_rect)[0]
	assert before.srgb_color_data != unsafe { nil }
	link := document.get_element_by_id('link')?
	document.set_hovered_node(link.as_node())
	document.update_layout(.event_handler_handle_mouse_move)
	after_list := document.record_display_list()?
	after := display_list_commands(after_list).filter(it.kind == 'fill_rect' && it.antialiased_rect)[0]
	assert after.srgb_color_data != unsafe { nil }
	assert before.color == after.color
	assert math.abs(before.srgb_color_data.components[0] * 255 - 10.1) < 1e-6
	assert math.abs(after.srgb_color_data.components[0] * 255 - 10.4) < 1e-6
	node := unsafe { &Node(link.as_node().unsafe_layout_node()?.real_layout_handle()) }
	fragment := TextFragment{layout_handle:voidptr(node),color:node.computed_values().color()}
	assert chromium_decoration_srgb_color(&fragment, 'rgb(255 0 0)') == unsafe { nil }
	assert chromium_decoration_srgb_color(&TextFragment{}, before.color) == unsafe { nil }
}

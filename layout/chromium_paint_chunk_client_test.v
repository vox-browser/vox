module layout

import html
import os

fn test_absolute_scroll_overlay_does_not_absorb_later_in_flow_content() {
	base := os.read_file('${@DIR}/../Tests/Browser/Brave/input/guardian-carousel-paint-clients.html')!
	mut document := html.parse_document(base + '<h1 style="margin:0;padding-top:406px">Later news</h1>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1024, 768)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	mut plan := ChromiumRasterLayerPlan{}
	update_chromium_raster_layer_plan_for_viewport(document, commands, 1, LayoutRect{0,0,1024,768}, mut plan)
	assert plan.has_paint_metadata
	mut headings := 0
	for index, command in commands {
		if command.kind == 'draw_text' && command.text.contains('Later') {
			headings++
			assert plan.command_layers[index] == 0
		}
	}
	assert headings > 0
}

fn test_carousel_overlay_does_not_promote_a_disjoint_svg_with_the_same_property_state() {
	base := os.read_file('${@DIR}/../Tests/Browser/Brave/input/guardian-carousel-paint-clients.html')!
	for wrapped in [false, true] {
		markup := if wrapped {
			base.replace('</style>', '.logo-wrapper{position:absolute;left:691px;top:206px;display:flex;width:291px;height:100px}.logo-wrapper #logo{position:static}.sr{position:absolute;width:1px;height:1px;margin:-1px;clip:rect(1px,1px,1px,1px)}</style>')
				.replace('<svg id="logo"', '<div class="logo-wrapper"><a href="/"><span class="sr">Home</span><svg id="logo"')
				.replace('</svg>', '</svg></a></div>')
		} else { base }
		mut document := html.parse_document(markup)
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
		mut plan := ChromiumRasterLayerPlan{}
		update_chromium_raster_layer_plan_for_viewport(document, commands, 1, LayoutRect{0,0,1024,768}, mut plan)
		assert plan.has_paint_metadata
		mut gradients := 0
		mut paths := 0
		for index, command in commands {
			if command.kind == 'fill_gradient' {
				gradients++
				assert plan.command_layers[index] > 0
			}
			if command.kind == 'draw_svg_path' && command.y > 200 {
				paths++
				assert plan.command_layers[index] == 0, 'Disjoint logo, wrapped=${wrapped}'
			}
		}
		assert gradients == 1 && paths > 0
	}
}

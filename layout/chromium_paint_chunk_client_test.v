module layout

import html
import os

fn test_hit_test_bounds_snap_without_shrinking_painted_ink() {
	command := PaintCommand{ kind: 'fill_rect' }
	box := BlockBox{
		snaps_background_rect: true
		x:                     903.890625
		y:                     206
		width:                 78.109375
		height:                24.1875
		paint_transform:       [f64(1), 0, 0, 1, 0.25, -0.25]!
	}
	metadata := compatibility_affine_map_rect(box.paint_transform, chromium_hit_test_border_rect(&box))
	assert metadata == LayoutRect{904.25, 205.75, 78, 24}
	assert chromium_raster_chunk_bounds(&box, &command) == LayoutRect{904.140625, 205.75, 78.109375, 24.1875}
	unsnapped := BlockBox{ ...box, snaps_background_rect: false }
	assert chromium_hit_test_border_rect(&unsnapped) == unsnapped.border_box()
	transformed := BlockBox{ ...box, own_paint_transform: [f64(0), 1, -1, 0, 0, 0]! }
	assert chromium_hit_test_border_rect(&transformed) == transformed.border_box()
	inherited := BlockBox{ ...box, paint_transform: [f64(0), 1, -1, 0, 0, 0]! }
	assert chromium_hit_test_border_rect(&inherited) == inherited.border_box()
	// The ticker circle's painted extent must retain its fractional top.
	// Snapping this to 68 changes the origin of its neighboring gradient.
	circle := BlockBox{ snaps_background_rect: true, x: 972, y: 67.5, width: 32, height: 32 }
	assert chromium_hit_test_border_rect(&circle).y == 68
	assert chromium_raster_chunk_bounds(&circle, &command).y == 67.5
}

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

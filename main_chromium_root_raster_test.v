module main

import html
import layout

fn test_root_raster_uses_scrollable_overflow_without_shadow_ink() {
	for width in [1280, 1400] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}div{width:${width}px;height:2000px;box-shadow:0 0 150px red}</style><div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 1280, 800)
		extent := chromium_root_raster_extent(document) or { panic('missing root scrolling bounds') }
		assert extent.x + extent.width == width
		assert extent.y + extent.height == 2000
		list := document.record_display_list() or { panic('missing paint') }
		commands := layout.display_list_commands(list)
		plan := layout.chromium_raster_layer_plan(document, commands, 1)
		assert plan.layers[0].bounds.x + plan.layers[0].bounds.width > width
		mut storage := ChromiumMSAAStorage{}
		storage.update_for_device_viewport(commands, plan, 1280, 800, 1280, 800,
			0, 1, extent)
		assert storage.grids[0].tile_width == if width == 1280 { 1280 } else { 672 }
		assert storage.grids[0].columns == if width == 1280 { 1 } else { 3 }
	}
}

fn test_root_raster_extent_does_not_change_independent_surfaces() {
	plan := layout.ChromiumRasterLayerPlan{
		layers:         [
			layout.ChromiumRasterLayer{ bounds: layout.LayoutRect{ width: 1364, height: 2000 } },
			layout.ChromiumRasterLayer{ bounds: layout.LayoutRect{ width: 900, height: 400 } },
		]
		command_layers: []int{}
	}
	mut storage := ChromiumMSAAStorage{}
	storage.update_for_device_viewport([], plan, 1280, 800, 1280, 800, 0, 1,
		layout.LayoutRect{ width: 1280, height: 2000 })
	assert storage.grids[0].tile_width == 1280
	assert storage.grids[0].columns == 1
	assert storage.grids[1].tile_width == 960
	assert storage.grids[1].columns == 1
}

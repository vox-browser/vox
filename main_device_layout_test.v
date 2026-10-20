module main

import html
import layout

fn test_native_device_layout_retains_css_layout_for_embedded_user_spaces() {
	for markup in ['<svg></svg>', '<math></math>', '<iframe></iframe>', '<canvas></canvas>',
		'<video></video>'] {
		mut document := html.parse_document('<!doctype html>${markup}')
		assert !browser_document_supports_device_layout(document), markup
		document.finalize()
	}
	mut document := html.parse_document('<!doctype html><div><img src="image.svg"><input type="checkbox"></div>')
	defer { document.finalize() }
	assert browser_document_supports_device_layout(document)
}

fn test_native_device_viewport_is_independent_of_emulated_raster_scale() {
	commands := [layout.PaintCommand{ kind: 'fill_rect', x: 10, y: 10, width: 10, height: 10 }]
	plan := layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{ bounds: layout.LayoutRect{ width: 1024, height: 2000 } }]
		command_layers: [0]
	}
	mut storage := ChromiumMSAAStorage{}
	storage.update(commands, plan, 1024, 684, 0, 2)
	assert storage.grids[0].tile_width == 544
	storage.update_for_device_viewport(commands, plan, 1024, 684, 2048, 1368, 0, 2)
	assert storage.grids[0].tile_width == 2048
	assert storage.grids[0].tile_height == 352
	storage.update(commands, plan, 1024, 684, 0, 2)
	assert storage.grids[0].tile_width == 544
}

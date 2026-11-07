module main

import html
import layout

fn test_native_device_layout_retains_css_layout_for_embedded_user_spaces() {
	for markup in ['<svg><foreignObject><div>embedded</div></foreignObject></svg>',
		'<math></math>', '<iframe></iframe>', '<canvas></canvas>',
		'<video></video>'] {
		mut document := html.parse_document('<!doctype html>${markup}')
		assert !browser_document_supports_device_layout(document), markup
		document.finalize()
	}
	mut document := html.parse_document('<!doctype html><div><img src="image.svg"><input type="checkbox"></div>')
	defer { document.finalize() }
	assert browser_document_supports_device_layout(document)
}

fn test_native_device_layout_accepts_svg_viewports_and_graphic_user_spaces() {
	for markup in ['<svg></svg>',
		'<svg width="24" height="24" viewBox="0 0 24 24"><path d="M4 8L12 16L20 8"/></svg>',
		'<svg><defs><linearGradient id="g"><stop offset="0" stop-color="red"/></linearGradient></defs><g><svg><rect width="20" height="20" fill="url(#g)"/></svg></g></svg>'] {
		mut document := html.parse_document('<!doctype html>${markup}')
		assert browser_document_supports_device_layout(document), markup
		document.finalize()
	}
}

fn test_native_device_layout_rechecks_svg_foreign_object_visibility() {
	mut document := html.parse_document('<!doctype html><svg><foreignObject id="embedded" style="display:none"><div>embedded</div></foreignObject></svg>')
	defer { document.finalize() }
	mut embedded := document.get_element_by_id('embedded') or { panic('embedded') }
	assert browser_document_supports_device_layout(document)
	embedded.remove_attribute('style')
	assert !browser_document_supports_device_layout(document)
	embedded.set_attribute_value('style', 'display:none')
	assert browser_document_supports_device_layout(document)
}

fn test_native_device_layout_ignores_only_unboxed_embedded_user_spaces() {
	for markup in ['<iframe></iframe>', '<svg><foreignObject><canvas></canvas></foreignObject></svg>',
		'<math><mi>x</mi></math>', '<object></object><embed><video></video><audio></audio>'] {
		mut document := html.parse_document('<!doctype html><style>.hidden { display:none }</style><div class="hidden"><div style="display:block">${markup}</div></div>')
		assert browser_document_supports_device_layout(document), markup
		document.finalize()
	}
	for display in ['opacity:0', 'display:contents'] {
		mut document := html.parse_document('<!doctype html><div style="${display}"><iframe></iframe></div>')
		assert !browser_document_supports_device_layout(document), display
		document.finalize()
	}
}

// An embedding whose used visibility is hidden paints nothing, like the 1x1
// frame Cloudflare's JavaScript Detections add to 4chan with an inline
// visibility:hidden. A visible embedding inside a hidden ancestor, or hidden
// SVG and MathML user spaces whose descendants may become visible again, keep
// CSS-pixel layout.
fn test_native_device_layout_ignores_invisible_replaced_embeddings() {
	for markup in ['<iframe style="visibility:hidden"></iframe>',
		'<canvas style="visibility:hidden"></canvas>',
		'<object style="visibility:collapse"></object><embed style="visibility:hidden"><video style="visibility:hidden"></video><audio style="visibility:hidden"></audio>'] {
		mut document := html.parse_document('<!doctype html>${markup}')
		assert browser_document_supports_device_layout(document), markup
		document.finalize()
	}
	for markup in ['<div style="visibility:hidden"><iframe style="visibility:visible"></iframe></div>',
		'<div style="visibility:hidden"><math><mi>x</mi></math></div>',
		'<div style="visibility:hidden"><svg><foreignObject><div>embedded</div></foreignObject></svg></div>'] {
		mut document := html.parse_document('<!doctype html>${markup}')
		assert !browser_document_supports_device_layout(document), markup
		document.finalize()
	}
}

fn test_native_device_layout_rechecks_live_display_changes() {
	mut document := html.parse_document('<!doctype html><style>.hidden { display:none }</style><div id="slot" class="hidden"><iframe id="frame"></iframe></div>')
	defer { document.finalize() }
	mut slot := document.get_element_by_id('slot') or { panic('missing slot') }
	mut frame := document.get_element_by_id('frame') or { panic('missing frame') }
	assert browser_document_supports_device_layout(document)
	slot.remove_attribute('class')
	assert !browser_document_supports_device_layout(document)
	frame.set_attribute_value('style', 'display:none')
	assert browser_document_supports_device_layout(document)
	frame.remove_attribute('style')
	assert !browser_document_supports_device_layout(document)
	slot.set_attribute_value('class', 'hidden')
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

// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module layout

import css
import dom
import html
import painting

// Ladybird 241fe045563c6ada5a055d9f2b83d600f429abfc: direct paint
// resource-cache lookups obey the same decoded-SVG boundary as Fetch.
fn test_decoded_svg_image_paint_urls_do_not_reuse_external_raster_resources() {
	mut document := dom.Document.create(dom.URL{value: 'https://svg.test/image.svg'})
	defer { document.finalize() }
	mut image := document.create_element_ns('http://www.w3.org/2000/svg', 'image')!
	mut filter_image := document.create_element_ns('http://www.w3.org/2000/svg', 'feImage')!
	for isolated in [false, true] {
		document.set_is_svg_image_document(isolated)
		for address in ['https://svg.test/cached.png', '/cached.png', 'file:///cached.png',
			'blob:https://svg.test/cached', 'data:image/png,embedded'] {
			image.set_attribute_value('href', address)
			filter_image.set_attribute_value('href', address)
			allowed := !isolated || address.starts_with('data:')
			assert (resolved_svg_image_url(image) != '') == allowed
			graph_element := svg_element_model(filter_image)
			assert (graph_element.attributes['href'] != '') == allowed
		}
	}
}

fn test_decoded_svg_css_background_cache_and_masks_keep_the_resource_boundary() {
	mut document := html.parse_document('<!doctype html><div id="target"></div>')
	defer { document.finalize() }
	mut element := document.get_element_by_id('target') or { panic('target') }
	element.set_attribute_value('style', 'background-image:url(https://svg.test/cached.png);mask-image:url(https://svg.test/cached.png)')
	computed := css.StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	container := BlockContainer.new(document, element.as_node(), computed)
	node := unsafe { &Node(container) }
	assert resolve_css_paint_image_url(node, 'https://svg.test/cached.png', none) == 'https://svg.test/cached.png'
	document.set_is_svg_image_document(true)
	assert resolve_css_paint_image_url(node, 'https://svg.test/cached.png', none) == ''
	assert resolve_css_paint_image_url(node, 'data:image/png,embedded', none) == 'data:image/png,embedded'
	layers := computed_background_image_layers(node, element, computed,
		color_resolution_context_for_typed_node(node, node.computed_values().color()))
	assert layers.len == 1 && layers[0].url == ''
	mask := css_mask_image_for_box(element, computed, painting.Rect{0, 0, 100, 100}, node) or { panic('mask') }
	assert mask.operations.len == 1
	assert mask.operations[0].kind == .path && mask.operations[0].fill_opacity == 0
}

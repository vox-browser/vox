module layout

import html

fn test_chromium_fractional_image_attributes_quantize_after_device_projection() {
	mut document := html.parse_document('<!doctype html><img id="first" width="150" height="106.2"><img id="second" width="150" height="140.4"><img id="third" width="150" height="99.6">')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	for scale in [1.0, 2.0, 1.0] {
		document.set_layout_coordinate_scale(scale)
		run_document_layout(document, 800, 600) or { panic('layout') }
		for id, height in {
			'first': if scale == 2 { 106.1953125 } else { 106.1875 }
			'second': if scale == 2 { 140.3984375 } else { 140.390625 }
			'third': 99.59375
		} {
			image := document.get_element_by_id(id) or { panic(id) }
			rect := image.get_bounding_client_rect()
			assert rect.width == 150
			assert rect.height == height, '${id} at ${scale}x: ${rect.height}'
		}
	}
}

fn test_chromium_fractional_image_attributes_refresh_and_respect_author_css() {
	mut document := html.parse_document('<!doctype html><img id="image" width="150" height="106.2">')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_layout_coordinate_scale(2)
	mut image := document.get_element_by_id('image') or { panic('image') }
	run_document_layout(document, 800, 600) or { panic('initial') }
	assert image.get_bounding_client_rect().height == 106.1953125
	image.set_attribute_value('height', '140.4')
	run_document_layout(document, 800, 600) or { panic('attribute mutation') }
	assert image.get_bounding_client_rect().height == 140.3984375
	image.set_attribute_value('style', 'height:42.3px')
	run_document_layout(document, 800, 600) or { panic('author style') }
	assert image.get_bounding_client_rect().height == 42.296875
}

fn test_ladybird_fractional_image_attributes_keep_upstream_rounding() {
	mut document := html.parse_document('<!doctype html><img id="image" width="150" height="106.2">')
	defer { document.finalize() }
	run_document_layout(document, 800, 600) or { panic('layout') }
	image := document.get_element_by_id('image') or { panic('image') }
	assert image.get_bounding_client_rect().height == 106.203125
}

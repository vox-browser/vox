module layout

import html
import os

fn test_replaced_auto_height_uses_the_clamped_specified_width() {
	image := 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAD0lEQVR4nGNgaGBAIOI4ANA0CAF5jtVRAAAAAElFTkSuQmCC'
	for style, expected in {
		'width:200px;max-width:100px;height:auto':                 [f64(100), 100]
		'width:40px;min-width:120px;height:auto':                  [f64(120), 120]
		'width:200px;max-width:100px;height:60px':                 [f64(100), 60]
		'width:200px;max-width:100px;height:auto;max-height:60px': [f64(100), 60]
		'width:200px;max-width:100px;height:50%':                  [f64(100), 100]
		'width:200px;max-width:50%;height:auto':                   [f64(100), 100]
		'width:auto;height:40px;min-height:120px':                 [f64(120), 120]
	} {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}div{width:200px}img{${style}}</style><div><img id="target" src="${image}"></div>')
		defer { document.finalize() }
		_ = run_document_layout(document, 800, 600) or { panic('layout') }
		element := document.get_element_by_id('target') or { panic('image') }
		rect := element.get_bounding_client_rect()
		assert rect.width == expected[0], style
		assert rect.height == expected[1], style
	}
}

fn test_svg_spacer_clamp_propagates_its_height_through_positioned_image_wrappers() {
	markup := os.read_file(os.join_path(@DIR, '..', 'Tests/Browser/Brave/input/pikabu-clamped-svg-image.html'))!
	mut document := html.parse_document(markup)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = run_document_layout(document, 800, 600) or { panic('layout') }
	for id in ['frame', 'stretch', 'content', 'link', 'image'] {
		element := document.get_element_by_id(id) or { panic(id) }
		rect := element.get_bounding_client_rect()
		assert rect.width == 350, id
		assert rect.height == 316, id
	}
}

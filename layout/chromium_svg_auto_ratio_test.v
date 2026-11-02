module layout

import html
import dom

fn chromium_auto_svg_size(style string, chromium bool) []f64 {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}div{width:20px}svg{${style}}</style><div><svg id="icon" viewBox="0 0 448 512"><path d="M0 0H448V512H0Z"/></svg></div>')
	defer { document.finalize() }
	if chromium { document.set_font_rendering_policy(.chromium) }
	run_document_layout(document, 1024, 768) or { panic('layout') }
	icon := document.get_element_by_id('icon') or { panic('icon') }
	rect := icon.get_bounding_client_rect()
	return [rect.width, rect.height]
}

fn test_chromium_auto_svg_width_transfers_the_quantized_auto_height() {
	assert chromium_auto_svg_size('', true) == [19.984375, 22.84375]
	assert chromium_auto_svg_size('display:block', true) == [19.984375, 22.84375]
}

fn test_chromium_auto_svg_transfer_preserves_author_sizes_and_minimums() {
	assert chromium_auto_svg_size('width:20px', true) == [20.0, 22.84375]
	assert chromium_auto_svg_size('height:22.84375px', true) == [19.984375, 22.84375]
	assert chromium_auto_svg_size('min-width:20px', true) == [20.0, 22.84375]
}

fn test_libweb_auto_svg_keeps_its_upstream_ratio_width() {
	assert chromium_auto_svg_size('', false) == [20.0, 22.84375]
}

fn test_svg_image_keeps_its_explicit_viewport() {
	mut embedder := html.parse_document('<!doctype html>')
	defer { embedder.finalize() }
	mut image := parse_svg_image_document(SVGImageSource{
		source: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512"><path d="M0 0H448V512H0Z"/></svg>'
		url: dom.URL{ value: 'https://svg-ratio.test/icon.svg' }
	}, 'light', embedder)?
	defer { image.finalize() }
	image.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(image, 20, 22.84375)
	root := image.document_element() or { panic('SVG root') }
	rect := root.get_bounding_client_rect()
	assert [rect.width, rect.height] == [20.0, 22.84375]
}

module main

import dom
import encoding.base64
import html
import layout

fn test_native_svg_image_requests_keep_vectors_and_exact_viewbox_ratio() {
	source := '<?xml version="1.0"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 139 150"><path fill="green" d="M0 0H139V150H0Z"/></svg>'
	address := 'data:image/svg+xml;base64,' + base64.encode_str(source)
	mut document := parse_loaded_browser_navigation_document(LoadedPage{
		url: 'https://asgardpvp.com/'
		markup: '<!doctype html><style>html,body{margin:0}img{display:block;height:auto}</style><img id="picture" width="80" height="80" alt="fallback" src="${address}">'
	}, dom.URL{value: 'https://asgardpvp.com/'}, none, none, none, false)
	defer { document.finalize() }
	install_static_browser_image_fetch_hooks(document, map[string]bool{})
	image := unsafe { &dom.HTMLImageElement(document.get_element_by_id('picture')?) }
	model := html.html_image_element_model_for_dom_element(image)
	assert model.complete()
	assert model.is_image_available()
	assert model.event_count('error') == 0
	assert model.event_count('load') == 1
	decoded := model.decoded_image_data()?
	assert decoded is html.SVGDecodedImageData
	assert decoded.has_clients()
	assert decoded.frame(0) == none
	assert decoded.intrinsic_width() == none
	assert decoded.intrinsic_height() == none
	assert decoded.intrinsic_aspect_ratio()? == 139.0 / 150.0
	mut app := BrowserApp{document: document}
	app.relayout(1280, 912)
	placeholder := unsafe { &dom.Element(image) }.as_node().unsafe_layout_node()?
	box := unsafe { &layout.ImageBox(placeholder.real_layout_handle()) }
	assert box.svg_image_document() != none
	assert box.natural_size().aspect_ratio?.to_double() == 139.0 / 150.0
	rect := unsafe { &dom.Element(image) }.bounding_client_rect_assuming_layout_clean()
	assert rect.width == 80
	assert rect.height == 86.328125
	assert app.paint_commands.any(it.kind == 'paint_nested_display_list' && it.nested_viewport_commands.any(it.kind == 'draw_svg_path'))
}

fn test_native_svg_decode_validates_root_and_keeps_cors_and_absolute_dimensions() {
	address := dom.URL{value: 'https://images.example.test/icon.svg?v=2#view'}
	assert browser_image_resource_is_svg(address)
	decoded := browser_decoded_image_data(address,
		'<svg xmlns="http://www.w3.org/2000/svg" width="2in" height="48" viewBox="0 0 1 1"/>'.bytes())!
	assert decoded is html.SVGDecodedImageData
	assert decoded.is_cors_cross_origin()
	assert decoded.intrinsic_width()? == 192
	assert decoded.intrinsic_height()? == 48
	assert decoded.intrinsic_aspect_ratio()? == 4
	for invalid in ['<svg/>', '<html xmlns="http://www.w3.org/1999/xhtml"/>', '<svg xmlns="http://www.w3.org/2000/svg"><g></svg>', 'not an image'] {
		if _ := browser_decoded_image_data(address, invalid.bytes()) {
			assert false, 'Invalid SVG was accepted: ${invalid}'
		}
	}
}

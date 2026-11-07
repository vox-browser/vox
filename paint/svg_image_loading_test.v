module main

import adblock
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

// GitHub README badges come from camo.githubusercontent.com and shields.io
// URLs without a .svg name; the image/svg+xml response type selects SVG.
fn test_native_svg_decode_follows_the_response_content_type() {
	address := dom.URL{value: 'https://camo.githubusercontent.com/8a2a9f/68747470733a2f2f696d672e736869656c64732e696f'}
	assert !browser_image_resource_is_svg(address)
	badge := '<svg xmlns="http://www.w3.org/2000/svg" width="99" height="20"><rect width="99" height="20" fill="#555"/></svg>'
	if _ := browser_decoded_image_data(address, badge.bytes()) {
		assert false, 'An untyped extensionless SVG must not reach the raster decoders as SVG'
	}
	resource := PreloadedResource{
		url:              address.serialize()
		body:             badge
		response_headers: [adblock.ResponseHeader{name: 'Content-Type', value: 'image/svg+xml;charset=utf-8'}]
	}
	decoded := browser_decoded_resource_image(address, resource)!
	assert decoded is html.SVGDecodedImageData
	assert decoded.intrinsic_width()? == 99
	assert decoded.intrinsic_height()? == 20
	assert browser_response_mime_essence([adblock.ResponseHeader{name: 'content-type', value: ' Image/SVG+XML ; charset=utf-8'}]) == 'image/svg+xml'
}

// GitHub's README badges are SVG images whose <image> elements embed SVG logos
// as data URLs. The referenced document draws as a nested display list inside
// the image viewport rather than failing in the raster decoders.
fn test_svg_image_elements_draw_referenced_svg_documents() {
	logo := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="white" d="M0 0H24V24H0Z"/></svg>'
	address := 'data:image/svg+xml;base64,' + base64.encode_str(logo)
	mut document := parse_loaded_browser_navigation_document(LoadedPage{
		url: 'https://github.com/vlang/v'
		markup: '<!doctype html><style>html,body{margin:0}</style><svg width="99" height="20"><rect width="99" height="20" fill="#555"/><image x="5" y="3" width="14" height="14" href="${address}"/></svg>'
	}, dom.URL{value: 'https://github.com/vlang/v'}, none, none, none, false)
	defer { document.finalize() }
	mut app := BrowserApp{document: document}
	app.relayout(400, 300)
	nested := app.paint_commands.filter(it.kind == 'paint_nested_display_list')
	assert nested.len == 1
	assert nested[0].nested_viewport_commands.any(it.kind == 'draw_svg_path')
}

module main

import dom
import html
import layout

fn test_completed_background_svg_refreshes_paint_without_rebuilding_geometry() {
	address := 'https://svg-cache.example.test/sprite.svg?version=1'
	mut document :=
		html.parse_document('<!doctype html><style>body{margin:0}#target{width:30px;height:20px;background-image:url("${address}")}</style><div id="target"></div>')
	mut app := BrowserApp{
		document:                    document
		background_resource_results: chan PreloadedResource{cap: 2}
		background_resource_pending: {
			address: true
		}
	}
	app.relayout(200, 232)
	before := document.layout_root
	before_result := layout.document_layout_result(document) or { panic('missing layout') }
	before_root := before_result.root
	before_state := before_result.state
	assert !app.paint_commands.any(it.image().background_svg_document != none)
	app.background_resource_results <- PreloadedResource{
		url:  address
		body: '<svg xmlns="http://www.w3.org/2000/svg" width="30" height="20"><rect width="30" height="20" fill="red"/></svg>'
	}
	app.poll_background_resources()
	assert address !in app.background_resource_pending
	assert app.resource_cache[address].error == ''
	assert voidptr(document.layout_root) == voidptr(before)
	retained := layout.document_layout_result(document) or { panic('missing retained layout') }
	assert voidptr(retained.root) == voidptr(before_root)
	assert voidptr(retained.state) == voidptr(before_state)
	assert app.paint_commands.any(it.image().background_svg_document != none)
	first_svg := app.paint_commands.filter(it.image().background_svg_document != none)[0].image().background_svg_document or {
		panic('missing first SVG document')
	}

	first_rect := first_svg.document_element() or { panic('missing first SVG root') }
	assert first_rect.as_node().first_child()?.as_element()?.get_attribute_value('fill') == 'red'
	first_body := app.resource_cache[address].body
	app.background_resource_results <- PreloadedResource{
		url:  address
		body: first_body.replace('red', 'tan')
	}
	app.poll_background_resources()
	assert app.resource_cache[address].body.len == first_body.len
	second_svg := app.paint_commands.filter(it.image().background_svg_document != none)[0].image().background_svg_document or {
		panic('missing replacement SVG document')
	}

	assert second_svg != first_svg
	second_rect := second_svg.document_element() or { panic('missing replacement SVG root') }
	assert second_rect.as_node().first_child()?.as_element()?.get_attribute_value('fill') == 'tan'
	assert first_rect.as_node().first_child()?.as_element()?.get_attribute_value('fill') == 'red'
	app.background_resource_results <- PreloadedResource{
		url:   address
		error: 'replacement failed'
	}
	app.poll_background_resources()
	assert !app.paint_commands.any(it.image().background_svg_document != none)
	assert second_rect.as_node().first_child()?.as_element()?.get_attribute_value('fill') == 'tan'
	after := document.layout_root
	app.background_resource_results <- PreloadedResource{
		url:   'https://svg-cache.example.test/failed.svg'
		error: 'unavailable'
	}
	app.poll_background_resources()
	assert voidptr(document.layout_root) == voidptr(after)
	assert !publish_browser_svg_resource(PreloadedResource{
		url:  'https://svg-cache.example.test/picture.png'
		body: 'PNG'
	})
	assert !publish_browser_svg_resource(PreloadedResource{
		url:  'file:///sprite.svg'
		body: '<svg/>'
	})
	assert document.cached_display_list() != none
}

fn test_svg_completion_keeps_body_and_inline_background_geometry() {
	address := 'https://svg-cache.example.test/body-and-inline.svg'
	mut document := html.parse_document('<!doctype html><style>body{background:url("${address}");margin:0}span{background:url("${address}")}</style><span>inline background</span>')
	mut app := BrowserApp{document: document, background_resource_results: chan PreloadedResource{cap: 1}}
	app.relayout(200, 232)
	before := layout.document_layout_result(document) or { panic('missing layout') }
	root := before.root
	state := before.state
	app.background_resource_results <- PreloadedResource{url: address, body: '<svg xmlns="http://www.w3.org/2000/svg" width="8" height="6"><rect width="8" height="6" fill="red"/></svg>'}
	app.poll_background_resources()
	after := layout.document_layout_result(document) or { panic('missing retained layout') }
	assert voidptr(after.root) == voidptr(root)
	assert voidptr(after.state) == voidptr(state)
	assert app.paint_commands.any(it.image().background_svg_document != none)
	assert document.cached_display_list() != none
}

fn test_svg_completion_preserves_intrinsic_image_and_marker_layout_invalidation() {
	address := 'https://svg-cache.example.test/shared.svg?version=2'
	for markup in [
		'<img src="${address}#view" alt="pending">',
		'<img src="other.png" srcset="${address} 2x" alt="pending">',
		'<input type="image" src="${address}">',
		'<object data="${address}">fallback</object>',
		'<svg><image href="${address}"/></svg>',
		'<div style="content:url(${address})"></div>',
		'<ul style="list-style-image:url(${address})"><li>marker</li></ul>',
	] {
		mut document := html.parse_document_with_url('<!doctype html><style>body{background:url("${address}")}</style>${markup}', dom.URL{value:'https://svg-cache.example.test/page.html'})
		mut app := BrowserApp{document: document, background_resource_results: chan PreloadedResource{cap: 1}}
		app.relayout(200, 232)
		before := document.layout_root
		assert browser_svg_resources_need_layout(document, {address: true}), markup
		app.background_resource_results <- PreloadedResource{url: address, body: '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="32"><rect width="48" height="32" fill="red"/></svg>'}
		app.poll_background_resources()
		assert voidptr(document.layout_root) != voidptr(before), markup
		assert app.paint_commands.any(it.image().background_svg_document != none), markup
	}
	mut document := html.parse_document_with_url('<!doctype html><base href="https://svg-cache.example.test/"><img src="globe.png" srcset="globe@2x.png 2x"><div style="background:url(shared.svg?version=2)"></div>', dom.URL{value:'https://elsewhere.example.test/page.html'})
	mut app := BrowserApp{document: document}
	app.relayout(200, 232)
	assert !browser_svg_resources_need_layout(document, {address: true})
}

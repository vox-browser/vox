module main

import html
import layout

fn test_ready_initial_background_is_applied_before_first_paint_recording() {
	address := 'https://initial-background.test/ready.svg'
	document := html.parse_document('<!doctype html><div style="width:40px;height:20px;background:url(${address})"></div>')
	defer { document.finalize() }
	mut app := BrowserApp{document:document, background_resource_results:chan PreloadedResource{cap:1}}
	app.begin_frame_preparation()
	app.relayout(200, 232)
	before := layout.document_layout_result(document) or { panic('first layout') }
	root := voidptr(before.root)
	state := voidptr(before.state)
	app.background_resource_results <- PreloadedResource{
		url:address, body:'<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10"><rect width="20" height="10" fill="red"/></svg>'
	}
	app.finish_initial_ready_background_requests()
	assert app.background_resource_results.len == 0
	assert !app.document_presented
	app.finish_frame_preparation()
	after := layout.document_layout_result(document) or { panic('retained layout') }
	assert voidptr(after.root) == root && voidptr(after.state) == state
	assert app.paint_commands.any(it.image().background_static_svg_resource != none || it.image().background_svg_document != none)
}

fn test_initial_background_completion_does_not_consume_outside_first_preparation() {
	document := html.parse_document('<!doctype html><p>ordinary frame</p>')
	defer { document.finalize() }
	mut app := BrowserApp{document:document, background_resource_results:chan PreloadedResource{cap:1}}
	app.background_resource_results <- PreloadedResource{url:'https://initial-background.test/error.png', error:'fixture failure'}
	app.finish_initial_ready_background_requests()
	assert app.background_resource_results.len == 1
	app.relayout(200, 232)
	app.finish_initial_ready_background_requests()
	assert app.background_resource_results.len == 1
	app.begin_frame_preparation()
	app.document_presented = true
	app.finish_initial_ready_background_requests()
	assert app.background_resource_results.len == 1
}

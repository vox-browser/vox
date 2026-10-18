module main

import html

fn test_requested_capture_scroll_survives_the_initial_chrome_frame() {
	mut app := BrowserApp{
		screenshot_path:     'capture.png'
		screenshot_scroll_y: 1000
	}
	app.apply_screenshot_scroll_if_ready(600)
	assert !app.screenshot_scroll_applied
	assert app.scroll_y == 0
	mut document := html.parse_document(
		'<!doctype html><style>body{margin:0}div{height:100px}</style>' +
		'<div>row</div>'.repeat(30))
	defer { document.finalize() }
	app.document = document
	app.relayout(800, 600)
	app.apply_screenshot_scroll_if_ready(600)
	assert app.screenshot_scroll_applied
	assert app.scroll_y == 1000
	assert document.viewport_rect().y == 1000
	app.set_scroll_y(400, 600)
	app.apply_screenshot_scroll_if_ready(600)
	assert app.scroll_y == 400
}

fn test_requested_capture_scroll_waits_for_loading_and_then_clamps_to_final_content() {
	mut document :=
		html.parse_document('<!doctype html><style>body{margin:0}div{height:1200px}</style><div>content</div>')
	defer { document.finalize() }
	mut app := BrowserApp{
		document:            document
		screenshot_path:     'capture.png'
		screenshot_scroll_y: 99999
		load_status:         'Loading document'
	}
	app.relayout(800, 600)
	app.apply_screenshot_scroll_if_ready(600)
	assert !app.screenshot_scroll_applied
	assert app.scroll_y == 0
	app.load_status = 'HTTP 200'
	app.apply_screenshot_scroll_if_ready(600)
	assert app.screenshot_scroll_applied
	assert app.scroll_y == app.maximum_scroll(600)
	assert app.scroll_y > 0
	assert document.viewport_rect().y == app.scroll_y
}

module main

import html
import os

fn test_requested_capture_scroll_waits_for_initial_presentation_and_resources() {
	previous := os.getenv_opt('VOX_CAPTURE_INITIAL_VIEWPORT')
	os.setenv('VOX_CAPTURE_INITIAL_VIEWPORT', '1', true)
	defer {
		if value := previous {
			os.setenv('VOX_CAPTURE_INITIAL_VIEWPORT', value, true)
		} else {
			os.unsetenv('VOX_CAPTURE_INITIAL_VIEWPORT')
		}
	}
	mut document := html.parse_document('<!doctype html><style>body{margin:0}div{height:5000px}</style><div>content</div>')
	defer { document.finalize() }
	mut app := BrowserApp{
		document:            document
		screenshot_path:     'capture.png'
		screenshot_scroll_y: 3200
	}
	app.relayout(800, 600)
	document.update_readiness(.complete)
	loop := html.main_thread_event_loop()
	loop.update_font_face_sets_pending_on_the_environment([document])
	app.apply_screenshot_scroll_if_ready(600)
	assert !app.screenshot_scroll_applied
	assert app.screenshot_initial_viewport_pending()
	assert app.scroll_y == 0
	app.document_presented = true
	document.update_readiness(.interactive)
	app.note_screenshot_initial_viewport(true)
	app.apply_screenshot_scroll_if_ready(600)
	assert !app.screenshot_scroll_applied
	assert app.scroll_y == 0
	assert capture_retry_needs_frame(voidptr(&app)) == 0
	assert capture_scroll_retry_needs_frame(voidptr(&app)) == 1
	document.update_readiness(.complete)
	app.note_screenshot_initial_viewport(false)
	app.apply_screenshot_scroll_if_ready(600)
	assert !app.screenshot_scroll_applied
	app.note_screenshot_initial_viewport(true)
	assert app.screenshot_initial_viewport_ready
	// Animation sampling can dirty style before the next frame's layout.
	// The preceding completed frame already established initial readiness.
	mut body := document.body()?.as_node().as_element()?
	body.set_attribute_value('style', 'color:blue')
	app.apply_screenshot_scroll_if_ready(600)
	assert app.screenshot_scroll_applied
	assert !app.screenshot_initial_viewport_pending()
	assert app.scroll_y == 3200
}

fn test_requested_capture_scroll_survives_the_initial_chrome_frame() {
	mut app := BrowserApp{
		screenshot_path:     'capture.png'
		screenshot_scroll_y: 1000
	}
	app.apply_screenshot_scroll_if_ready(600)
	assert !app.screenshot_scroll_applied
	assert app.scroll_y == 0
	mut document := html.parse_document('<!doctype html><style>body{margin:0}div{height:100px}</style>' +
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

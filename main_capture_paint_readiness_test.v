module main

import dom
import gg

fn test_native_capture_waits_for_document_readiness_and_keeps_progressive_windows() {
	$if !macos { return }
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.update_readiness(.loading)
	mut app := &BrowserApp{document: document, ctx: &gg.Context{native_rendering: true}, screenshot_path: 'capture.png'}
	assert !app.document_pixels_ready_for_frame()
	app.screenshot_path = ''
	assert app.document_pixels_ready_for_frame()
	app.screenshot_path = 'capture.png'
	app.ctx = &gg.Context{native_rendering: false}
	assert app.document_pixels_ready_for_frame()
	app.ctx = &gg.Context{native_rendering: true}
	app.screenshot_scheduled = true
	assert app.document_pixels_ready_for_frame()
	app.screenshot_scheduled = false
	document.update_readiness(.complete)
	assert app.document_resources_ready_for_capture()
	assert app.document_pixels_ready_for_frame()
}

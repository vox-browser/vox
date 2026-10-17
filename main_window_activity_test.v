module main

import html

// Screenshot runs capture Chromium-policy documents like headless Chromium,
// without system focus; interactive sessions keep the window's state.
fn test_screenshot_runs_report_an_inactive_window() {
	mut document := html.parse_document('<!doctype html><input id="field">')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	mut app := BrowserApp{document: document}
	app.sync_window_activity()
	assert document.shows_focus_state()
	app.screenshot_path = '/tmp/capture.png'
	app.sync_window_activity()
	assert !document.shows_focus_state()
	app.screenshot_path = ''
	app.sync_window_activity()
	assert document.shows_focus_state()
}

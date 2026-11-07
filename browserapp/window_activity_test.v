module main

import html
import os

fn test_explicit_capture_focus_matches_a_focused_reference_without_changing_the_default() {
	previous := os.getenv_opt('VOX_CAPTURE_DOCUMENT_ACTIVE')
	defer {
		if value := previous { os.setenv('VOX_CAPTURE_DOCUMENT_ACTIVE',value,true) } else { os.unsetenv('VOX_CAPTURE_DOCUMENT_ACTIVE') }
	}
	mut document := html.parse_document('<!doctype html><input>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	mut app := BrowserApp{document:document,screenshot_path:'/tmp/focused-reference.png'}
	os.setenv('VOX_CAPTURE_DOCUMENT_ACTIVE','1',true)
	app.sync_window_activity()
	assert document.shows_focus_state()
	assert document.get_cursor_blink_state()
	assert !document.cursor_blink_timer.is_active()
	document.reset_cursor_blink_cycle()
	assert !document.cursor_blink_timer.is_active()
	os.setenv('VOX_CAPTURE_DOCUMENT_ACTIVE','0',true)
	app.sync_window_activity()
	assert !document.shows_focus_state()
	assert document.cursor_blink_timer.is_active()
}

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

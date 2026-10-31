module main

import dom
import os

$if macos {
	fn C.native_browser_window_is_active() int
}

// Report whether the browser window is focused and active. Documents under
// the Chromium policy show focus styles and carets only then. A screenshot
// run defaults to an unfocused document. Conformance launches can explicitly
// match a focused reference with VOX_CAPTURE_DOCUMENT_ACTIVE=1.
fn (mut app BrowserApp) sync_window_activity() {
	if app.document == unsafe { nil } {
		return
	}
	force_capture_focus := app.screenshot_path != '' && os.getenv('VOX_CAPTURE_DOCUMENT_ACTIVE') == '1'
	mut active := (app.screenshot_path == '' || force_capture_focus) && app.is_active_browser_tab()
	$if macos {
		if active && !force_capture_focus && app.ctx != unsafe { nil } && app.ctx.native_rendering {
			active = C.native_browser_window_is_active() != 0
		}
	}
	mut document := unsafe { &dom.Document(app.document) }
	document.set_embedder_window_active(active)
}

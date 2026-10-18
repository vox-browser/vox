module main

import dom

$if macos {
	fn C.native_browser_window_is_active() int
}

// Report whether the browser window is focused and active. Documents under
// the Chromium policy show focus styles and carets only then. A screenshot
// run captures like headless Chromium, whose page never has system focus.
fn (mut app BrowserApp) sync_window_activity() {
	if app.document == unsafe { nil } {
		return
	}
	mut active := app.screenshot_path == '' && app.is_active_browser_tab()
	$if macos {
		if active && app.ctx != unsafe { nil } && app.ctx.native_rendering {
			active = C.native_browser_window_is_active() != 0
		}
	}
	mut document := unsafe { &dom.Document(app.document) }
	document.set_embedder_window_active(active)
}

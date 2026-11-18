module main

import os

fn (app &BrowserApp) schedule_document_screenshot(path string) bool {
	$if macos {
		if path != '' && os.getenv('VOX_CAPTURE_DOCUMENT_ONLY') == '1' {
			C.schedule_native_document_screenshot(path, f64(app.page_top()), f64(app.viewport_width),
				f64(app.viewport_height), voidptr(app), native_document_capture_audit)
			return true
		}
	}
	return false
}

fn (mut app App) schedule_native_screenshot(path string) {
	if app.closed { return }
	$if macos {
		C.schedule_native_screenshot(path)
	}
	$if linux || windows {
		app.capture_portable_screenshot(path)
	}
}

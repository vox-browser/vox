module main

import os

// Diagnostic: reach the capture offset in CSS-pixel steps, one per frame, so
// the viewport scroll raster reuse path paints the intermediate frames. With
// VOX_CAPTURE_INITIAL_VIEWPORT=1 the capture itself waits for the final step.
const screenshot_scroll_step = os.getenv('VOX_SCREENSHOT_SCROLL_STEP').f64()

fn (app &BrowserApp) screenshot_initial_viewport_pending() bool {
	return os.getenv('VOX_CAPTURE_INITIAL_VIEWPORT') == '1'
		&& app.screenshot_scroll_y > 0 && !app.screenshot_scroll_applied
}

fn (mut app BrowserApp) note_screenshot_initial_viewport(painted bool) {
	if painted && app.screenshot_initial_viewport_pending()
		&& app.document_resources_ready_for_capture() {
		app.screenshot_initial_viewport_ready = true
	}
}

fn capture_scroll_retry_needs_frame(target voidptr) int {
	ready := capture_retry_needs_frame(target)
	app := unsafe { &BrowserApp(target) }
	// Initial lazy-image responses are adopted by the frame's task polling.
	// Keep requesting that work while the ordered capture is still at the top.
	if ready == 0 && app.screenshot_initial_viewport_pending() { return 1 }
	return ready
}

// The chrome's initial frame can precede navigation installation. Applying
// the requested capture offset there would clamp it to zero and consume it
// before the document exists.
fn (mut app BrowserApp) apply_screenshot_scroll_if_ready(window_height int) {
	if app.screenshot_path == '' || app.screenshot_scroll_applied || app.document == unsafe { nil }
		|| app.load_status.starts_with('Loading ') {
		return
	}
	// Reference captures can settle the initial viewport before scrolling.
	// Its first frame starts nearby lazy-image requests; wait for those and
	// fonts before moving them out of range. Ordinary jump captures stay eager.
	if app.screenshot_initial_viewport_pending() && !app.screenshot_initial_viewport_ready {
		return
	}
	if screenshot_scroll_step > 0
		&& app.scroll_y + screenshot_scroll_step < f64(app.screenshot_scroll_y) {
		app.set_scroll_y(app.scroll_y + screenshot_scroll_step, window_height)
		return
	}
	app.screenshot_scroll_applied = true
	app.set_scroll_y(f64(app.screenshot_scroll_y), window_height)
}

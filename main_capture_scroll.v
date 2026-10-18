module main

// The chrome's initial frame can precede navigation installation. Applying
// the requested capture offset there would clamp it to zero and consume it
// before the document exists.
fn (mut app BrowserApp) apply_screenshot_scroll_if_ready(window_height int) {
	if app.screenshot_path == '' || app.screenshot_scroll_applied || app.document == unsafe { nil }
		|| app.load_status.starts_with('Loading ') {
		return
	}
	app.screenshot_scroll_applied = true
	app.set_scroll_y(f64(app.screenshot_scroll_y), window_height)
}

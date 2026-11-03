module main

// Bookmark preferences determine the browser chrome's final height. Resolve
// the initial document viewport after loading those preferences, before local
// page installation or asynchronous navigation can construct any geometry.
fn (mut app BrowserApp) prepare_initial_viewport(window_height int, screenshot_height int) {
	app.viewport_height = if screenshot_height > 0 {
		screenshot_height
	} else if window_height > app.chrome_height() {
		window_height - app.chrome_height()
	} else {
		1
	}
}

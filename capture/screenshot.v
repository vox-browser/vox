module main

fn (mut app App) schedule_native_screenshot(path string) {
	if app.closed { return }
	$if macos {
		C.schedule_native_screenshot(path)
	}
	$if linux || windows {
		app.capture_portable_screenshot(path)
	}
}

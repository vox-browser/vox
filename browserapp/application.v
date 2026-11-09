module main

import adblock
import platform

// App owns services that live for the browser window/process, across tab and
// document replacement. BrowserApp holds one tab's state; every tab in a window
// shares this owner instead of reaching process globals.
@[heap]
struct App {
mut:
	filter_cleanup_timer ?&platform.Timer
	portable_screenshot  PortableScreenshotState
	closed               bool
}

fn new_app() &App {
	// Tests and embedders may create a browser while a document arena is active.
	// Application services must outlive that document's allocation scope.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return &App{}
}

fn (mut app App) arm_filter_memory_cleanup() {
	if app.closed || app.filter_cleanup_timer != none {
		return
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut timer := platform.Timer.create_repeating(1000, fn () {
		adblock.release_default_engine_if_idle(5000)
	})
	app.filter_cleanup_timer = timer
	timer.start()
}

fn (mut app App) close() {
	if app.closed {
		return
	}
	app.closed = true
	if mut timer := app.filter_cleanup_timer {
		timer.stop()
	}
	app.filter_cleanup_timer = none
	app.portable_screenshot = PortableScreenshotState{}
}

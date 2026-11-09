module main

import os
import platform
import sokol.sapp
import time

$if linux || windows {
	#include "@VMODROOT/native/include/native_browser_portable.h"

	fn (mut app App) capture_portable_screenshot(path string) {
		seconds := os.getenv_opt('SCREENSHOT_SETTLE_SECONDS') or { '2' }
		// A request made during a frame must survive the frame's scratch arena.
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		app.portable_screenshot.schedule(path, time.sys_mono_now(), i64(seconds.f64() * time.second))
	}

	fn (app &App) finish_portable_frame() {
		path := app.portable_screenshot.ready_path(time.sys_mono_now()) or { return }
		sapp.screenshot_png(path) or {
			eprintln('Vox screenshot: ${err.msg()}')
			exit(1)
		}
		exit(0)
	}

	fn pump_portable_browser_events() {
		platform.pump_native_events(0)
	}
}

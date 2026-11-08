module main

import os
import platform
import sokol.sapp
import time

$if linux || windows {
	#include "@VMODROOT/native_browser_portable.h"

	__global (
		portable_screenshot_path string
		portable_screenshot_due i64
	)

	fn capture_portable_screenshot(path string) {
		portable_screenshot_path = path
		seconds := os.getenv_opt('SCREENSHOT_SETTLE_SECONDS') or { '2' }
		portable_screenshot_due = time.sys_mono_now() + i64(seconds.f64() * time.second)
	}

	fn finish_portable_frame() {
		if portable_screenshot_path == '' || time.sys_mono_now() < portable_screenshot_due { return }
		sapp.screenshot_png(portable_screenshot_path) or {
			eprintln('Vox screenshot: ${err.msg()}')
			exit(1)
		}
		exit(0)
	}

	fn pump_portable_browser_events() {
		platform.pump_native_events(0)
	}
}

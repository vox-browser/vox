module main

import os
import platform
import sokol.sapp
import time

#include "@VMODROOT/native_browser_linux.h"

__global (
	linux_screenshot_path string
	linux_screenshot_due i64
)

fn capture_linux_screenshot(path string) {
	linux_screenshot_path = path
	seconds := os.getenv_opt('SCREENSHOT_SETTLE_SECONDS') or { '2' }
	linux_screenshot_due = time.sys_mono_now() + i64(seconds.f64() * time.second)
}

fn finish_linux_frame() {
	if linux_screenshot_path == '' || time.sys_mono_now() < linux_screenshot_due { return }
	sapp.screenshot_png(linux_screenshot_path) or {
		eprintln('Vox screenshot: ${err.msg()}')
		exit(1)
	}
	exit(0)
}

fn pump_linux_browser_events() {
	platform.pump_native_events(0)
}

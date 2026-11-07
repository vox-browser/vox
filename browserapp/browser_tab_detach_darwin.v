module main

import browserui
import browserwindow
import os

fn position_detached_browser_window(x f64, y f64) {
	if os.getenv('VOX_TEST_WINDOW') != '' { return }
	width, height := browserwindow.key_window_size()
	frame := browserui.detached_frame(x, y, width, height, browser_window_displays())
	browserwindow.position_key_window(frame.x, frame.y + frame.height)
}

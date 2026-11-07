module main

import browserui
import os

#include "@VMODROOT/native_browser_tab_detach_darwin.m"

fn C.native_open_tab_window(executable &u8, session &u8) bool
fn C.native_tab_drop_x() f64
fn C.native_tab_drop_y() f64
fn C.native_position_detached_frame(x f64, top f64)
fn C.native_detached_window_size(width &f64, height &f64)

fn position_detached_browser_window(x f64, y f64) {
	if os.getenv('VOX_TEST_WINDOW') != '' { return }
	mut width := 0.0
	mut height := 0.0
	C.native_detached_window_size(&width, &height)
	frame := browserui.detached_frame(x, y, width, height, browser_window_displays())
	C.native_position_detached_frame(frame.x, frame.y + frame.height)
}

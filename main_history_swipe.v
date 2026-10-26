module main

import page

$if macos {
	#include "native_history_swipe_darwin.h"
	fn C.native_history_swipe_install(window voidptr, owner voidptr,
		begin fn (voidptr, i32, f64, f64, f64, f64, &voidptr) i32,
		commit fn (voidptr, voidptr, i32))
	fn C.native_history_swipe_remove()
}

// The first horizontal wheel event gets the ordinary DOM/default-action path.
// Only an uncancelled, unconsumed delta can become a history swipe.
fn begin_browser_history_swipe(owner voidptr, delta i32, x f64, y f64,
	wheel_x f64, wheel_y f64, document_token &voidptr) i32 {
	mut shell := unsafe { &BrowserApp(owner) }
	mut app := shell.active_browser_tab()
	client := page.PixelPoint{x, y - app.page_top()}
	if delta !in [-1, 1] || app.navigation_work_depth > 0 || app.document == unsafe { nil }
		|| client.x < 0 || client.y < 0 || client.x >= app.viewport_width
		|| client.y >= app.viewport_height || app.history_index + delta < 0
		|| app.history_index + delta >= app.history.len {
		return 0 // Leave ordinary input with Sokol.
	}
	document := voidptr(app.document)
	mut screen_x := x
	mut screen_y := y
	$if macos {
		C.native_pointer_screen_position(x, y, &screen_x, &screen_y)
	}
	// Match Sokol's precise-wheel scaling (0.1) and the browser's 42px step.
	result := app.handle_wheel_input(client, page.PixelPoint{screen_x, screen_y},
		0, 0, 0, -wheel_x * 4.2, -wheel_y * 4.2, false, true)
	request_browser_frame()
	if result != .accepted || voidptr(shell.active_browser_tab()) != voidptr(app)
		|| voidptr(app.document) != document {
		return 1 // Already dispatched: do not deliver the same wheel twice.
	}
	unsafe { *document_token = document }
	return 2
}

fn commit_browser_history_swipe(owner voidptr, document_token voidptr, delta i32) {
	mut shell := unsafe { &BrowserApp(owner) }
	mut app := shell.active_browser_tab()
	// A tab switch, navigation or close during tracking invalidates the gesture.
	// Compare the token only; its former document may already have been released.
	if delta !in [-1, 1] || document_token == unsafe { nil }
		|| voidptr(app.document) != document_token || app.navigation_work_depth > 0 {
		return
	}
	app.activate_browser_chrome(if delta < 0 { 'back' } else { 'forward' })
}

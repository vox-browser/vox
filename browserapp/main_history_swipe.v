module main

import page
import browserui

$if macos {
	import browserwindow
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

fn install_browser_history_swipe(window voidptr, owner voidptr) {
	$if macos {
		browserwindow.install_history_swipe(window, owner, begin_browser_history_swipe, filter_browser_history_swipe, capture_browser_history_swipe, progress_browser_history_swipe)
	}
}

fn filter_browser_history_swipe(owner voidptr, phase i32, momentum i32, precise i32, enabled i32, modifiers u32, x f64, y f64) i32 {
	mut app := unsafe { &BrowserApp(owner) }
	mut state := app.browser_ui()
	return i32(state.swipe.filter(browserui.SwipeInput{ phase: int(phase), momentum: momentum != 0, precise: precise != 0, enabled: enabled != 0, modifiers: modifiers, x: x, y: y }))
}

fn capture_browser_history_swipe(owner voidptr, expected u64) u64 {
	mut app := unsafe { &BrowserApp(owner) }
	mut state := app.browser_ui()
	if expected == 0 { return state.swipe.candidate }
	return state.swipe.capture_candidate(expected)
}

fn progress_browser_history_swipe(owner voidptr, document voidptr, generation u64, amount f64, phase i32, complete i32, delta i32) i32 {
	mut app := unsafe { &BrowserApp(owner) }
	mut state := app.browser_ui()
	decision := state.swipe.progress(generation, amount, int(phase), complete != 0, int(delta))
	if decision == 1 { commit_browser_history_swipe(owner, document, delta) }
	return i32(decision != 0)
}

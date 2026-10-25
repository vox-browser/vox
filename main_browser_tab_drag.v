module main

import gg
import math

fn (app &BrowserApp) browser_tab_index(tab &BrowserApp) int {
	if app.tabs != unsafe { nil } {
		for i, candidate in app.tabs.pages {
			if voidptr(candidate) == voidptr(tab) { return i }
		}
	}
	return -1
}

// Capture the whole gesture before page pointer dispatch, including a release
// over the document. GG delivers its separate click callback after mouse-down.
fn (mut app BrowserApp) handle_browser_tab_drag(event &gg.Event, width int) bool {
	if event.typ == .mouse_down && event.mouse_button == .left && app.tabs != unsafe { nil } {
		app.tabs.drag = none
	}
	if event.typ == .mouse_down && event.mouse_button == .left
		&& event.mouse_y >= 0 && event.mouse_y < tab_strip_height {
		app.initialize_browser_tabs()
		first, end := browser_visible_tabs(width, app.tabs.pages.len, app.tabs.selected)
		tab_width := browser_tab_width(width, end - first)
		index := first + int(math.floor((f64(event.mouse_x) - tab_strip_leading_width) / tab_width))
		if index < first || index >= end { return false }
		left := tab_strip_leading_width + f64(index - first) * tab_width
		// Leave the close button's existing click action alone.
		if event.mouse_x >= left + tab_width - 30 { return false }
		app.tabs.drag = BrowserTabDrag{
			page: app.tabs.pages[index]
			first: first
			end: end
			width: tab_width
			start: event.mouse_x
			offset: f64(event.mouse_x) - left
			x: event.mouse_x
			target: index
		}
		app.activate_tab_chrome('tab-select:${index}')
		app.suppress_next_click_for_chrome = true
		mut active := app.active_browser_tab()
		active.suppress_next_click_for_chrome = true
		return true
	}
	if app.tabs == unsafe { nil } { return false }
	mut drag := app.tabs.drag or { return false }
	if event.typ == .mouse_leave {
		drag.cancelled = true
		drag.moving = false
		app.tabs.drag = drag
		request_browser_frame()
		return false
	}
	if event.typ != .mouse_move && !(event.typ == .mouse_up && event.mouse_button == .left) {
		return false
	}
	drag.x = event.mouse_x
	drag.moving = !drag.cancelled && (drag.moving || math.abs(drag.x - drag.start) >= 4)
	drag.target = math.max(drag.first, math.min(drag.end - 1,
		drag.first + int(math.floor((drag.x - tab_strip_leading_width) / drag.width))))
	app.tabs.drag = drag
	if event.typ == .mouse_up {
		app.tabs.drag = none
		if drag.moving && event.mouse_y >= 0 && event.mouse_y < tab_strip_height {
			from := app.browser_tab_index(drag.page)
			app.activate_tab_chrome('tab-move:${from}:${drag.target}')
		}
	}
	request_browser_frame()
	return true
}

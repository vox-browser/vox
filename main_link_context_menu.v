module main

import browserui
import platform
import time

// The page context menu: link actions over links, and Inspect over any
// document content, as in Chrome.
fn (mut app BrowserApp) show_link_context_menu(x f32, y f32) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if y < app.page_top() || y >= app.page_top() + f32(app.viewport_height) { return }
	destination := app.link_at_point(x, y) or { '' }
	app.dismiss_browser_popup()
	mut state := app.browser_ui()
	state.link = destination.clone()
	app.remember_devtools_inspect_target(x, y)
	mut rows := []browserui.MenuRow{}
	if destination != '' {
		rows << browserui.MenuRow{ id: 'link-open', text: 'Open Link in New Tab' }
		rows << browserui.MenuRow{ id: 'link-copy', text: 'Copy Link URL' }
		rows << browserui.MenuRow{ separator: true }
	}
	rows << browserui.MenuRow{ id: 'inspect', text: 'Inspect' }
	state.version++
	state.popup = browserui.Popup{
		token: u64(time.sys_mono_now())
		x:     x
		y:     y
		rows:  rows
	}
	app.refresh_browser_ui()
}

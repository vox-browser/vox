module main

import browserui
import platform
import time

fn (mut app BrowserApp) show_link_context_menu(x f32, y f32) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	destination := app.link_at_point(x, y) or { return }
	app.dismiss_browser_popup()
	mut state := app.browser_ui()
	state.link = destination.clone()
	state.version++
	state.popup = browserui.Popup{
		token: u64(time.sys_mono_now())
		x:     x
		y:     y
		rows:  [
			browserui.MenuRow{ id: 'link-open', text: 'Open Link in New Tab' },
			browserui.MenuRow{ id: 'link-copy', text: 'Copy Link URL' },
		]
	}
	app.refresh_browser_ui()
}

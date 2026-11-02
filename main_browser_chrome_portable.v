module main

import gg
import ui2
import platform

$if !vox_ui2 ? {
	fn (mut app BrowserApp) draw_portable_browser_chrome(window gg.Size) {
		$if linux || ui2_custom_rendering ? {
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { address_bar_owner }
			owner.app = app
			mut ui_state := app.browser_ui()
			if ui_state.memory_timer == unsafe { nil } { app.start_browser_memory_chrome() }
			chrome := app.browser_chrome_state(window.width, window.height)
			app.browser_chrome = chrome
			mut images := map[string]int{}
			for index, icon in chrome.bookmark_favicons {
				if icon < 0 { continue }
				items := app.browser_bar_bookmarks()
				if index < items.len {
					images[app.browser_bookmark_icon_path(items[index].url, icon)] = icon
				}
			}
			for index, icon in chrome.tab_favicons {
				if icon >= 0 { images[app.browser_tab_icon_path(index, chrome)] = icon }
			}
			ui2.on_key_event(browser_ui_key)
			ui2.install_embedded_wheel(browser_ui_scroll)
			ui2.draw_embedded_elements(app.ctx, app.browser_chrome_ui_elements(chrome), images, browser_ui_event)
			app.focus_browser_tab_title_editor()
		}
	}
}

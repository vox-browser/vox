module main

import gg
import ui2
import platform
import browserui

// Prepare textures before the frame enters its render pass. Their ownership
// stays with the GG context; UI2 and the Vinix adapter borrow the image IDs.
fn (mut app BrowserApp) prepare_browser_navigation_icons() {
	$if !vox_ui2 ? {
		$if linux || ui2_custom_rendering ? {
			if app.ctx == unsafe { nil } || app.ctx.native_rendering { return }
			mut state := app.browser_ui()
			if state.navigation_images.len == 6 { return }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			browserui.prepare_navigation_images(mut app.ctx, mut state.navigation_images)
		}
	}
}

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
			app.sync_browser_tab_loading_animation(chrome)
			mut images := map[string]int{}
			for path, id in ui_state.navigation_images { images[path] = id }
			for index, icon in chrome.bookmark_favicons {
				if icon < 0 { continue }
				items := app.bookmarks.items
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
			app.focus_browser_find_bar()
			app.finish_devtools_render()
		}
	}
}

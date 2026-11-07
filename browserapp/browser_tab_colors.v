module main

import browsersettings
import browsertabs
import browserui
import platform
import time

fn (app &BrowserApp) browser_tab_identity(index int) string {
	if app.process_tabs() {
		if index < 0 || index >= app.tabs.session.state.tabs.len { return '' }
		return app.tabs.session.state.tabs[index].id
	}
	if app.tabs == unsafe { nil } {
		return if index == 0 { 'local-${u64(voidptr(app))}' } else { '' }
	}
	if index < 0 || index >= app.tabs.pages.len { return '' }
	return 'local-${u64(voidptr(app.tabs.pages[index]))}'
}

fn (app &BrowserApp) browser_tab_colors() []browsertabs.TabColor {
	if app.process_tabs() { return app.tabs.session.state.tabs.map(it.color) }
	if app.tabs == unsafe { nil } { return [app.browser_ui().tab_color] }
	return app.tabs.pages.map(it.browser_ui().tab_color)
}

// Resolve the owner again at completion: menu indices can move or disappear.
fn (app &BrowserApp) browser_tab_index_for_identity(target string) int {
	for index in 0 .. app.browser_tab_count() {
		if app.browser_tab_identity(index) == target { return index }
	}
	return -1
}

fn (mut app BrowserApp) show_tab_color_menu(target string) {
	if !browsersettings.current().enable_tab_coloring { return }
	index := app.browser_tab_index_for_identity(target)
	if index < 0 { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	app.dismiss_browser_popup()
	mut state := app.browser_ui()
	state.tab_color_target = target.clone()
	colors := app.browser_tab_colors()
	first, end := browser_visible_tabs(app.browser_chrome.width, colors.len, app.browser_selected_tab())
	state.popup = browserui.Popup{
		token: u64(time.sys_mono_now())
		x: tab_strip_leading_width + f64(index - first) * browser_tab_width(app.browser_chrome.width, end - first)
		y: tab_strip_height
		rows: browserui.tab_color_rows(colors[index])
		active: int(colors[index]) + 1
	}
	state.version++
	app.refresh_browser_ui()
}

fn (mut app BrowserApp) complete_tab_color_menu(name string) {
	if !browsersettings.current().enable_tab_coloring { return }
	color := browsertabs.TabColor.from_string(name) or { return }
	target := app.browser_ui().tab_color_target
	index := app.browser_tab_index_for_identity(target)
	if index < 0 { return }
	if app.process_tabs() {
		app.tabs.session.set_color(target, color) or {
			app.status = 'Could not set tab color: ${err.msg()}'
			return
		}
	} else {
		mut tab := if app.tabs == unsafe { nil } { &app } else { app.tabs.pages[index] }
		mut state := tab.browser_ui()
		state.tab_color = color
	}
	app.invalidate_tab_customization_snapshot()
}

fn (mut app BrowserApp) invalidate_tab_customization_snapshot() {
	app.snapshot_cached = false
	app.snapshot_hold = false
	app.snapshot_hold_until = 0
	app.snapshot_visible = false
	$if macos { C.native_hide_cached_snapshot() }
}

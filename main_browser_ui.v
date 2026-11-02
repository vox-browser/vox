module main

import browserui
import browsertabs
import dom
import platform
import ui2
import gg
import sokol.sapp
import math
import time

@[heap]
struct BrowserUIState {
mut:
	window_clicks   browserui.WindowClicks
	swipe           browserui.Swipe
	memory_label    string
	memory_timer    &platform.Timer = unsafe { nil }
	version         u64
	popup           ?browserui.Popup
	link            string
	select_node     &dom.Node = unsafe { nil }
	select_document dom.UniqueNodeID
	tab_color       browsertabs.Color
	tab_color_target string
}

fn (app &BrowserApp) browser_ui() &BrowserUIState {
	if app.browser_ui_ != unsafe { nil } { return app.browser_ui_ }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut owner := unsafe { &BrowserApp(app) }
	owner.browser_ui_ = &BrowserUIState{}
	return owner.browser_ui_
}

fn (mut app BrowserApp) refresh_browser_ui() {
	app.update_browser_chrome(app.browser_chrome.width, app.browser_chrome.height)
	request_browser_frame()
}

fn (app &BrowserApp) browser_popup_elements(width int, height int) []ui2.Element {
	state := app.browser_ui()
	if popup := state.popup { return popup.elements(f64(width), f64(height)) }
	return []ui2.Element{}
}

fn (mut app BrowserApp) dismiss_browser_popup() {
	if app.browser_ui_ == unsafe { nil } { return }
	mut state := app.browser_ui()
	if state.select_node != unsafe { nil } && app.document != unsafe { nil }
		&& state.select_document == app.document.unique_id() {
		app.close_browser_select_picker(state.select_node)
	}
	state.select_node = unsafe { nil }
	state.link = ''
	state.tab_color_target = ''
	state.popup = none
	state.version++
}

fn (mut app BrowserApp) browser_popup_action(action string) {
	mut state := app.browser_ui()
	popup := state.popup or { return }
	parts := action.split(':')
	if parts.len != 3 || parts[1].u64() != popup.token { return }
	id := parts[2]
	if id != 'dismiss' && !popup.rows.any(it.id == id && it.enabled && !it.group && !it.separator) {
		return
	}
	link := state.link
	if id.starts_with('tab-color-') {
		app.complete_tab_color_menu(id.all_after('tab-color-'))
		app.dismiss_browser_popup()
		app.refresh_browser_ui()
		return
	}
	if id.starts_with('select-') {
		app.complete_browser_select_picker(id.all_after('select-').u32())
		app.dismiss_browser_popup()
		app.refresh_browser_ui()
		return
	}
	app.dismiss_browser_popup()
	app.refresh_browser_ui()
	if id == 'link-open' { app.activate_tab_chrome('tab-open-background:${link}') }
	if id == 'link-copy' {
		$if vox_ui2 ? {
			ui2.copy_embedded_text(link)
		}
		$if linux || ui2_custom_rendering ? {
			ui2.copy_embedded_text(link)
		}
	}
}

fn (mut app BrowserApp) handle_browser_popup_key(key string) bool {
	mut state := app.browser_ui()
	mut popup := state.popup or { return false }
	if key !in ['up', 'down', 'home', 'end', 'enter', 'space', 'escape', 'tab'] { return false }
	action := if key == 'tab' { 'browser-menu:${popup.token}:dismiss' } else { popup.key(key) }
	state.popup = popup
	state.version++
	if action != '' {
		app.browser_popup_action(action)
	} else {
		app.refresh_browser_ui()
		ui2.scroll_to_rect('browser-menu-list', 0, f64(popup.active) * 28, popup.width, 28)
	}
	return true
}

fn browser_ui_event(event string) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if address_bar_owner.app == unsafe { nil } { return }
	mut app := address_bar_owner.app.active_browser_tab()
	if event == 'host-reopen' {
		app.request_browser_reopen()
		return
	}
	if event.starts_with('pointer:') {
		parts := event.split(':')
		if parts.len != 5 { return }
		if parts[2].starts_with('tabdrag-') {
			if parts[1] == 'middle' {
				app.activate_tab_chrome('tab-close:${parts[2].all_after('tabdrag-')}')
				return
			}
			typ := match parts[1] {
				'down' { sapp.EventType.mouse_down }
				'drag' { sapp.EventType.mouse_move }
				else { sapp.EventType.mouse_up }
			}
			app.handle_browser_tab_drag_target(&gg.Event{ typ: typ, mouse_button: .left, mouse_x: f32(parts[3].f64()), mouse_y: f32(parts[4].f64()) }, app.browser_chrome.width, parts[2].all_after('tabdrag-').int())
			mut ui_state := app.browser_ui()
			ui_state.version++
			app.refresh_browser_ui()
		}
		$if vox_ui2 ?|| linux {
			if parts[2] == 'window-drag' && parts[1] == 'down' {
				mut state := app.browser_ui()
				double_click := state.window_clicks.press(time.sys_mono_now(), parts[3].f64(), parts[4].f64())
				ui2.embedded_host_action(if double_click { 'zoom' } else { 'drag' })
			}
		}
		return
	}
	if event.starts_with('tabdrag-') {
		app.activate_tab_chrome('tab-select:${event.all_after('tabdrag-')}')
		return
	}
	if event.starts_with('window-') {
		$if vox_ui2 ?|| linux {
			ui2.embedded_host_action(event.all_after('window-'))
		}
		return
	}
	if event == 'address-change' {
		if app.address_bar_editable() {
			app.address = ui2.text('address')
		} else {
			app.sync_address_bar()
		}
		return
	}
	if event == 'panel-close:settings' {
		browser_settings_event(event)
		return
	}
	if event.starts_with('settings-') {
		browser_settings_event(event)
		app.refresh_browser_ui()
		return
	}
	app.activate_browser_chrome(event)
}

fn browser_ui_key(event ui2.KeyEvent) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if address_bar_owner.app == unsafe { nil } { return }
	mut app := address_bar_owner.app.active_browser_tab()
	mut settings_keys := browser_settings_visible()
	$if vox_ui2 ? {
		settings_keys = settings_keys && ui2.embedded_key_panel() == 'settings'
	}
	if settings_keys && event.code in [.escape, .w] && (event.code == .escape || event.cmd || event.ctrl) {
		close_browser_settings()
		ui2.consume_key()
		return
	}
	if app.handle_browser_popup_key(event.code.name()) {
		ui2.consume_key()
		return
	}
	if settings_keys { return }
	editing := app.address_active || ui2.focused_id() == 'address'
	action := browserui.shortcut(event, editing, $if macos { true } $else { false })
	if action == '' { return }
	$if vox_ui2 ? {
		if ui2.embedded_key_repeat() && action in ['bookmarks-toggle', 'bookmark-add', 'debug-toggle',
			'tab-new', 'tab-close'] {
			ui2.consume_key()
			return
		}
	}
	ui2.consume_key()
	match action {
		'address-focus' { app.focus_address_bar() }
		'address-cancel' { app.cancel_address_bar() }
		'debug-toggle' { app.toggle_browser_debug() }
		'settings-open' { show_browser_settings() }
		else {
			if action.starts_with('zoom-') {
				app.activate_browser_zoom(action)
			} else {
				app.activate_browser_chrome(action)
			}
		}
	}
	request_browser_frame()
}

fn browser_ui_scroll(_ f64, y f64, dx f64, dy f64) bool {
	if y < 0 || y >= tab_strip_height || address_bar_owner.app == unsafe { nil } { return false }
	mut app := address_bar_owner.app.active_browser_tab()
	if app.browser_ui().popup != none { return false }
	delta := if math.abs(dx) > math.abs(dy) { dx } else { dy }
	if math.abs(delta) > 0.5 {
		app.activate_tab_chrome(if delta > 0 { 'tab-previous' } else { 'tab-next' })
	}
	return true
}

module main

import adblock
import browsertabs
import browsersettings
import encoding.base64
import os
import platform
import sokol.sapp
import time
import ui2

$if macos {
	#include "@VMODROOT/native_browser_tab_process_darwin.m"
	fn C.vox_tab_window_prepare(voidptr)
	fn C.vox_tab_window_frame(voidptr, &f64)
	fn C.vox_tab_window_show(voidptr, i32, f64, f64, f64, f64)
} $else $if linux {
	#include "@VMODROOT/native_browser_tab_process_linux.h"
	fn C.vox_tab_x11_frame(voidptr, uint, &f64)
	fn C.vox_tab_x11_show(voidptr, uint, i32, f64, f64, f64, f64)
}

fn (app &BrowserApp) process_tabs() bool {
	return app.tabs != unsafe { nil } && app.tabs.session != unsafe { nil }
}

fn (mut app BrowserApp) request_browser_reopen() {
	if app.process_tabs() {
		app.tabs.session.request_reopen() or { eprintln('Vox: cannot reopen window: ${err}') }
	} else {
		$if vox_ui2 ? { ui2.embedded_host_action('show') }
	}
	request_browser_frame()
}

fn (app &BrowserApp) browser_tab_count() int {
	if app.process_tabs() { return app.tabs.session.state.tabs.len }
	return if app.tabs != unsafe { nil } { app.tabs.pages.len } else { 1 }
}

fn (app &BrowserApp) browser_selected_tab() int {
	if app.process_tabs() { return app.tabs.session.selected_index() }
	return if app.tabs != unsafe { nil } { app.tabs.selected } else { 0 }
}

fn process_tab_window_frame() browsertabs.Frame {
	mut values := [4]f64{}
	$if macos {
		C.vox_tab_window_frame(sapp.macos_get_window(), &values[0])
	} $else $if linux {
		C.vox_tab_x11_frame(sapp.x11_get_display(), uint(sapp.x11_get_window()), &values[0])
	}
	return browsertabs.Frame{ x: values[0], y: values[1], width: values[2], height: values[3] }
}

fn process_tab_window_show(visible bool, frame browsertabs.Frame) {
	$if macos {
		C.vox_tab_window_show(sapp.macos_get_window(), i32(visible), frame.x, frame.y, frame.width, frame.height)
	} $else $if linux {
		C.vox_tab_x11_show(sapp.x11_get_display(), uint(sapp.x11_get_window()), i32(visible), frame.x, frame.y, frame.width, frame.height)
	}
}

fn (mut app BrowserApp) start_process_tabs() {
	if app.process_tabs() || app.ctx == unsafe { nil } || !sapp.isvalid() || app.screenshot_path != '' {
		return
	}
	app.initialize_browser_tabs()
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	folder := os.getenv('VOX_TAB_GROUP')
	app.tabs.session = if folder == '' {
		browsertabs.create(process_tab_window_frame()) or {
			eprintln('Vox: ${err}')
			sapp.quit()
			return
		}
	} else {
		browsertabs.join(folder, os.getenv('VOX_TAB_ID')) or {
			eprintln('Vox: ${err}')
			sapp.quit()
			return
		}
	}
	if folder == '' && app.browser_ui().tab_color != .none {
		app.tabs.session.set_color(app.tabs.session.id, app.browser_ui().tab_color) or { eprintln(err) }
	}
	if folder == '' && app.browser_ui().custom_tab_title != '' {
		app.tabs.session.set_custom_title(app.tabs.session.id, app.browser_ui().custom_tab_title) or { eprintln(err) }
	}
	app.tabs.process_visible = folder == ''
	if folder != '' {
		app.tabs.process_initializing = true
		$if macos {
			C.vox_tab_window_prepare(sapp.macos_get_window())
		}
	}
	mut timer := platform.Timer.create_repeating(100, fn [mut app] () { app.poll_process_tabs() })
	app.tabs.process_timer = timer
	timer.start()
}

fn (mut app BrowserApp) open_process_tab(address string, background bool) {
	mut call_arguments := ['--window-width=${app.viewport_width}',
		'--window-height=${app.viewport_height + app.chrome_height()}', '--js-engine=${app.js_engine}']
	if app.script_policy == .enabled { call_arguments << '--enable-javascript' }
	if app.script_policy == .disabled { call_arguments << '--disable-javascript' }
	if app.auto_open_devtools { call_arguments << '--auto-open-devtools-for-tabs' }
	call_arguments << address
	// On macOS os.executable() can name an injected dylib (dyld image zero).
	// Use the kernel-backed path shared with the isolated worker launcher.
	executable := adblock.current_executable_path() or {
		eprintln('Vox: cannot locate the new-tab executable: ${err}')
		return
	}
	app.tabs.session.open(executable, call_arguments, background, process_tab_window_frame()) or {
		eprintln('Vox: ${err}')
		return
	}
	request_browser_frame()
}

fn (mut app BrowserApp) activate_process_tab(action string) {
	mut session := app.tabs.session
	count := session.state.tabs.len
	if count == 0 { return }
	selected := session.selected_index()
	frame := process_tab_window_frame()
	match action {
		'tab-new' { app.open_process_tab(browser_new_tab_url, false) }
		'tab-next' { session.select((selected + 1) % count, frame) or { eprintln(err) } }
		'tab-previous' {
			session.select((selected + count - 1) % count, frame) or { eprintln(err) }
		}
		'tab-last' { session.select(count - 1, frame) or { eprintln(err) } }
		'tab-close' { app.close_process_tab(selected) }
		else {
			if action.starts_with('tab-open:') || action.starts_with('tab-open-background:') {
				app.open_process_tab(action.all_after(':'), action.starts_with('tab-open-background:'))
			} else if action.starts_with('tab-select:') {
				session.select(action.all_after(':').int(), frame) or { eprintln(err) }
			} else if action.starts_with('tab-close:') {
				app.close_process_tab(action.all_after(':').int())
			} else if action.starts_with('tab-move:') {
				indices := action.all_after(':').split(':')
				if indices.len == 2 {
					session.move(indices[0].int(), indices[1].int()) or { eprintln(err) }
				}
			} else if action.starts_with('tab-detach:') {
				session.detach(action.all_after(':').int()) or { eprintln(err) }
			}
		}
	}
	app.poll_process_tabs()
	request_browser_frame()
}

fn (mut app BrowserApp) close_process_tab(index int) {
	if index < 0 || index >= app.tabs.session.state.tabs.len { return }
	if app.tabs.session.state.tabs.len == 1 {
		// Keep the last document alive until its replacement has started.
		app.open_process_tab(browser_new_tab_url, false)
		if app.tabs.session.state.tabs.len > 1 { app.tabs.close_after_replacement = true }
		return
	}
	app.tabs.session.close(index, process_tab_window_frame()) or { eprintln(err) }
}

fn process_tab_icon_data_url(bytes []u8) string {
	// Current V can stringify an encoder call inside interpolation as an Option.
	return 'data:image/png;base64,' + base64.encode(bytes)
}

fn (mut app BrowserApp) poll_process_tabs() {
	if !app.process_tabs() || app.tabs.polling_process || app.browser_tabs_busy() || platform.arena_entered() {
		return
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	app.tabs.polling_process = true
	defer { app.tabs.polling_process = false }
	// Publish encoded icon bytes, so other processes never refetch a page's icon.
	icon := app.browser_tab_favicon_id()
	if icon != app.tabs.process_icon_id {
		app.tabs.process_icon_id = icon
		app.tabs.process_icon = ''
		if icon >= 0 {
			cache := app.browser_text_cache()
			address := if cache.favicon_fallback {
				browser_tab_fallback_favicon_url(app.document)
			} else {
				cache.favicon_url
			}
			if bytes := app.background_image_bytes(address) {
				app.tabs.process_icon = process_tab_icon_data_url(bytes)
			}
		}
	}
	mut session := app.tabs.session
	previous := session.revision
	session.poll_loading(app.browser_tab_title(), app.address, app.tabs.process_icon,
		app.initial_window_frame_presented, app.browser_document_loading()) or {
		eprintln('Vox: tab session failed: ${err}')
		sapp.quit()
		return
	}
	index := session.index()
	if index < 0 {
		app.tabs.closing_process = true
		sapp.quit()
		return
	}
	if session.state.tabs[index].detach {
		mut frame := process_tab_window_frame()
		frame.x += 40
		frame.y -= 40
		app.tabs.session = session.detach_self(frame) or {
			eprintln(err)
			return
		}
		session = app.tabs.session
		app.tabs.process_initializing = true
	}
	if app.tabs.close_after_replacement && !session.visible() {
		app.tabs.close_after_replacement = false
		app.tabs.closing_process = true
		session.leave() or { eprintln(err) }
		sapp.quit()
		return
	}
	visible := session.visible()
	if visible != app.tabs.process_visible || (app.tabs.process_initializing && app.initial_window_frame_presented) {
		app.tabs.process_initializing = false
		app.tabs.process_visible = visible
		if !visible { app.blur_address_bar() }
		process_tab_window_show(visible, session.state.frame)
		if app.document != unsafe { nil } {
			app.document.update_the_visibility_state(if visible { .visible } else { .hidden })
			app.document.set_embedder_window_active(visible)
		}
		if visible {
			app.sync_address_bar()
			app.update_window_title()
			if app.address == '' || app.address == browser_new_tab_url { app.focus_address_bar() }
		}
	}
	if !visible { app.poll_background_browser_tab() }
	if session.take_reopen_request() {
		$if vox_ui2 ? { ui2.embedded_host_action('show') }
	}
	if time.sys_mono_now() >= app.tabs.profile_refresh_at {
		app.tabs.profile_refresh_at = time.sys_mono_now() + 1_000_000_000
		settings := browsersettings.current()
		if app.browser_chrome.tab_coloring != settings.enable_tab_coloring
			|| app.browser_chrome.custom_tab_titles != settings.enable_custom_tab_titles {
			if !settings.enable_custom_tab_titles && app.browser_ui().tab_title_editor != none {
				app.dismiss_browser_popup()
			}
			app.invalidate_tab_customization_snapshot()
			app.refresh_browser_ui()
		}
		// Profile writers merge under a process lock; refresh readers without
		// overwriting another tab's history, bookmarks or per-domain zoom.
		if app.browsing_history != unsafe { nil } {
			version := app.browsing_history.version
			app.browsing_history.reload() or {}
			if version != app.browsing_history.version { request_browser_frame() }
		}
		if app.bookmarks != unsafe { nil } {
			version := app.bookmarks.version
			app.bookmarks.reload() or {}
			if version != app.bookmarks.version {
				$if macos {
					if app.snapshot_visible { C.native_hide_cached_snapshot() }
				}
				app.snapshot_visible = false
				app.snapshot_hold = false
				app.snapshot_hold_until = 0
				app.snapshot_cached = false
				app.update_browser_chrome(app.browser_chrome.width, app.browser_chrome.height)
				request_browser_frame()
			}
		}
		if app.zoom_levels != unsafe { nil } {
			app.zoom_levels.reload() or {}
			if app.document != unsafe { nil } {
				app.set_browser_zoom(app.zoom_levels.for_url(app.document.url_string()))
			}
		}
	}
	if previous != session.revision { request_browser_frame() }
}

module main

import gg

$if vox_ui2 ? {
	import ui2

	#include "native_browser_chrome_darwin.h"
	#include "native_browser_chrome_style_darwin.h"
	fn C.native_browser_chrome_prepare_window(parent voidptr)
	fn C.native_browser_chrome_restore_window()
	fn C.native_browser_chrome_style_controls(toolbar voidptr, back voidptr, forward voidptr, reload voidptr, address voidptr)
	fn C.native_browser_chrome_style_history(control voidptr)
	fn C.native_browser_chrome_start_memory(control voidptr)
	fn C.native_browser_chrome_stop_memory()
}

struct BrowserChromeState {
	width   int
	height  int
	address string
	status  string
	footer  string
	back    bool
	forward bool
	reload  bool
	tab_titles []string
	selected_tab int
	debug   bool
	bookmarks_visible bool
	bookmarks_version u64
	bookmarks_error string
}

fn browser_chrome_requires_update(previous BrowserChromeState, next BrowserChromeState) bool {
	// Layout diagnostics change on every scroll. They have no visible control
	// while the debug strip is hidden, and must not rebuild the toolbar/tabs.
	if !previous.debug && !next.debug {
		return previous != BrowserChromeState{ ...next, status: previous.status }
	}
	return previous != next
}

fn browser_toolbar_height(debug bool) f64 {
	return toolbar_height + if debug { debug_status_height } else { 0.0 }
}

fn browser_debug_modifier(modifier gg.Modifier, is_macos bool) bool {
	if !modifier.has(.shift) || modifier.has(.alt) { return false }
	return if is_macos { modifier.has(.super) && !modifier.has(.ctrl) } else { modifier.has(.ctrl) && !modifier.has(.super) }
}

fn is_browser_debug_shortcut(key gg.KeyCode, modifier gg.Modifier) bool {
	if key != .d { return false }
	$if macos {
		return browser_debug_modifier(modifier, true)
	} $else {
		return browser_debug_modifier(modifier, false)
	}
}

fn (mut app BrowserApp) toggle_browser_debug() {
	app.chrome_debug = !app.chrome_debug
	// A cached full-window image has the old strip height and visibility.
	$if macos {
		if app.snapshot_visible { C.native_hide_cached_snapshot() }
	}
	app.snapshot_visible = false
	app.snapshot_hold = false
	app.snapshot_hold_until = 0
	app.snapshot_cached = false
	app.update_browser_chrome(app.browser_chrome.width, app.browser_chrome.height)
	// The next frame resolves the document viewport against the new strip height.
	request_browser_frame()
}

fn (app &BrowserApp) browser_chrome_snapshot_path(resource_url string) string {
	// Keep previous chrome layouts and debug-only diagnostics out of normal
	// startup snapshots, while retaining the shared snapshots cache directory.
	return cached_snapshot_path('${resource_url}\nclassic-chrome-v4:${app.chrome_debug}:${app.browser_tab_snapshot_key()}:zoom=${app.page_zoom}:bookmarks=${app.bookmark_bar_visible()}:${if app.bookmarks != unsafe { nil } { app.bookmarks.version } else { u64(0) }}')
}

fn (app &BrowserApp) chrome_footer() string {
	if app.hovered_link != '' { return app.hovered_link }
	if app.js_messages.len > 0 {
		// Console stacks must stay on the single-line status surface.
		return app.cached_browser_console_footer()
	}
	return app.source_label
}

fn (app &BrowserApp) browser_chrome_state(width int, height int) BrowserChromeState {
	titles := app.cached_browser_tab_titles()
	return BrowserChromeState{
		tab_titles: titles
		selected_tab: if app.tabs != unsafe { nil } { app.tabs.selected } else { 0 }
		width:   width
		height:  height
		address: app.address
		status:  app.status
		footer:  app.chrome_footer()
		back:    app.history_index > 0
		forward: app.history_index + 1 < app.history.len
		reload:  app.history_index >= 0
		debug:   app.chrome_debug
		bookmarks_visible: app.bookmark_bar_visible()
		bookmarks_version: if app.bookmarks != unsafe { nil } { app.bookmarks.version } else { 0 }
		bookmarks_error: app.bookmarks_error
	}
}

$if vox_ui2 ? {
	fn chrome_navigation_button(id string, title string, x f64, enabled bool) ui2.Element {
		return ui2.Element{
			...ui2.with_native_style(ui2.button(id, title, ui2.rect(x, tab_strip_height + 4, 22, 22),
				ui2.BoxStyle{}, ui2.TextStyle{}))
			enabled:             enabled
			tooltip:             title
			accessibility_label: title
		}
	}

	fn browser_chrome_elements(chrome BrowserChromeState) []ui2.Element {
		width := f64(chrome.width)
		address_width := if width > 162 { width - 138 } else { 24.0 }
		footer_width := if width > 224 { width - 224 } else { 0.0 }
		memory := ui2.text('memory')
		return [
			ui2.view('toolbar', ui2.rect(0, 0, width, tab_strip_height + browser_toolbar_height(chrome.debug) + if chrome.bookmarks_visible { bookmark_bar_height } else { 0.0 }), ui2.BoxStyle{ bg: 0xf7f7f7 }, [
				ui2.Element{ ...chrome_navigation_button('back', '‹', 5, chrome.back), tooltip: 'Back', accessibility_label: 'Back' },
				ui2.Element{ ...chrome_navigation_button('forward', '›', 27, chrome.forward), tooltip: 'Forward', accessibility_label: 'Forward' },
				ui2.Element{ ...chrome_navigation_button('reload', '↻', 49, chrome.reload), tooltip: 'Reload', accessibility_label: 'Reload' },
				ui2.text_input(
					id:          'address'
					action_id:   'address-change'
					submit_id:   'address-submit'
					text:        chrome.address
					hint_text:   'Enter a URL'
					multiline:   false
					autocorrect: false
					frame:       ui2.rect(98, tab_strip_height + 5, address_width, 20)
					text_style:  ui2.TextStyle{ size: 12 }
				) or { panic(err) },
				ui2.Element{
					...chrome_navigation_button('history', '◷', width - 32, true)
					tooltip: 'History'
					accessibility_label: 'History'
				},
				ui2.Element{
					...ui2.label('load-status', chrome.status, ui2.rect(12, tab_strip_height + toolbar_height, width - 24, debug_status_height), ui2.TextStyle{ color: 0x555555, size: 12 })
					hidden: !chrome.debug
				},
			]),
			ui2.view('status-bar', ui2.rect(0, f64(chrome.height) - status_bar_height, width, status_bar_height), ui2.BoxStyle{ bg: 0xececec }, [
				ui2.label('footer', chrome.footer, ui2.rect(12, 0, footer_width, status_bar_height), ui2.TextStyle{ color: 0x555555, size: 12 }),
				ui2.label('memory', memory, ui2.rect(width - 200, 0, 188, status_bar_height), ui2.TextStyle{ color: 0x555555, size: 12, align: .right }),
			]),
		]
	}

	fn (app &BrowserApp) style_native_browser_chrome() {
		C.native_browser_chrome_style_controls(ui2.embedded_browser_control('toolbar'),
			ui2.embedded_browser_control('back'), ui2.embedded_browser_control('forward'),
			ui2.embedded_browser_control('reload'), ui2.embedded_browser_control('address'))
		C.native_browser_chrome_style_history(ui2.embedded_browser_control('history'))
	}

	fn (mut app BrowserApp) mount_ui2_chrome(parent voidptr, width int, height int) !voidptr {
		C.native_browser_chrome_prepare_window(parent)
		chrome := app.browser_chrome_state(width, height)
		ui2.mount_embedded_browser(parent, browser_chrome_elements(chrome), address_bar_event)!
		app.browser_chrome = chrome
		app.native_address_bar = true
		app.style_native_browser_chrome()
		app.update_native_browser_tabs(chrome)
		app.update_native_browser_bookmarks(chrome)
		C.native_browser_chrome_start_memory(ui2.embedded_browser_control('memory'))
		return ui2.embedded_browser_control('address')
	}
}

fn (mut app BrowserApp) update_browser_chrome(width int, height int) {
	$if vox_ui2 ? {
		if !app.native_address_bar { return }
		chrome := app.browser_chrome_state(width, height)
		changed := browser_chrome_requires_update(app.browser_chrome, chrome)
		app.browser_chrome = chrome
		if !changed { return }
		ui2.update_embedded_browser(browser_chrome_elements(chrome))
		app.style_native_browser_chrome()
		app.update_native_browser_tabs(chrome)
		app.update_native_browser_bookmarks(chrome)
	}
}

fn (mut app BrowserApp) activate_browser_chrome(action string) {
	if action.starts_with('tab-') {
		app.activate_tab_chrome(action)
		return
	}
	match action {
		'history' { app.open_browser_history() }
		'back' {
			app.blur_address_bar()
			app.history_go(-1)
		}
		'forward' {
			app.blur_address_bar()
			app.history_go(1)
		}
		'reload' {
			app.blur_address_bar()
			app.reload()
		}
		'home' {
			app.blur_address_bar()
			app.navigate('about:home', true)
		}
		'address-submit' { app.submit_address_bar() }
		else { return }
	}
	request_browser_frame()
}

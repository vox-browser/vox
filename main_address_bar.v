module main

$if vox_ui2 ? {
	import ui2
	import macos
	import sokol.sapp

	#include "native_address_bar_darwin.h"

	fn C.native_address_bar_install_shortcuts(field voidptr, owner voidptr, callback fn (voidptr, int))
	fn C.native_address_bar_remove_shortcuts()
}

struct AddressBarOwner {
mut:
	app &BrowserApp = unsafe { nil }
}

const address_bar_owner = &AddressBarOwner{}

fn (mut app BrowserApp) mount_address_bar() {
	$if vox_ui2 ? {
		if app.chrome_height() == 0 { return }
		window := sapp.macos_get_window()
		parent := macos.msg_id(window, 'contentView')
		mut owner := unsafe { address_bar_owner }
		owner.app = app
		size := browser_window_size()
		field := app.mount_ui2_chrome(voidptr(parent), size.width, size.height) or {
			panic(err)
		}
		C.native_address_bar_install_shortcuts(field, app, address_bar_shortcut)
	}
}

fn (mut app BrowserApp) unmount_address_bar() {
	$if vox_ui2 ? {
		if !app.native_address_bar { return }
		C.native_browser_tabs_remove()
		C.native_browser_bookmarks_remove()
		C.native_browser_chrome_restore_window()
		C.native_address_bar_remove_shortcuts()
		C.native_browser_chrome_stop_memory()
		ui2.unmount_embedded_browser()
		mut owner := unsafe { address_bar_owner }
		owner.app = unsafe { nil }
		app.native_address_bar = false
	}
}

fn (mut app BrowserApp) resize_address_bar(width int) {
	$if vox_ui2 ? {
		if app.native_address_bar {
			app.update_browser_chrome(width, app.browser_chrome.height)
		}
	}
}

fn (app &BrowserApp) sync_address_bar() {
	$if vox_ui2 ? {
		if app.native_address_bar && app.is_active_browser_tab() { ui2.set_text('address', app.address) }
	}
}

fn (mut app BrowserApp) focus_address_bar() {
	app.address_active = true
	app.address_select = true
	app.address_cursor = app.address.runes().len
	$if vox_ui2 ? {
		if app.native_address_bar { ui2.select_embedded_textbox() }
	}
}

fn (mut app BrowserApp) blur_address_bar() {
	app.address_active = false
	app.address_select = false
	$if vox_ui2 ? {
		if app.native_address_bar { ui2.blur_embedded_textbox() }
	}
}

fn (mut app BrowserApp) submit_address_bar() {
	$if vox_ui2 ? {
		if app.native_address_bar { app.address = ui2.text('address') }
	}
	destination := app.address.trim_space()
	if destination == '' { return }
	app.blur_address_bar()
	app.navigate(destination, true)
	request_browser_frame()
}

fn (mut app BrowserApp) cancel_address_bar() {
	if app.history_index >= 0 && app.history_index < app.history.len {
		app.address = app.history[app.history_index].url
	}
	app.sync_address_bar()
	app.blur_address_bar()
}

$if vox_ui2 ? {
	fn address_bar_event(event string) {
		if address_bar_owner.app == unsafe { nil } { return }
		mut app := address_bar_owner.app.active_browser_tab()
		match event {
			'address-change' { app.address = ui2.text('address') }
			else { app.activate_browser_chrome(event) }
		}
	}

	fn address_bar_shortcut(owner voidptr, action int) {
		mut shell := unsafe { &BrowserApp(owner) }
		mut app := shell.active_browser_tab()
		match action {
			0 { app.focus_address_bar() }
			1 { app.reload() }
			2 { app.cancel_address_bar() }
			3 { app.toggle_browser_debug() }
			4 { app.activate_tab_chrome('tab-new') }
			5 { app.activate_tab_chrome('tab-close') }
			6 { app.activate_tab_chrome('tab-next') }
			7 { app.activate_tab_chrome('tab-previous') }
			8 { app.activate_tab_chrome('tab-last') }
			9...16 { app.activate_tab_chrome('tab-select:${action - 9}') }
			17 { app.activate_browser_zoom('zoom-in') }
			18 { app.activate_browser_zoom('zoom-out') }
			19 { app.activate_browser_zoom('zoom-reset') }
			20 { app.open_browser_history() }
			21 { app.activate_browser_bookmarks('bookmarks-toggle') }
			22 { app.activate_browser_bookmarks('bookmark-add') }
			else {}
		}

		request_browser_frame()
	}
}

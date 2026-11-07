module main

import browserbookmarks
import browsersettings
import gg
import optimizedsites
import os
import page
import time

$if vox_ui2 ? {
	import ui2
}

fn open_browsing_test_settings() string {
	directory := os.join_path(os.temp_dir(), 'vox-browsing-shell-${os.getpid()}-${time.sys_mono_now()}')
	browsersettings.initialize(os.join_path(directory, 'settings.json')) or { panic(err) }
	return directory
}

fn test_interactive_shell_edits_the_address_and_keeps_seeded_bookmarks_optional() {
	directory := open_browsing_test_settings()
	defer { os.rmdir_all(directory) or {} }
	mut app := BrowserApp{
		seed_optimized_bookmarks: true
		address: 'https://www.wikipedia.org/'
		bookmarks: browserbookmarks.open('')!
	}
	app.bookmarks.seed_optimized_sites()!
	app.bookmarks.seed_forum_news_sites()!
	app.bookmarks.add('https://custom.example/', 'Custom')!
	assert app.bookmark_bar_visible()
	assert app.bookmarks.items.len == optimizedsites.bookmarked_sites.len + 1
	app.focus_address_bar()
	app.handle_character(u32(`x`))
	assert app.address == 'x'
	app.handle_key(.backspace, unsafe { gg.Modifier(0) })
	assert app.address == ''
	app.address = 'https://unconfirmed.example/'
	app.address_cursor = app.address.runes().len
	app.navigation_work_depth = 1
	app.handle_key(.enter, unsafe { gg.Modifier(0) })
	assert (app.deferred_navigation_input or { panic('address submission was blocked') }).address == 'https://unconfirmed.example/'
	app.activate_browser_bookmarks('bookmark-open:${app.bookmarks.items.len - 1}')
	assert (app.deferred_navigation_input or { panic('custom bookmark did not open') }).address == 'https://custom.example/'
	app.activate_browser_bookmarks('bookmarks-toggle')
	assert !app.bookmark_bar_visible()
}

fn test_new_tabs_inherit_bookmark_seeding_and_open_unlisted_destinations() {
	directory := open_browsing_test_settings()
	defer { os.rmdir_all(directory) or {} }
	profile := os.getenv('VOX_PROFILE_DIR')
	os.setenv('VOX_PROFILE_DIR', directory, true)
	defer {
		if profile == '' { os.unsetenv('VOX_PROFILE_DIR') }
		else { os.setenv('VOX_PROFILE_DIR', profile, true) }
	}
	unlisted := os.join_path(directory, 'unlisted.html')
	os.mkdir_all(directory)!
	os.write_file(unlisted, '<!doctype html><title>Unlisted</title>')!
	mut app := BrowserApp{seed_optimized_bookmarks: true, page_model: page.Page.create(1.0)!}
	app.initialize_browser_tabs()
	defer { app.cleanup_browser_tabs() }
	app.activate_tab_chrome('tab-new')
	mut tab := app.active_browser_tab()
	assert tab.seed_optimized_bookmarks
	assert tab.document.url_string() == browser_new_tab_url
	tab.navigate('file://${unlisted}', true)
	assert tab.document.url_string() == 'file://${unlisted}'
	assert tab.document.title() == 'Unlisted'
}

$if vox_ui2 ? {
	#include "@VMODROOT/native_browser_settings_test_darwin.h"
	#include "@VMODROOT/native_browser_bookmarks_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_address_selection(field voidptr) uint
	fn C.native_test_settings_address_state(control voidptr, editable int) int
	fn C.native_test_bookmark_bar_geometry(control voidptr, width int, top int) int
	fn C.native_test_chrome_click(control voidptr)

	fn test_native_address_is_editable_beside_seeded_and_custom_bookmarks() {
		directory := open_browsing_test_settings()
		defer { os.rmdir_all(directory) or {} }
		window := C.native_test_address_window()
		mut app := &BrowserApp{
			seed_optimized_bookmarks: true
			address: 'https://www.wikipedia.org/'
			bookmarks: browserbookmarks.open('')!
		}
		app.bookmarks.seed_optimized_sites()!
		app.bookmarks.add('https://custom.example/', 'Custom')!
		mut owner := unsafe { address_bar_owner }
		owner.app = app
		defer {
			app.unmount_address_bar()
			C.native_test_address_close(window)
		}
		field := app.mount_ui2_chrome(C.native_test_address_parent(window), 800, 600)!
		assert C.native_test_settings_address_state(field, 1) != 0
		assert C.native_test_bookmark_bar_geometry(ui2.embedded_browser_control('bookmarks-bar'), 800, int(app.bookmark_bar_top())) != 0
		app.focus_address_bar()
		assert C.native_test_address_selection(field) == u32(app.address.len)
		ui2.set_text('address', 'https://unconfirmed.example/')
		address_bar_event('address-change')
		assert app.address == 'https://unconfirmed.example/'
		app.navigation_work_depth = 1
		C.native_test_chrome_click(ui2.embedded_browser_control('bookmark-open:4'))
		assert (app.deferred_navigation_input or { panic('custom bookmark did not dispatch') }).address == 'https://custom.example/'
	}
}

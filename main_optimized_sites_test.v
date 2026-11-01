module main

import browserbookmarks
import browsersettings
import gg
import os
import page
import time

$if vox_ui2 ? {
	import ui2
}

fn optimized_browsing_test_settings() string {
	directory := os.join_path(os.temp_dir(), 'vox-browsing-shell-${os.getpid()}-${time.sys_mono_now()}')
	browsersettings.initialize(os.join_path(directory, 'settings.json')) or { panic(err) }
	return directory
}

fn test_restricted_shell_blocks_navigation_history_redirects_and_address_edits() {
	directory := optimized_browsing_test_settings()
	defer { os.rmdir_all(directory) or {} }
	mut app := BrowserApp{
		restrict_to_optimized_sites: true
		address: 'https://www.wikipedia.org/'
		history: [HistoryEntry{url: 'https://www.wikipedia.org/'}, HistoryEntry{url: 'https://unconfirmed.example/'}]
		history_index: 0
		bookmarks: browserbookmarks.open('')!
	}
	assert app.bookmark_bar_visible()
	assert app.browser_bar_bookmarks().len == 3
	assert !app.address_bar_editable()
	app.focus_address_bar()
	app.handle_character(u32(`x`))
	app.handle_key(.backspace, unsafe { gg.Modifier(0) })
	app.submit_address_bar()
	assert app.address == 'https://www.wikipedia.org/'
	assert app.navigation_generation == 0
	app.navigate('https://unconfirmed.example/', true)
	assert app.navigation_generation == 0 && app.history_index == 0
	assert app.pending_navigation == none
	assert app.chrome_footer().contains('Allow opening any site')
	app.history_go(1)
	assert app.history_index == 0
	app.prepare_loaded_page(LoadedPage{url: 'https://redirect.example/', markup: '<title>Redirect</title>'}, true)
	assert app.document == unsafe { nil } && app.pending_page_preload == none
	app.install_loaded_page(LoadedPage{url: 'https://redirect.example/', markup: '<title>Direct</title>'}, true)
	assert app.document == unsafe { nil }
	app.activate_browser_bookmarks('bookmarks-toggle')
	app.activate_browser_bookmarks('bookmark-remove:0')
	assert app.bookmark_bar_visible() && app.browser_bar_bookmarks().len == 3
	assert app.browser_destination_allowed('https://en.wikipedia.org/wiki/V')
	assert app.browser_destination_allowed(browser_new_tab_url)
	assert app.browser_destination_allowed(browser_history_url)
	assert !app.browser_destination_allowed('javascript:location="https://evil.test"')
	app.navigation_work_depth = 1
	app.activate_browser_bookmarks('bookmark-open:2')
	assert (app.deferred_navigation_input or { panic('missing optimized bookmark navigation') }).address == 'https://vlang.io/'
}

fn test_settings_unlock_and_relock_the_existing_shell_without_losing_custom_bookmarks() {
	directory := optimized_browsing_test_settings()
	defer { os.rmdir_all(directory) or {} }
	mut app := BrowserApp{restrict_to_optimized_sites: true, bookmarks: browserbookmarks.open('')!}
	app.bookmarks.add('https://custom.example/', 'Custom')!
	before := app.browser_chrome_state(800, 600)
	snapshot := app.browser_chrome_snapshot_path('https://www.wikipedia.org/')
	browsersettings.save(browsersettings.Proxy{allow_any_site: true})!
	assert app.address_bar_editable()
	assert app.browser_destination_allowed('https://unconfirmed.example/')
	assert app.browser_bar_bookmarks().len == 1
	assert app.bookmarks.items[0].title == 'Custom'
	app.address = ''
	app.focus_address_bar()
	app.handle_character(u32(`x`))
	assert app.address == 'x'
	app.address = 'https://unconfirmed.example/'
	app.navigation_work_depth = 1
	app.submit_address_bar()
	assert (app.deferred_navigation_input or { panic('unlocked submission was blocked') }).address == app.address
	assert browser_chrome_requires_update(before, app.browser_chrome_state(800, 600))
	assert app.browser_chrome_snapshot_path('https://www.wikipedia.org/') != snapshot
	browsersettings.save(browsersettings.Proxy{})!
	app.navigation_work_depth = 0
	app.poll_deferred_navigation_input()
	assert app.navigation_generation == 0
	assert app.deferred_navigation_input == none
	assert !app.address_bar_editable()
	assert app.browser_bar_bookmarks().len == 3
	assert app.bookmarks.items.len == 1
}

fn test_new_tabs_inherit_interactive_restrictions() {
	directory := optimized_browsing_test_settings()
	defer { os.rmdir_all(directory) or {} }
	profile := os.getenv('VOX_PROFILE_DIR')
	os.setenv('VOX_PROFILE_DIR', directory, true)
	defer {
		if profile == '' { os.unsetenv('VOX_PROFILE_DIR') }
		else { os.setenv('VOX_PROFILE_DIR', profile, true) }
	}
	mut app := BrowserApp{restrict_to_optimized_sites: true, page_model: page.Page.create(1.0)!}
	app.initialize_browser_tabs()
	defer { app.cleanup_browser_tabs() }
	app.activate_tab_chrome('tab-new')
	mut tab := app.active_browser_tab()
	assert tab.restrict_to_optimized_sites && !tab.address_bar_editable()
	assert tab.document.url_string() == browser_new_tab_url
	tab.navigate('https://unconfirmed.example/', true)
	assert tab.document.url_string() == browser_new_tab_url
}

$if vox_ui2 ? {
	#include "native_browser_settings_test_darwin.h"
	#include "native_browser_bookmarks_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_address_selection(field voidptr) uint
	fn C.native_test_settings_address_state(control voidptr, editable int) int
	fn C.native_test_bookmark_bar_geometry(control voidptr, width int, top int) int
	fn C.native_test_chrome_click(control voidptr)

	fn test_native_address_is_selectable_read_only_and_bookmark_links_use_the_catalog() {
		directory := optimized_browsing_test_settings()
		defer { os.rmdir_all(directory) or {} }
		window := C.native_test_address_window()
		mut app := &BrowserApp{
			restrict_to_optimized_sites: true
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
		assert C.native_test_settings_address_state(field, 0) != 0
		assert C.native_test_bookmark_bar_geometry(ui2.embedded_browser_control('bookmarks-bar'), 800, int(app.bookmark_bar_top())) != 0
		app.focus_address_bar()
		assert C.native_test_address_selection(field) == u32(app.address.len)
		ui2.set_text('address', 'https://unconfirmed.example/')
		address_bar_event('address-change')
		assert ui2.text('address') == 'https://www.wikipedia.org/'
		app.navigation_work_depth = 1
		C.native_test_chrome_click(ui2.embedded_browser_control('bookmark-open:1'))
		assert (app.deferred_navigation_input or { panic('bookmark did not dispatch') }).address == 'https://old.reddit.com/r/programming/'
		browsersettings.save(browsersettings.Proxy{allow_any_site: true})!
		app.update_browser_chrome(800, 600)
		assert C.native_test_settings_address_state(field, 1) != 0
		assert app.browser_bar_bookmarks().len == 4
		browsersettings.save(browsersettings.Proxy{})!
		app.update_browser_chrome(800, 600)
		assert C.native_test_settings_address_state(field, 0) != 0
		assert app.browser_bar_bookmarks().len == 3
	}
}

module main

import browserbookmarks
import gg
import page

$if vox_ui2 ? {
	import ui2
}

fn bookmark_test_app() &BrowserApp {
	mut app := &BrowserApp{
		page_model:                  page.Page.create(1) or { panic(err) }
		bookmarks:                   browserbookmarks.open('') or { panic(err) }
		viewport_width:              800
		viewport_height:             516
		navigation_results:          chan NavigationResult{cap: 4}
		background_resource_results: chan PreloadedResource{cap: max_cached_resources}
	}
	app.install_chrome_widget_input_bridge()
	app.initialize_browser_tabs()
	app.install_loaded_page(LoadedPage{
		url:          'https://example.com/loaded#section'
		markup:       '<!doctype html><title>Saved page — café</title><p>Content</p>'
		content_type: 'text/html'
	}, true)
	return app
}

fn bookmark_test_close(mut app BrowserApp) {
	for mut tab in app.tabs.pages { tab.dispose_browser_tab() }
}

fn test_bookmark_shortcuts_save_the_committed_page_and_preserve_address_editing() {
	modifier := $if macos { gg.Modifier.super } $else { gg.Modifier.ctrl }
	mut app := bookmark_test_app()
	defer { bookmark_test_close(mut app) }
	app.address = 'https://unsubmitted.example/'
	app.focus_address_bar()
	app.handle_key(.d, modifier)
	assert app.bookmarks.items.len == 1
	assert app.bookmarks.items[0].url == 'https://example.com/loaded#section'
	assert app.bookmarks.items[0].title == 'Saved page — café'
	assert app.address == 'https://unsubmitted.example/'
	assert app.address_active && app.address_select
	assert !app.chrome_debug
	app.handle_key(.d, modifier)
	assert app.bookmarks.items.len == 1
	assert browser_bookmark_shortcut(.b, modifier | .shift) == 'bookmarks-toggle'
	assert browser_bookmark_shortcut(.b, modifier) == ''
	assert browser_bookmark_shortcut(.d, modifier | .shift) == ''
	assert browser_bookmark_shortcut(.d, modifier | .alt) == ''
	assert browser_bookmark_shortcut(.d, .ctrl | .super) == ''
	assert browser_bookmark_shortcut(.d, unsafe { gg.Modifier(0) }) == ''
}

fn test_bookmark_bar_toggle_reflows_viewport_and_invalidates_window_snapshots() {
	modifier := $if macos { gg.Modifier.super } $else { gg.Modifier.ctrl }
	mut app := bookmark_test_app()
	defer { bookmark_test_close(mut app) }
	app.relayout(800, 600)
	assert app.page_top() == 60
	assert app.document.viewport_rect().height == 516
	path := app.browser_chrome_snapshot_path('https://example.com/')
	app.snapshot_cached = true
	app.snapshot_hold = true
	app.snapshot_hold_until = 1
	app.navigation_work_depth = 1
	app.handle_event(&gg.Event{ typ: .key_down, key_code: .b, modifiers: u32(modifier | .shift) })
	assert app.deferred_page_input.len == 0
	app.handle_key(.b, modifier | .shift)
	assert app.bookmark_bar_visible()
	assert !app.snapshot_cached && !app.snapshot_hold
	assert app.snapshot_hold_until == 0
	app.navigation_work_depth = 0
	app.relayout(800, 600)
	assert app.page_top() == 88
	assert app.document.viewport_rect().height == 488
	assert app.browser_chrome_snapshot_path('https://example.com/') != path
	app.toggle_browser_debug()
	assert app.page_top() == 120
	app.handle_key(.b, modifier | .shift)
	assert app.page_top() == 92
	assert !app.bookmark_bar_visible()
}

fn test_bookmarks_and_bar_visibility_are_shared_with_new_and_switched_tabs() {
	mut app := bookmark_test_app()
	defer { bookmark_test_close(mut app) }
	app.activate_browser_bookmarks('bookmark-add')
	app.activate_browser_bookmarks('bookmarks-toggle')
	app.activate_tab_chrome('tab-new')
	mut second := app.active_browser_tab()
	assert voidptr(second.bookmarks) == voidptr(app.bookmarks)
	assert second.bookmark_bar_visible()
	// New tabs now start at vox://newtab, which is not a bookmarkable page.
	second.install_loaded_page(LoadedPage{
		url: 'about:blank'
		markup: '<!doctype html><title>Second saved page</title>'
		content_type: 'text/html'
	}, true)
	second.activate_browser_bookmarks('bookmark-add')
	assert app.bookmarks.items.len == 2
	second.activate_browser_bookmarks('bookmarks-toggle')
	app.select_browser_tab(0)
	assert !app.bookmark_bar_visible()
	app.activate_browser_bookmarks('bookmark-remove:0')
	assert second.bookmarks.items.len == 1
	assert second.bookmarks.items[0].url == 'about:blank'
}

$if vox_ui2 ? {
	#include "native_browser_bookmarks_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_address_shortcut(field voidptr, owner voidptr, callback fn (voidptr, int), key u16, shift int) int
	fn C.native_test_address_selection(field voidptr) uint
	fn C.native_test_bookmark_bar_geometry(control voidptr, width int, top int) int
	fn C.native_test_chrome_click(control voidptr)

	fn test_native_bookmark_shortcuts_work_in_the_address_editor_and_bar_links_navigate() {
		window := C.native_test_address_window()
		mut app := bookmark_test_app()
		mut owner := unsafe { address_bar_owner }
		owner.app = app
		defer {
			app.unmount_address_bar()
			bookmark_test_close(mut app)
			C.native_test_address_close(window)
		}
		app.bookmarks.add('about:blank', 'Blank page') or { panic(err) }
		field := app.mount_ui2_chrome(C.native_test_address_parent(window), 800, 600) or { panic(err) }
		app.focus_address_bar()
		selection := C.native_test_address_selection(field)
		assert C.native_test_address_shortcut(field, app, address_bar_shortcut, 2, 0) == 1
		assert app.bookmarks.items.len == 2
		assert !app.chrome_debug
		assert C.native_test_address_selection(field) == selection
		assert C.native_test_address_shortcut(field, app, address_bar_shortcut, 11, 1) == 1
		assert C.native_test_bookmark_bar_geometry(ui2.embedded_browser_control('bookmarks-bar'), 800, 60) == 1
		assert ui2.focused_id() == 'address'
		assert C.native_test_address_selection(field) == selection
		app.update_browser_chrome(640, 480)
		assert C.native_test_bookmark_bar_geometry(ui2.embedded_browser_control('bookmarks-bar'), 640, 60) == 1
		C.native_test_chrome_click(ui2.embedded_browser_control('bookmark-open:0'))
		assert app.document.url_string() == 'about:blank'
		assert !app.address_active
		for index in 0 .. 12 {
			app.bookmarks.add('https://example.com/bookmark/${index}', 'Overflow bookmark ${index}')!
		}
		app.update_browser_chrome(640, 480)
		assert ui2.embedded_browser_control('bookmarks-more') != unsafe { nil }
		C.native_test_chrome_click(ui2.embedded_browser_control('bookmarks-more'))
		assert ui2.embedded_browser_control('bookmarks-overflow') != unsafe { nil }
		count := app.bookmarks.items.len
		C.native_test_chrome_click(ui2.embedded_browser_control('bookmark-remove:${count - 1}'))
		assert app.bookmarks.items.len == count - 1
		assert C.native_test_address_shortcut(field, app, address_bar_shortcut, 11, 1) == 1
		assert !app.bookmark_bar_visible()
		assert ui2.embedded_browser_control('bookmarks-bar') == unsafe { nil }
		assert ui2.embedded_browser_control('bookmarks-overflow') == unsafe { nil }
	}
}

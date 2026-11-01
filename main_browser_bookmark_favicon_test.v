module main

import browserbookmarks
import dom
import encoding.base64
import gg
import os

$if vox_ui2 ? {
	import ui2
}

const bookmark_favicon_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='

fn bookmark_favicon_app() &BrowserApp {
	return &BrowserApp{
		document: dom.Document.create(dom.URL{value: 'vox://newtab'})
		ctx: gg.new_context(native_rendering: true, width: 800, height: 600)
		bookmarks: browserbookmarks.open('') or { panic(err) }
		background_resource_results: chan PreloadedResource{cap: 4}
	}
}

fn test_bookmark_icons_decode_offline_and_keep_published_chrome_state_immutable() {
	mut app := bookmark_favicon_app()
	defer { app.document.finalize() }
	app.bookmarks.seed_optimized_sites()!
	before := app.browser_chrome_state(800, 600)
	assert before.bookmark_favicons.len == 4
	assert before.bookmark_favicons.all(it >= 0)
	assert app.background_resource_pending.len == 0
	assert app.browser_chrome_state(800, 600).bookmark_favicons == before.bookmark_favicons
	app.bookmarks.remove(0)!
	after := app.browser_chrome_state(800, 600)
	assert after.bookmark_favicons.len == 3
	assert before.bookmark_favicons.len == 4
	assert after.bookmark_favicons == before.bookmark_favicons[1..]
}

fn test_bookmark_favicon_completion_refreshes_chrome_without_waiting_or_mutating_prior_state() {
	mut app := bookmark_favicon_app()
	defer { app.document.finalize() }
	app.bookmarks.add('https://custom.example/path', 'Custom')!
	app.bookmarks.toggle_visible()!
	address := 'https://custom.example/favicon.ico'
	app.background_resource_pending[address] = true
	before := app.browser_chrome_state(800, 600)
	assert before.bookmark_favicons == [-1]
	app.resource_cache[address] = PreloadedResource{url: address, body: base64.decode(bookmark_favicon_png).bytestr()}
	after := app.browser_chrome_state(800, 600)
	assert after.bookmark_favicons[0] >= 0
	assert browser_chrome_requires_update(before, after)
	assert before.bookmark_favicons == [-1]
	assert browser_bookmark_favicon_url('https://custom.example/path?q=x') == address
	for url in ['file:///private/icon.png', 'https://user:secret@custom.example/', 'javascript:void(0)'] {
		assert browser_bookmark_favicon_url(url) == ''
	}
}

$if vox_ui2 ? {
	#include "native_browser_bookmarks_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_bookmark_has_favicon(control voidptr) int
	fn C.native_test_bookmark_capture(control voidptr, path &char)
	fn C.native_test_chrome_click(control voidptr)

	fn test_native_default_favicons_and_overflow_render_and_click_the_programming_bookmark() {
		window := C.native_test_address_window()
		mut app := bookmark_favicon_app()
		app.bookmarks.seed_optimized_sites()!
		app.mount_ui2_chrome(C.native_test_address_parent(window), 800, 600)!
		defer { app.unmount_address_bar(); app.document.finalize(); C.native_test_address_close(window) }
		for index in 0 .. 4 { assert C.native_test_bookmark_has_favicon(ui2.embedded_browser_control('bookmark-open:${index}')) != 0 }
		if path := os.getenv_opt('VOX_BOOKMARK_CAPTURE') { C.native_test_bookmark_capture(ui2.embedded_browser_control('bookmarks-bar'), path.str) }
		app.navigation_work_depth = 1
		C.native_test_chrome_click(ui2.embedded_browser_control('bookmark-open:1'))
		assert (app.deferred_navigation_input or { panic('missing bookmark click') }).address == 'https://old.reddit.com/r/programming/'
		app.update_browser_chrome(140, 600)
		C.native_test_chrome_click(ui2.embedded_browser_control('bookmarks-more'))
		for index in 0 .. 4 { assert C.native_test_bookmark_has_favicon(ui2.embedded_browser_control('bookmark-open:${index}')) != 0 }
	}

	fn test_native_remote_icon_completion_preserves_the_existing_button() {
		window := C.native_test_address_window()
		mut app := bookmark_favicon_app()
		app.bookmarks.add('https://custom.example/path', 'Custom')!
		app.bookmarks.toggle_visible()!
		address := 'https://custom.example/favicon.ico'
		app.background_resource_pending[address] = true
		app.mount_ui2_chrome(C.native_test_address_parent(window), 800, 600)!
		defer { app.unmount_address_bar(); app.document.finalize(); C.native_test_address_close(window) }
		button := ui2.embedded_browser_control('bookmark-open:0')
		assert button != unsafe { nil } && C.native_test_bookmark_has_favicon(ui2.embedded_browser_control('bookmark-open:0')) == 0
		app.resource_cache[address] = PreloadedResource{url: address, body: base64.decode(bookmark_favicon_png).bytestr()}
		app.update_browser_chrome(800, 600)
		assert C.native_test_bookmark_has_favicon(ui2.embedded_browser_control('bookmark-open:0')) != 0
		assert ui2.embedded_browser_control('bookmark-open:0') == button
	}
}

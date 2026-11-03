module main

import browserbookmarks
import browsersettings
import dom
import encoding.base64
import gg
import os
import platform
import time

$if vox_ui2 ? {
	import ui2
}

const bookmark_favicon_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='

fn test_bookmark_favicon_url_cache_owns_keys_and_values_after_caller_retires() {
	mut app := &BrowserApp{}
	mut caller := platform.new_arena('bookmark URL caller')
	host := 'custom${os.getpid()}.example'
	expected := 'https://${host}:8443/favicon.ico'
	entry := caller.enter()
	mut entered := true
	defer {
		if entered { caller.leave(entry) }
		caller.release()
	}
	address := 'https://${host}:8443/path?q=old#fragment'
	$if prealloc { assert caller.contains(address.str) }
	resolved := app.cached_browser_bookmark_favicon_url(address)
	assert resolved == expected
	assert !caller.contains(resolved.str)
	// Map iteration clones string keys into the caller. Verify the retained
	// key through a lookup after this caller has actually retired instead.
	caller.leave(entry)
	entered = false
	caller.reset()
	assert resolved == expected
	assert app.cached_browser_bookmark_favicon_url('https://${host}:8443/path?q=old#fragment') == resolved
	assert app.cached_browser_bookmark_favicon_url('https://other.example/new') == 'https://other.example/favicon.ico'
}

fn test_warm_bookmark_icon_lookups_do_not_retain_per_frame_url_records() {
	directory := os.join_path(os.temp_dir(), 'vox-bookmark-cache-${os.getpid()}-${time.sys_mono_now()}')
	browsersettings.initialize(os.join_path(directory, 'settings.json'))!
	defer { os.rmdir_all(directory) or {} }
	mut app := bookmark_favicon_app()
	defer { app.document.finalize() }
	app.bookmarks.seed_optimized_sites()!
	app.restrict_to_optimized_sites = true
	assert app.optimized_sites_only()
	before_icons := app.cached_browser_bookmark_favicons()
	assert before_icons.len == app.browser_bar_bookmarks().len && before_icons.any(it >= 0)
	addresses := ['https://custom.example/path?q=1', 'file:///private/icon.png',
		'https://user:secret@custom.example/', 'javascript:void(0)']
	for address in addresses { _ = app.cached_browser_bookmark_favicon_url(address) }
	before := platform.thread_arena_usage().used
	for _ in 0 .. 1024 {
		assert app.cached_browser_bookmark_favicons() == before_icons
		for address in addresses { _ = app.cached_browser_bookmark_favicon_url(address) }
	}
	cached_bytes := platform.thread_arena_usage().used - before
	$if prealloc { assert cached_bytes < 1024 }
	for address in addresses[1..] { assert app.cached_browser_bookmark_favicon_url(address) == '' }
	control_before := platform.thread_arena_usage().used
	for _ in 0 .. 1024 {
		for address in addresses {
			assert browser_bookmark_favicon_url(address) == app.cached_browser_bookmark_favicon_url(address)
		}
	}
	control_bytes := platform.thread_arena_usage().used - control_before
	eprintln('BOOKMARK_FAVICON_URL_CACHE cached_bytes=${cached_bytes} control_bytes=${control_bytes}')
}

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

// A completed background fetch that followed a redirect leaves final_url
// different from the requested url. Drawing the bookmark bar must decode that
// retained body directly, never re-enter a blocking network fetch per frame.
fn test_redirected_remote_favicon_decodes_without_resynchronous_fetch() {
	mut app := bookmark_favicon_app()
	defer { app.document.finalize() }
	app.bookmarks.add('https://redirect.example/path', 'Redirect')!
	app.bookmarks.toggle_visible()!
	address := 'https://redirect.example/favicon.ico'
	app.resource_cache[address] = PreloadedResource{
		url:       address
		final_url: 'https://cdn.redirect.example/favicon.ico'
		body:      base64.decode(bookmark_favicon_png).bytestr()
	}
	first := app.browser_chrome_state(800, 600)
	assert first.bookmark_favicons.len == 1
	assert first.bookmark_favicons[0] >= 0
	// Decoded once and reused; no new background request and no refetch.
	assert address !in app.background_resource_pending
	second := app.browser_chrome_state(800, 600)
	assert second.bookmark_favicons == first.bookmark_favicons
}

// An errored favicon response is remembered as absent so the chrome neither
// re-requests it nor retries a synchronous fetch on later frames.
fn test_errored_remote_favicon_is_remembered_absent_without_refetch() {
	mut app := bookmark_favicon_app()
	defer { app.document.finalize() }
	app.bookmarks.add('https://missing.example/path', 'Missing')!
	app.bookmarks.toggle_visible()!
	address := 'https://missing.example/favicon.ico'
	app.resource_cache[address] = PreloadedResource{url: address, error: 'HTTP 404'}
	first := app.browser_chrome_state(800, 600)
	assert first.bookmark_favicons == [-1]
	assert address !in app.background_resource_pending
	second := app.browser_chrome_state(800, 600)
	assert second.bookmark_favicons == [-1]
	assert address !in app.background_resource_pending
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

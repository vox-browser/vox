module main

import dom
import encoding.base64
import gg
import html
import os
import platform

$if vox_ui2 ? {
	import ui2
}

const tab_favicon_test_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='

fn tab_favicon_test_app(address string, markup string) &BrowserApp {
	mut document := dom.Document.create(dom.URL{ value: address })
	html.parse_html_from_a_string(document, '<!doctype html><title>Site</title>${markup}')
	return &BrowserApp{
		document:                    document
		ctx:                         gg.new_context(native_rendering: true, width: 800, height: 600)
		background_resource_results: chan PreloadedResource{cap: 4}
	}
}

fn test_tab_favicon_resolves_last_head_icon_against_live_base() {
	mut app := tab_favicon_test_app('https://site.example/path/page',
		'<base href="https://cdn.example/assets/"><link rel="ICON" href="first.png"><link id="icon" rel="shortcut icon" href="last.png"><link rel="mask-icon" href="mask.svg">')
	defer { app.document.finalize() }
	assert browser_tab_declared_favicon_url(app.document) == 'https://cdn.example/assets/last.png'
	assert browser_tab_fallback_favicon_url(app.document) == 'https://site.example/favicon.ico'
	mut icon := unsafe { &dom.Element(app.document.get_element_by_id('icon')?) }
	icon.set_attribute_value('href', '../changed.png')
	assert browser_tab_declared_favicon_url(app.document) == 'https://cdn.example/changed.png'
}

fn test_tab_favicon_decodes_declared_png_and_ico_fallback_without_blocking() {
	icon := 'data:image/png;base64,${tab_favicon_test_png}'
	mut app := tab_favicon_test_app('https://site.example/page', '<link id="icon" rel="icon" href="${icon}">')
	defer { app.document.finalize() }
	first := app.browser_tab_favicon_id()
	assert first >= 0
	assert app.ctx.get_cached_image_by_idx(first).width == 1
	assert app.browser_tab_favicon_id() == first
	mut link := unsafe { &dom.Element(app.document.get_element_by_id('icon')?) }
	link.set_attribute_value('href', 'https://site.example/broken.png')
	app.resource_cache['https://site.example/broken.png'] = PreloadedResource{
		url:          'https://site.example/broken.png'
		source_url:   'https://site.example/page'
		request_type: 'image'
		error:        '404'
	}
	app.resource_cache['https://site.example/favicon.ico'] = PreloadedResource{
		url:  'https://site.example/favicon.ico'
		body: os.read_bytes('${@VMODROOT}/pixel_tests/sites/curl/curl.se/favicon.ico')!.bytestr()
	}
	second := app.browser_tab_favicon_id()
	assert second >= 0 && second != first
	assert app.ctx.get_cached_image_by_idx(second).width == 32
	assert app.browser_text_cache().favicon_fallback
}

fn test_tab_favicon_background_completion_updates_chrome_and_preserves_old_state() {
	mut app := tab_favicon_test_app('https://site.example/page', '')
	defer { app.document.finalize() }
	address := 'https://site.example/favicon.ico'
	// Model an in-flight background fetch without making a network request.
	app.background_resource_pending[address] = true
	before := app.browser_chrome_state(800, 600)
	assert before.tab_favicons == [-1]
	assert !app.browser_text_cache().favicon_complete
	app.background_resource_results <- PreloadedResource{
		url:  address
		body: base64.decode(tab_favicon_test_png).bytestr()
	}
	app.poll_background_resources()
	after := app.browser_chrome_state(800, 600)
	assert after.tab_favicons[0] >= 0
	assert browser_chrome_requires_update(before, after)
	assert before.tab_favicons == [-1]
	assert !browser_chrome_requires_update(after, app.browser_chrome_state(800, 600))
}

fn test_tab_favicons_follow_page_owners_and_clear_after_navigation() {
	icon := 'data:image/png;base64,${tab_favicon_test_png}'
	mut first := tab_favicon_test_app('https://first.example/', '<link id="icon" rel="icon" href="${icon}">')
	mut second := tab_favicon_test_app('vox://newtab', '')
	defer {
		first.document.finalize()
		second.document.finalize()
	}
	second.ctx = first.ctx
	first.initialize_browser_tabs()
	first.tabs.pages << second
	before := first.browser_chrome_state(800, 600)
	assert before.tab_favicons[0] >= 0 && before.tab_favicons[1] == -1
	first.tabs.pages = [second, first]
	after := first.browser_chrome_state(800, 600)
	assert after.tab_favicons == [-1, before.tab_favicons[0]]
	assert before.tab_favicons[1] == -1
	mut old := first.document
	first.document = dom.Document.create(dom.url_about_blank())
	old.finalize()
	assert first.browser_chrome_state(800, 600).tab_favicons == [-1, -1]
}

fn test_shared_ui2_tabs_receive_the_cached_site_favicon_path() {
    icon := 'data:image/png;base64,${tab_favicon_test_png}'
    mut app := tab_favicon_test_app('https://site.example/', '<link rel="icon" href="${icon}">')
    defer { app.document.finalize() }
    strip := app.browser_tab_strip(app.browser_chrome_state(800,600))
    image := strip.children[3].children[0]
    assert image.id == 'tab-icon-0' && os.is_file(image.image_path)
    assert image.frame.width == 16 && image.frame.height == 16
}

fn test_tab_favicon_ignores_unsafe_icons_and_internal_pages() {
	mut app := tab_favicon_test_app('vox://newtab', '<link rel="icon" href="file:///private/icon.png">')
	defer { app.document.finalize() }
	assert app.browser_tab_favicon_id() == -1
	assert app.background_resource_pending.len == 0
}

fn test_tab_favicon_cache_survives_temporary_work_and_reuses_unchanged_state() {
	icon := 'data:image/png;base64,${tab_favicon_test_png}'
	mut app := tab_favicon_test_app('https://site.example/', '<link rel="icon" href="${icon}">')
	defer { app.document.finalize() }
	mut scratch := platform.new_arena('tab favicon ownership fixture')
	defer { scratch.release() }
	entry := scratch.enter()
	before := app.browser_chrome_state(800, 600)
	scratch.leave(entry)
	scratch.reset()
	assert before.tab_favicons[0] >= 0
	assert app.browser_text_cache().favicon_url == icon
	used := platform.thread_arena_usage().used
	for _ in 0 .. 128 {
		after := app.browser_chrome_state(800, 600)
		assert !browser_chrome_requires_update(before, after)
	}
	$if prealloc {
		assert platform.thread_arena_usage().used - used < 1024
	}
}

$if vox_ui2 ? {
	#include "@VMODROOT/native_browser_tabs_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_tabs_has_icon(control voidptr) int
	fn C.native_test_tabs_icon_pixel(control voidptr, x int, y int) u32

	fn test_native_tabs_receive_favicon_and_paint_it_beside_the_title() {
		window := C.native_test_address_window()
		icon := 'data:image/png;base64,${tab_favicon_test_png}'
		mut app := tab_favicon_test_app('https://site.example/', '<link id="icon" rel="icon" href="${icon}">')
		app.mount_ui2_chrome(C.native_test_address_parent(window), 800, 600)!
		defer {
			app.unmount_address_bar()
			app.document.finalize()
			C.native_test_address_close(window)
		}
		assert C.native_test_tabs_has_icon(ui2.embedded_browser_control('tab-0')) == 1
		assert C.native_test_tabs_icon_pixel(ui2.embedded_browser_control('tab-0'), 20, 12) == u32(0x000000ff)
		mut link := unsafe { &dom.Element(app.document.get_element_by_id('icon')?) }
		link.set_attribute_value('rel', 'stylesheet')
		app.document.set_url(dom.url_about_blank())
		app.update_browser_chrome(800, 600)
		assert C.native_test_tabs_has_icon(ui2.embedded_browser_control('tab-0')) == 0
	}
}

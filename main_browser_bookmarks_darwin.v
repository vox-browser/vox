module main

$if vox_ui2 ? {
	import ui2
	import platform
	import optimizedsites

	#include "native_browser_bookmarks_darwin.m"
	fn C.native_browser_bookmarks_begin(toolbar voidptr, owner voidptr, callback fn (voidptr, int, int), visible int, top f64, width f64, version u64, error &u8, error_length int) int
	fn C.native_browser_bookmarks_item(index int, title &u8, title_length int, address &u8, address_length int)
	fn C.native_browser_bookmarks_end(count int)
	fn C.native_browser_bookmarks_remove()
	fn C.native_browser_bookmark_icon(index int, bytes &u8, length int)

	fn (app &BrowserApp) update_native_browser_bookmarks(chrome BrowserChromeState) {
		replay := C.native_browser_bookmarks_begin(ui2.embedded_browser_control('toolbar'), app,
			native_browser_bookmark_action, int(chrome.bookmarks_visible), app.bookmark_bar_top(),
			f64(chrome.width), chrome.bookmarks_version, app.bookmarks_error.str, app.bookmarks_error.len) != 0
		if !chrome.bookmarks_visible { return }
		items := app.browser_bar_bookmarks()
		if replay {
			for index, item in items {
				C.native_browser_bookmarks_item(index, item.title.str, item.title.len, item.url.str, item.url.len)
			}
			C.native_browser_bookmarks_end(items.len)
		}
		// Native images copy encoded bytes; scratch storage never escapes here.
		scratch := platform.begin_thread_scratch('native bookmark favicons')
		defer { scratch.finish() }
		for index, item in items {
			address := browser_bookmark_favicon_url(item.url)
			if optimizedsites.favicon_data_url(item.url) != '' || (index < chrome.bookmark_favicons.len && chrome.bookmark_favicons[index] >= 0) {
				if bytes := app.background_image_bytes(address) {
					C.native_browser_bookmark_icon(index, bytes.data, bytes.len)
					continue
				}
			}
			C.native_browser_bookmark_icon(index, unsafe { nil }, 0)
		}
	}

	fn native_browser_bookmark_action(owner voidptr, action int, index int) {
		mut shell := unsafe { &BrowserApp(owner) }
		mut app := shell.active_browser_tab()
		app.activate_browser_bookmarks('${if action == 0 {
			'bookmark-open'
		} else {
			'bookmark-remove'
		}}:${index}')
	}
}

module main

import bookmarkui
import crypto.sha256
import os
import platform
import stbi
import ui2

fn (app &BrowserApp) browser_bookmark_ui_state(chrome BrowserChromeState) bookmarkui.State {
	if !chrome.bookmarks_visible { return bookmarkui.State{} }
	mut items := []bookmarkui.Item{}
	for index, item in app.browser_bar_bookmarks() {
		icon := if index < chrome.bookmark_favicons.len {
			chrome.bookmark_favicons[index]
		} else {
			-1
		}
		items << bookmarkui.Item{ title: item.title, url: item.url, icon: app.browser_bookmark_icon_path(item.url, icon) }
	}
	return bookmarkui.State{
		width:    chrome.width
		height:   chrome.height
		top:      app.bookmark_bar_top()
		visible:  chrome.bookmarks_visible
		overflow: chrome.bookmark_overflow_open
		error:    chrome.bookmarks_error
		items:    items
	}
}

// UI2's image API takes paths on every backend. Publish a content-addressed PNG
// once, using the browser's existing decoder (including ICO), without another
// request or a platform-specific image control.
fn (app &BrowserApp) browser_bookmark_icon_path(address string, image_id int) string {
	if image_id < 0 { return '' }
	bytes := app.background_image_bytes(app.cached_browser_bookmark_favicon_url(address)) or { return '' }
	return app.browser_ui_icon_path(image_id, bytes)
}

fn (app &BrowserApp) browser_ui_icon_path(image_id int, bytes []u8) string {
	mut cache := app.browser_text_cache()
	if path := cache.bookmark_icon_paths[image_id] { return path }
	path := browser_cache_entry_path(browser_cache_root(), 'bookmark-icons', sha256.hexhash(bytes.bytestr())) + '.png'
	if !os.is_file(path) {
		bitmap := browser_decode_raster_image_bytes(bytes) or { return '' }
		os.mkdir_all(os.dir(path)) or { return '' }
		stbi.stbi_write_png(path, bitmap.width, bitmap.height, 4, bitmap.data.data, bitmap.width * 4) or { return '' }
	}
	persistent := platform.enter_persistent()
	cache.bookmark_icon_paths[image_id] = path.clone()
	platform.leave_persistent(persistent)
	return path
}

fn (app &BrowserApp) browser_chrome_ui_elements(chrome BrowserChromeState) []ui2.Element {
	mut elements := browser_chrome_elements(chrome)
	mut toolbar := elements[0]
	mut toolbar_children := toolbar.children.clone()
	toolbar_children << app.browser_tab_strip(chrome)
	elements[0] = ui2.Element{ ...toolbar, children: toolbar_children }
	// The bar belongs to the toolbar; the overflow floats over the document.
	bookmarks := bookmarkui.elements(app.browser_bookmark_ui_state(chrome))
	if bookmarks.len > 0 {
		bar_toolbar := elements[0]
		mut children := bar_toolbar.children.clone()
		children << bookmarks[0]
		elements[0] = ui2.Element{ ...bar_toolbar, children: children }
		if bookmarks.len > 1 { elements << bookmarks[1..] }
	}
	elements << app.browser_settings_overlay(chrome.width, chrome.height)
	elements << app.browser_popup_elements(chrome.width, chrome.height)
	return elements
}

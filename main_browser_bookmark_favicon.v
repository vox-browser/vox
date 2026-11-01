module main

import dom
import optimizedsites
import platform

fn browser_bookmark_favicon_url(address string) string {
	bundled := optimizedsites.favicon_data_url(address)
	if bundled != '' { return bundled }
	page_url := dom.dom_url_parse(address, dom.url_about_blank(), 'UTF-8') or { return '' }
	if page_url.scheme() !in ['http', 'https'] || !browser_new_tab_allows_favicon_url(page_url) { return '' }
	return (dom.dom_url_parse('/favicon.ico', page_url, 'UTF-8') or { return '' }).serialize()
}

fn (app &BrowserApp) cached_browser_bookmark_favicons() []int {
	mut cache := app.browser_text_cache()
	if !app.bookmark_bar_visible() { return cache.bookmark_favicons }
	items := app.browser_bar_bookmarks()
	mut icons := unsafe { cache.bookmark_favicons }
	mut changed := icons.len != items.len
	if changed { icons = []int{len: items.len, init: -1} }
	for index, item in items {
		address := browser_bookmark_favicon_url(item.url)
		mut icon := -1
		if address != '' && app.ctx != unsafe { nil } {
			mut owner := unsafe { &BrowserApp(app) }
			if image := owner.background_image(address) { icon = image.id }
		}
		if icons[index] == icon { continue }
		if !changed {
			icons = icons.clone()
			changed = true
		}
		icons[index] = icon
	}
	if changed {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		cache.bookmark_favicons = icons.clone()
	}
	return cache.bookmark_favicons
}

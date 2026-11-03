module main

import dom
import gg
import optimizedsites
import os
import platform

// Diagnostic control: route bookmark favicons back through the ordinary
// document image path, whose redirect revalidation re-enters a synchronous
// network fetch from the frame callback. Used only to measure the async fix.
const disable_async_bookmark_favicons = os.getenv('VOX_DISABLE_ASYNC_BOOKMARK_FAVICONS') != ''

fn browser_bookmark_favicon_url(address string) string {
	bundled := optimizedsites.favicon_data_url(address)
	if bundled != '' { return bundled }
	page_url := dom.dom_url_parse(address, dom.url_about_blank(), 'UTF-8') or { return '' }
	if page_url.scheme() !in ['http', 'https'] || !browser_new_tab_allows_favicon_url(page_url) { return '' }
	return (dom.dom_url_parse('/favicon.ico', page_url, 'UTF-8') or { return '' }).serialize()
}

// Bookmark icons are browser chrome that every frame callback consults. This
// lookup never performs synchronous network work: a remote icon is requested
// once in the background, decoded from the retained response when it arrives,
// and remembered as absent after an error or undecodable body. The ordinary
// document image path replays redirected or filtered responses with a blocking
// fetch, which must not run inside the frame callback.
fn (mut app BrowserApp) bookmark_favicon_image(address string) ?&gg.Image {
	mut cache := app.browser_text_cache()
	if image_id := cache.bookmark_favicon_ids[address] {
		if image_id < 0 { return none }
		image := app.ctx.get_cached_image_by_idx(image_id)
		if image.ok { return image }
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if address.starts_with('http://') || address.starts_with('https://') {
		resource := app.resource_cache[address] or {
			app.request_background_resource(address)
			return none
		}
		if resource.error != '' || resource.adblock_replacement {
			cache.bookmark_favicon_ids[address.clone()] = -1
			return none
		}
		// The browser itself requested this icon, so the retained final body is
		// decoded directly; there is no page request to filter hop by hop.
		image := app.create_image_from_resource_bytes(address, resource.body.bytes()) or {
			cache.bookmark_favicon_ids[address.clone()] = -1
			return none
		}
		cache.bookmark_favicon_ids[address.clone()] = image.id
		return app.ctx.get_cached_image_by_idx(image.id)
	}
	// Bundled data URLs decode offline through the ordinary image path.
	image := app.background_image(address) or {
		cache.bookmark_favicon_ids[address.clone()] = -1
		return none
	}
	cache.bookmark_favicon_ids[address.clone()] = image.id
	return image
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
			image := if disable_async_bookmark_favicons {
				owner.background_image(address)
			} else {
				owner.bookmark_favicon_image(address)
			}
			if resolved := image { icon = resolved.id }
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

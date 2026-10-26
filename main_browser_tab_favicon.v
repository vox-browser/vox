module main

import dom
import platform

// Chrome polls only the head and avoids installing a document-owned selector
// cache while favicon discovery is using temporary storage.
fn browser_tab_declared_favicon_url(document &dom.Document) string {
	head := document.head() or { return '' }
	return browser_favicon_url_in_subtree(head.as_node(), document)
}

fn browser_favicon_url_in_subtree(root &dom.Node, document &dom.Document) string {
	mut favicon := ''
	for child in root.children {
		if link := child.as_element() {
			if link.local_name() == 'link' && 'icon' in link_relations(link) {
				href := link.get_attribute_value('href').trim_space()
				if href != '' {
					if address := document.encoding_parse_url(href) {
						if browser_new_tab_allows_favicon_url(address) {
							favicon = address.serialize()
						}
					}
				}
			}
		}
		nested := browser_favicon_url_in_subtree(child, document)
		if nested != '' { favicon = nested }
	}
	return favicon
}

fn browser_tab_fallback_favicon_url(document &dom.Document) string {
	if document.url.scheme() !in ['http', 'https'] { return '' }
	address := dom.dom_url_parse('/favicon.ico', document.url, 'UTF-8') or { return '' }
	return if browser_new_tab_allows_favicon_url(address) { address.serialize() } else { '' }
}

// Keep image ownership with the page, including background tabs. Requests use
// the ordinary asynchronous resource loader, never a synchronous UI fetch.
fn (mut app BrowserApp) browser_tab_favicon_id() int {
	if app.document == unsafe { nil } || app.ctx == unsafe { nil } { return -1 }
	mut discovery := platform.begin_thread_scratch('tab favicon discovery')
	declared := browser_tab_declared_favicon_url(app.document)
	fallback := browser_tab_fallback_favicon_url(app.document)
	address := if declared != '' { declared } else { fallback }
	discovery.leave()
	defer { discovery.finish() }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut cache := app.browser_text_cache()
	if cache.favicon_document_id != app.document.unique_id() || cache.favicon_url != address {
		cache.favicon_document_id = app.document.unique_id()
		cache.favicon_url = address.clone()
		cache.favicon_image_id = -1
		cache.favicon_complete = address == ''
		cache.favicon_fallback = false
	}
	if cache.favicon_complete { return cache.favicon_image_id }
	for _ in 0 .. 2 {
		candidate := if cache.favicon_fallback { fallback } else { address }
		if image := app.background_image(candidate) {
			cache.favicon_image_id = image.id
			cache.favicon_complete = true
			return image.id
		}
		if (candidate.starts_with('http://') || candidate.starts_with('https://'))
			&& candidate !in app.resource_cache {
			return -1
		}
		// A missing or undecodable declared icon may still have an ICO fallback.
		if !cache.favicon_fallback && fallback != '' && fallback != candidate {
			cache.favicon_fallback = true
			continue
		}
		cache.favicon_complete = true
		break
	}
	return -1
}

fn (app &BrowserApp) cached_browser_tab_favicons() []int {
	mut cache := app.browser_text_cache()
	count := app.browser_tab_count()
	mut icons := unsafe { cache.tab_favicons }
	mut changed := icons.len != count
	if changed { icons = []int{len: count, init: -1} }
	for index in 0 .. count {
		if app.process_tabs() {
			address := app.tabs.session.state.tabs[index].favicon
			mut owner := unsafe { &BrowserApp(app) }
			icon := if address != '' {
				if image := owner.background_image(address) { image.id } else { -1 }
			} else {
				-1
			}
			if icons[index] != icon {
				if !changed {
					icons = icons.clone()
					changed = true
				}
				icons[index] = icon
			}
			continue
		}
		mut tab := if app.tabs != unsafe { nil } {
			app.tabs.pages[index]
		} else {
			unsafe { &BrowserApp(app) }
		}
		icon := tab.browser_tab_favicon_id()
		if icons[index] == icon { continue }
		// Previously published chrome states retain their immutable list.
		if !changed {
			icons = icons.clone()
			changed = true
		}
		icons[index] = icon
	}
	if changed {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		cache.tab_favicons = icons.clone()
	}
	return cache.tab_favicons
}

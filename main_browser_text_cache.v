module main

import dom
import platform

@[heap]
struct BrowserChromeTextCache {
mut:
	document_id         dom.UniqueNodeID
	tree_version        u64
	character_version   u64
	title_valid         bool
	title               string
	message             string
	footer              string
	footer_valid        bool
	tab_titles          []string
	favicon_document_id dom.UniqueNodeID
	favicon_url         string
	favicon_image_id    int = -1
	favicon_complete    bool
	favicon_fallback    bool
	tab_favicons        []int
	bookmark_icon_paths map[int]string
	bookmark_favicons   []int
	// Decoded icon per favicon address, or -1 once an address is known to
	// supply no icon. Chrome never retries a failed icon during a frame.
	bookmark_favicon_ids map[string]int
}

fn (app &BrowserApp) browser_text_cache() &BrowserChromeTextCache {
	if app.browser_text_cache_ != unsafe { nil } { return app.browser_text_cache_ }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut owner := unsafe { &BrowserApp(app) }
	owner.browser_text_cache_ = &BrowserChromeTextCache{}
	return owner.browser_text_cache_
}

fn (app &BrowserApp) cached_browser_tab_document_title() string {
	document := app.document
	mut cache := app.browser_text_cache()
	document_id := document.unique_id()
	tree_version := document.dom_tree_version()
	character_version := document.character_data_version()
	if cache.title_valid && cache.document_id == document_id
		&& cache.tree_version == tree_version && cache.character_version == character_version {
		return cache.title
	}
	resolved := document_title(document).replace('\n', ' ').replace('\r', ' ')
	title := if resolved.trim_space() == '' { '' } else { resolved }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	// Chrome owns its text even when the read ran in a document/paint arena.
	if !cache.title_valid || cache.title != title { cache.title = title.clone() }
	// An identity key must not keep a closed tab's retired document reachable.
	cache.document_id = document_id
	cache.tree_version = tree_version
	cache.character_version = character_version
	cache.title_valid = true
	return cache.title
}

fn (app &BrowserApp) cached_browser_console_footer() string {
	message := app.js_messages.last()
	mut cache := app.browser_text_cache()
	if cache.footer_valid && cache.message == message { return cache.footer }
	end := message.index_any('\r\n')
	first := if end < 0 { message } else { unsafe { message.substr_unsafe(0, end) } }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	cache.message = message.clone()
	cache.footer = 'Console: ${first}'
	cache.footer_valid = true
	return cache.footer
}

fn (app &BrowserApp) cached_browser_tab_titles(custom_titles bool) []string {
	mut cache := app.browser_text_cache()
	count := app.browser_tab_count()
	mut unchanged := cache.tab_titles.len == count
	for index in 0 .. count {
		title := app.browser_display_tab_title(index, custom_titles)
		if index >= cache.tab_titles.len || cache.tab_titles[index] != title { unchanged = false }
	}
	if unchanged { return cache.tab_titles }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	// Published chrome states may still hold the preceding list. Replace it
	// only when its values change; keep each published list immutable.
	mut titles := []string{cap: count}
	for index in 0 .. count {
		titles << app.browser_display_tab_title(index, custom_titles).clone()
	}
	cache.tab_titles = titles
	return titles
}

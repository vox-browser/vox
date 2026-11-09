module main

import adblock
import math
import os
import platform
import processmetrics
import runtime

// Like Safari's back/forward cache (WebKit's BackForwardCache), recently left
// pages stay alive: their Document, Window and JavaScript realm, loaders and
// computed styles. Going back or forward to such an entry reactivates the page
// instead of parsing its markup and running its scripts again, so it returns
// with its script state, form contents and scroll position. It also keeps its
// layout tree, as WebKit keeps a cached page's render tree: showing it again
// records its paint commands from the retained layout. A cached page's
// event-loop tasks stay queued and do not run until it is fully active again,
// which freezes its timers.
const back_forward_cache_capacity = 4
const back_forward_cache_disabled = os.getenv('VOX_DISABLE_BACK_FORWARD_CACHE') != ''

struct BrowserBackForwardCache {
mut:
	pages []&BackForwardCachedPage
	// A traversal that missed the cache re-installs its entry's markup. The
	// page it leaves is cached under this history index.
	traversal_from_index int = -1
}

@[heap]
struct BackForwardCachedPage {
	// Entry identity belongs to navigation; every document-owned field stays
	// inside the session, including fields added after this cache was written.
	history_index int
	entry_url     string
	entry_markup  string
	entry_content_type string
	entry_response_headers []adblock.ResponseHeader
	entry_response_status u16
	session       &DocumentSession
}

fn (page &BackForwardCachedPage) matches_history_response(entry HistoryEntry) bool {
	return page.entry_url == entry.url && page.entry_markup == entry.markup
		&& page.entry_content_type == entry.content_type
		&& page.entry_response_headers == entry.response_headers
		&& page.entry_response_status == entry.response_status
}

// Why the displayed page cannot be kept, or '' when it can.
fn (app &BrowserApp) back_forward_cache_blocker() string {
	if back_forward_cache_disabled { return 'disabled' }
	// Captures and layout dumps measure a single navigation.
	if app.layout_tree_only || app.screenshot_path != '' { return 'capture' }
	if app.state != .active || app.document == unsafe { nil } { return 'no document' }
	document := app.document
	if document.has_been_destroyed() || !document.salvageable { return 'unsalvageable' }
	if !document.is_fully_active() { return 'inactive' }
	address := document.url_string()
	if !address.starts_with('https://') && !address.starts_with('http://')
		&& !address.starts_with('file://') {
		return 'scheme'
	}
	if app.load_status == 'Navigation error' { return 'error page' }
	// A page that navigates while it loads, such as a script redirect, runs
	// again when its entry is revisited, as in Safari.
	if document.readiness() == .loading || (app.ctx != unsafe { nil } && !app.document_presented) {
		return 'loading'
	}
	// Compact background requests do not have a suspend/resume contract. A
	// cached page must not retain request flags after their producers retire.
	if app.background_resource_pending.len > 0 { return 'resource requests' }
	// Native players do not survive suspension.
	if app.media_players.len > 0 { return 'media' }
	if children := app.child_document_host {
		for child in children.children {
			if !child.closed { return 'child documents' }
		}
	}
	return ''
}

// install_loaded_page calls this before it replaces the displayed document.
// A page that can be cached leaves with its realm, loaders, computed styles
// and layout; the installation then releases only the shell's paint state.
fn (mut app BrowserApp) suspend_displayed_page_for_back_forward_cache(add_history bool) bool {
	from_index := if add_history { app.history_index } else { app.back_forward_cache.traversal_from_index }
	app.back_forward_cache.traversal_from_index = -1
	if add_history {
		// The new entry replaces every forward entry.
		app.evict_back_forward_cached_pages(.after_index, from_index)
	}
	return app.cache_displayed_page(from_index)
}

fn (mut app BrowserApp) cache_displayed_page(history_index int) bool {
	if history_index < 0 || history_index >= app.history.len || app.back_forward_cache_blocker() != '' {
		return false
	}
	app.evict_back_forward_cached_pages(.at_index, history_index)
	mut session := app.document_session()
	if !session.suspend() { return false }
	entry := app.history[history_index]
	persistent := platform.enter_persistent()
	app.back_forward_cache.pages << &BackForwardCachedPage{
		history_index: history_index
		entry_url: entry.url
		entry_markup: entry.markup
		entry_content_type: entry.content_type
		entry_response_headers: entry.response_headers.clone()
		entry_response_status: entry.response_status
		session: session
	}
	platform.leave_persistent(persistent)
	return true
}

// Enforce bounds after the replacement takes over the navigable. Eviction
// must not retire an outgoing session while activation still needs its origin
// and browsing context, even when the memory budget immediately evicts it.
fn (mut app BrowserApp) enforce_back_forward_cache_limits() {
	for app.back_forward_cache.pages.len > back_forward_cache_capacity {
		mut oldest := app.back_forward_cache.pages[0]
		app.back_forward_cache.pages.delete(0)
		discard_back_forward_cached_page(mut oldest)
	}
	app.trim_back_forward_cache_to_memory_budget()
}

// WebKit sizes its cache by physical memory. A cached page holds its whole
// document, realm and layout, so pages are kept only while the process stays
// within a share of RAM.
fn back_forward_cache_memory_budget() u64 {
	total := u64(runtime.total_memory() or { return u64(4) << 30 })
	return math.min(math.max(total / 4, u64(2) << 30), u64(8) << 30)
}

fn (mut app BrowserApp) trim_back_forward_cache_to_memory_budget() {
	budget := back_forward_cache_memory_budget()
	for app.back_forward_cache.pages.len > 0 {
		snapshot := processmetrics.memory_snapshot()
		if !snapshot.available || snapshot.bytes <= budget { return }
		mut oldest := app.back_forward_cache.pages[0]
		app.back_forward_cache.pages.delete(0)
		discard_back_forward_cached_page(mut oldest)
	}
}

fn (app &BrowserApp) back_forward_cached_page_position(history_index int) int {
	if history_index < 0 || history_index >= app.history.len { return -1 }
	entry := app.history[history_index]
	for position, page in app.back_forward_cache.pages {
		if page.history_index == history_index && page.matches_history_response(entry) {
			return position
		}
	}
	return -1
}

// history_go: show the page cached for history entry `target`. When none is
// cached, the traversal re-installs the entry and the displayed page is cached
// under `from_index` as it leaves.
fn (mut app BrowserApp) restore_back_forward_cached_page(from_index int, target int) bool {
	app.back_forward_cache.traversal_from_index = -1
	app.evict_back_forward_cached_pages(.stale, -1)
	position := app.back_forward_cached_page_position(target)
	if position < 0 || !app.back_forward_cache.pages[position].session.can_resume() {
		if position >= 0 {
			mut unusable := app.back_forward_cache.pages[position]
			app.back_forward_cache.pages.delete(position)
			discard_back_forward_cached_page(mut unusable)
		}
		app.back_forward_cache.traversal_from_index = from_index
		return false
	}
	load_instruction_stage := processmetrics.begin_instruction_stage('back_forward_cache_restore')
	defer { load_instruction_stage.finish() }
	mut incoming := app.back_forward_cache.pages[position].session
	app.back_forward_cache.pages.delete(position)
	app.dismiss_browser_popup()
	mut navigation_work := app.begin_navigation_work()
	defer { navigation_work.finish() }
	mut heap_scope := platform.begin_browser_activity_heap_scope_for_scripting(incoming.document.as_node().is_scripting_enabled())
	defer { heap_scope.finish() }
	entry := app.history[target]
	mut outgoing := app.document_session()
	navigable := if outgoing.document != unsafe { nil } {
		outgoing.document.navigable() or { incoming.cached_navigable }
	} else {
		incoming.cached_navigable
	}
	outgoing_cached := app.cache_displayed_page(from_index)
	app.DocumentSessionRef = incoming
	app.set_browser_zoom(incoming.page_zoom)
	// Publish the complete owner before resume dispatches pageshow. Its
	// handlers must observe the incoming realm, loaders and rendering state.
	if !incoming.resume(navigable) {
		// A pagehide handler can invalidate the candidate. Put the outgoing
		// owner back before falling through to ordinary history reconstruction.
		app.DocumentSessionRef = outgoing
		app.set_browser_zoom(outgoing.page_zoom)
		if outgoing_cached {
			for index, cached in app.back_forward_cache.pages {
				if voidptr(cached.session) == voidptr(outgoing) {
					app.back_forward_cache.pages.delete(index)
					break
				}
			}
			outgoing.resume(navigable)
		}
		incoming.retire()
		app.back_forward_cache.traversal_from_index = from_index
		return false
	}
	if !outgoing_cached { outgoing.retire() }
	app.enforce_back_forward_cache_limits()
	persistent := platform.enter_persistent()
	app.address = entry.url
	platform.leave_persistent(persistent)
	app.address_cursor = app.address.runes().len
	app.address_select = false
	app.sync_address_bar()
	app.pending_editing_scroll = none
	previous_zoom := app.page_zoom
	previous_scroll := app.scroll_y
	app.restore_browser_zoom(entry.url)
	// The cached offset was stored in screen pixels at its previous zoom.
	app.scroll_y = if previous_zoom > 0 { previous_scroll * app.page_zoom / previous_zoom } else { previous_scroll }
	app.screenshot_scroll_applied = false
	app.screenshot_scroll_awaits_content = false
	app.screenshot_initial_viewport_ready = false
	app.initial_layout_pending = false
	app.defer_initial_rendering_opportunity(false)
	app.status = app.load_status
	app.document_presented = false
	app.snapshot_cached = false
	app.record_browser_visit(LoadedPage{ url: entry.url, status: app.load_status, content_type: app.content_type })
	app.relayout(if app.viewport_width > 0 { app.viewport_width } else { initial_width }, if app.viewport_height > 0 {
		app.viewport_height + app.chrome_height()
	} else {
		initial_height
	})
	app.update_window_title()
	if app.js_runtime != unsafe { nil } {
		app.js_runtime.mark_document_state_dirty()
		app.poll_javascript_tasks()
	}
	request_browser_frame()
	return true
}

enum BackForwardCacheEviction {
	all
	at_index
	after_index
	// Pages whose history entry was replaced or removed.
	stale
}

fn (app &BrowserApp) back_forward_cached_page_evicted(page &BackForwardCachedPage, eviction BackForwardCacheEviction, history_index int) bool {
	return match eviction {
		.all { true }
		.at_index { page.history_index == history_index }
		.after_index { page.history_index > history_index }
		.stale {
			page.history_index < 0 || page.history_index >= app.history.len
				|| !page.matches_history_response(app.history[page.history_index])
		}
	}
}

fn (mut app BrowserApp) evict_back_forward_cached_pages(eviction BackForwardCacheEviction, history_index int) {
	mut evicted := []&BackForwardCachedPage{}
	for page in app.back_forward_cache.pages {
		if app.back_forward_cached_page_evicted(page, eviction, history_index) { evicted << page }
	}
	if evicted.len == 0 { return }
	persistent := platform.enter_persistent()
	mut kept := []&BackForwardCachedPage{cap: app.back_forward_cache.pages.len - evicted.len}
	for page in app.back_forward_cache.pages {
		if !app.back_forward_cached_page_evicted(page, eviction, history_index) { kept << page }
	}
	app.back_forward_cache.pages = kept
	platform.leave_persistent(persistent)
	for mut page in evicted { discard_back_forward_cached_page(mut page) }
}

fn (mut app BrowserApp) clear_back_forward_cache() {
	app.back_forward_cache.traversal_from_index = -1
	app.evict_back_forward_cached_pages(.all, -1)
}

// Cache eviction and active-page retirement share the same ownership boundary.
fn discard_back_forward_cached_page(mut page BackForwardCachedPage) {
	mut session := page.session
	session.retire()
}

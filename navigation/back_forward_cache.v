module main

import browserjs
import css
import dom
import html
import layout
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
	// The history entry the page was left from. An entry with another URL or
	// markup at this index belongs to a different page.
	history_index int
	entry_url     string
	entry_markup  string
	document      &dom.Document = unsafe { nil }
	navigable     &dom.Navigable = unsafe { nil }
	// Whether the page had finished loading and was showing when it was left.
	page_showing bool
mut:
	js_runtime                     &browserjs.Runtime = unsafe { nil }
	image_request_loader           ?&BrowserImageRequestLoader
	script_request_loader          ?&BrowserScriptRequestLoader
	child_document_host            ?&BrowserChildDocumentHost
	resource_cache                 map[string]PreloadedResource
	markup                         string
	content_type                   string
	source_label                   string
	load_status                    string
	scroll_y                       f64
	page_zoom                      f64 = 1
	js_messages                    []string
	animation_epoch_ns             u64
	script_stylesheet_requests     map[string]bool
	script_stylesheet_links        map[dom.UniqueNodeID]string
	script_stylesheet_responses    map[string]PreloadedResource
	script_stylesheet_scan_version u64
	script_image_scan_version      u64
}

// Why the displayed page cannot be kept, or '' when it can.
fn (app &BrowserApp) back_forward_cache_blocker() string {
	if back_forward_cache_disabled { return 'disabled' }
	// Captures and layout dumps measure a single navigation.
	if app.layout_tree_only || app.screenshot_path != '' { return 'capture' }
	if app.document == unsafe { nil } { return 'no document' }
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
	navigable := app.document.navigable() or { return false }
	app.evict_back_forward_cached_pages(.at_index, history_index)
	entry := app.history[history_index]
	page_showing := app.document.document_page_showing()
	html.suspend_document_for_back_forward_cache(app.document)
	if app.js_runtime != unsafe { nil } {
		// A script navigation that led away from the page was consumed then.
		// The compact facade keeps the request until its realm closes; a
		// restored realm would otherwise replay it and leave the page again.
		app.js_runtime.evaluate_host('typeof __ladybirdClearNavigation==="function"&&__ladybirdClearNavigation()') or {}
	}
	if app.js_runtime != unsafe { nil } && app.js_runtime.engine == .libjs {
		mut agent_event_loop := html.main_thread_event_loop()
		agent_event_loop.bind_vm(none)
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	app.back_forward_cache.pages << &BackForwardCachedPage{
		history_index:                  history_index
		entry_url:                      entry.url
		entry_markup:                   entry.markup
		document:                       app.document
		navigable:                      navigable
		page_showing:                   page_showing
		js_runtime:                     app.js_runtime
		image_request_loader:           app.image_request_loader
		script_request_loader:          app.script_request_loader
		child_document_host:            app.child_document_host
		resource_cache:                 app.resource_cache
		markup:                         app.markup
		content_type:                   app.content_type
		source_label:                   app.source_label
		load_status:                    app.load_status
		scroll_y:                       app.scroll_y
		page_zoom:                      app.page_zoom
		js_messages:                    app.js_messages
		animation_epoch_ns:             app.animation_epoch_ns
		script_stylesheet_requests:     app.script_stylesheet_requests
		script_stylesheet_links:        app.script_stylesheet_links
		script_stylesheet_responses:    app.script_stylesheet_responses
		script_stylesheet_scan_version: app.script_stylesheet_scan_version
		script_image_scan_version:      app.script_image_scan_version
	}
	// The cached page owns these now. app.document remains the outgoing
	// document until its replacement takes over the navigable.
	app.js_runtime = unsafe { nil }
	app.image_request_loader = none
	app.script_request_loader = none
	app.child_document_host = none
	app.resource_cache = map[string]PreloadedResource{}
	app.js_messages = []string{}
	app.script_stylesheet_requests = map[string]bool{}
	app.script_stylesheet_links = map[dom.UniqueNodeID]string{}
	app.script_stylesheet_responses = map[string]PreloadedResource{}
	for app.back_forward_cache.pages.len > back_forward_cache_capacity {
		mut oldest := app.back_forward_cache.pages[0]
		app.back_forward_cache.pages.delete(0)
		discard_back_forward_cached_page(mut oldest)
	}
	app.trim_back_forward_cache_to_memory_budget()
	return true
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
		if page.history_index == history_index && page.entry_url == entry.url
			&& page.entry_markup == entry.markup {
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
	// Entries that history changes have replaced no longer have a page.
	app.evict_back_forward_cached_pages(.stale, -1)
	position := app.back_forward_cached_page_position(target)
	if position < 0 || !html.can_reactivate_back_forward_cached_document(app.back_forward_cache.pages[position].document) {
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
	mut page := app.back_forward_cache.pages[position]
	app.back_forward_cache.pages.delete(position)
	app.dismiss_browser_popup()
	mut navigation_work := app.begin_navigation_work()
	defer { navigation_work.finish() }
	mut heap_scope := platform.begin_browser_activity_heap_scope_for_scripting(page.document.as_node().is_scripting_enabled())
	defer { heap_scope.finish() }
	entry := app.history[target]
	outgoing := app.document
	navigable := if outgoing != unsafe { nil } {
		outgoing.navigable() or { page.navigable }
	} else {
		page.navigable
	}
	outgoing_layout := if outgoing != unsafe { nil } { outgoing.layout_engine_handle() } else { unsafe { nil } }
	outgoing_cached := app.cache_displayed_page(from_index)
	app.cancel_background_resource_fetches()
	if !outgoing_cached && app.js_runtime != unsafe { nil } {
		if app.js_runtime.engine == .libjs {
			mut agent_event_loop := html.main_thread_event_loop()
			agent_event_loop.bind_vm(none)
		}
		app.js_runtime.close()
		app.js_runtime = unsafe { nil }
	}
	html.reactivate_back_forward_cached_document(page.document, navigable, page.page_showing)
	// The outgoing page is no longer active; release what the shell holds for it.
	app.close_media_playback()
	if !outgoing_cached {
		if mut loader := app.image_request_loader { loader.cancel() }
		if mut loader := app.script_request_loader { loader.cancel() }
		if mut children := app.child_document_host { children.close() }
	}
	if outgoing != unsafe { nil } && !outgoing_cached {
		app.retire_native_document_rendering(outgoing)
		if outgoing.native_storage() != unsafe { nil } {
			mut retiring := unsafe { &dom.Document(outgoing) }
			retiring.destroy_a_document_and_its_descendants()
			retiring.finalize()
			layout.retire_native_document_layout(outgoing_layout)
			retiring.release_native_storage()
		}
	} else {
		// A cached page keeps its layout result with its document.
		app.release_document_rendering()
	}
	app.adblock_tokens.release()
	persistent := platform.enter_persistent()
	app.document = page.document
	app.js_runtime = page.js_runtime
	app.image_request_loader = page.image_request_loader
	app.script_request_loader = page.script_request_loader
	app.child_document_host = page.child_document_host
	app.resource_cache = page.resource_cache
	app.markup = page.markup
	app.content_type = page.content_type
	app.source_label = page.source_label
	app.js_messages = page.js_messages
	app.animation_epoch_ns = page.animation_epoch_ns
	app.script_stylesheet_requests = page.script_stylesheet_requests
	app.script_stylesheet_links = page.script_stylesheet_links
	app.script_stylesheet_responses = page.script_stylesheet_responses
	app.script_stylesheet_scan_version = page.script_stylesheet_scan_version
	app.script_image_scan_version = page.script_image_scan_version
	app.address = entry.url
	platform.leave_persistent(persistent)
	if app.js_runtime != unsafe { nil } && app.js_runtime.engine == .libjs {
		mut agent_event_loop := html.main_thread_event_loop()
		agent_event_loop.bind_vm(app.js_runtime.libjs_vm())
	}
	app.address_cursor = app.address.runes().len
	app.address_select = false
	app.sync_address_bar()
	app.pending_editing_scroll = none
	app.restore_browser_zoom(entry.url)
	// The offset is kept in screen pixels at the page's zoom then.
	app.scroll_y = if page.page_zoom > 0 { page.scroll_y * app.page_zoom / page.page_zoom } else { page.scroll_y }
	app.screenshot_scroll_applied = false
	app.screenshot_scroll_awaits_content = false
	app.screenshot_initial_viewport_ready = false
	app.initial_layout_pending = false
	app.defer_initial_rendering_opportunity(false)
	app.load_status = page.load_status
	app.status = page.load_status
	app.document_presented = false
	app.snapshot_cached = false
	// Its layout is current unless the viewport or zoom changed meanwhile;
	// run_document_layout then restyles and lays it out again.
	app.record_browser_visit(LoadedPage{ url: entry.url, status: page.load_status, content_type: page.content_type })
	app.relayout(if app.viewport_width > 0 { app.viewport_width } else { initial_width }, if app.viewport_height > 0 {
		app.viewport_height + app.chrome_height()
	} else {
		initial_height
	})
	app.update_window_title()
	if app.js_runtime != unsafe { nil } {
		// pageshow and the tasks that resume can change the page.
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
				|| app.history[page.history_index].url != page.entry_url
				|| app.history[page.history_index].markup != page.entry_markup
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

// Retire a cached page as install_loaded_page retires a replaced document.
fn discard_back_forward_cached_page(mut page BackForwardCachedPage) {
	if mut loader := page.image_request_loader { loader.cancel() }
	page.image_request_loader = none
	if mut loader := page.script_request_loader { loader.cancel() }
	page.script_request_loader = none
	if mut children := page.child_document_host { children.close() }
	page.child_document_host = none
	if page.js_runtime != unsafe { nil } {
		mut script_runtime := page.js_runtime
		script_runtime.close()
		page.js_runtime = unsafe { nil }
	}
	document := page.document
	if document == unsafe { nil } || document.has_been_destroyed() { return }
	_ = css.discard_native_document_computed_styles(document)
	// Destruction also cancels the tasks the page left queued.
	mut retiring := unsafe { &dom.Document(document) }
	layout_handle := retiring.layout_engine_handle()
	retiring.destroy_a_document_and_its_descendants()
	retiring.finalize()
	if retiring.native_storage() != unsafe { nil } {
		layout.retire_native_document_layout(layout_handle)
		retiring.release_native_storage()
	}
}

module main

import browsertabs
import gg
import layout
import math
import os
import page
import platform

const tab_strip_height = 29.0
const tab_strip_leading_width = 62.0

// GUI tabs own separate processes; only tab-strip metadata is shared. The
// page list also supports non-windowed fixtures with stable callback owners.
@[heap]
struct BrowserTabs {
mut:
	session                 &browsertabs.Session = unsafe { nil }
	process_timer           &platform.Timer      = unsafe { nil }
	process_visible         bool
	process_initializing    bool
	profile_refresh_at      i64
	polling_process         bool
	close_after_replacement bool
	closing_process         bool
	process_icon_id         int = -1
	process_icon            string
	pages                   []&BrowserApp
	selected                int
	pending_actions         []string
	drag                    ?BrowserTabDrag
	pending_detaches        []PendingTabDetach
	open_window             fn (string) ! = open_detached_browser_window
}

struct BrowserTabDrag {
	process_id string
	page       &BrowserApp = unsafe { nil }
	first      int
	end        int
	width      f64
	start      f64
	start_y    f64
	offset     f64
mut:
	x         f64
	target    int
	moving    bool
	cancelled bool
}

fn (mut app BrowserApp) initialize_browser_tabs() {
	if app.tabs != unsafe { nil } { return }
	app.ensure_browser_zoom_levels()
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	app.tabs = &BrowserTabs{ pages: [unsafe { &BrowserApp(app) }] }
}

fn (app &BrowserApp) active_browser_tab() &BrowserApp {
	if app.tabs == unsafe { nil } || app.tabs.pages.len == 0 {
		return unsafe { &BrowserApp(app) }
	}
	return app.tabs.pages[app.tabs.selected]
}

fn (app &BrowserApp) is_active_browser_tab() bool {
	return voidptr(app.active_browser_tab()) == voidptr(app)
}

fn (app &BrowserApp) browser_tabs_busy() bool {
	if app.tabs == unsafe { nil } { return app.navigation_work_depth > 0 }
	for tab in app.tabs.pages {
		if tab.navigation_work_depth > 0 { return true }
	}
	return false
}

fn (app &BrowserApp) browser_tab_title() string {
	if app.document != unsafe { nil } {
		title := app.cached_browser_tab_document_title()
		if title != '' { return title }
	}
	if app.address == '' || app.address == 'about:blank' { return 'New Tab' }
	return app.address
}

fn browser_tab_width(width int, count int) f64 {
	return math.min(184.0, math.max(72.0, (f64(width) - tab_strip_leading_width - 44) / f64(math.max(1, count))))
}

// At high tab counts show a sliding range containing the active tab. The
// new-tab control remains reachable; keyboard cycling reaches every tab.
fn browser_visible_tabs(width int, count int, selected int) (int, int) {
	capacity := math.max(1, int((f64(width) - tab_strip_leading_width - 44) / 72))
	visible := math.min(count, capacity)
	first := math.max(0, selected - visible + 1)
	return first, math.min(count, first + visible)
}

fn (mut app BrowserApp) activate_tab_chrome(action string) {
	app.initialize_browser_tabs()
	if app.browser_tabs_busy() || platform.arena_entered() {
		// Native callbacks can arrive during a document or replay allocation
		// scope. Create/destroy tabs only after that scope has unwound; their
		// Page clients and shared tab list outlive every document in the window.
		persistent := platform.enter_persistent()
		app.tabs.pending_actions << action.clone()
		platform.leave_persistent(persistent)
		request_browser_frame()
		return
	}
	app.start_process_tabs()
	if app.process_tabs() {
		app.activate_process_tab(action)
		return
	}
	mut current := app.active_browser_tab()
	if action.starts_with('tab-open:') || action.starts_with('tab-open-background:') {
		previous := app.tabs.selected
		app.activate_tab_chrome('tab-new')
		mut opened := app.active_browser_tab()
		opened.blur_address_bar()
		opened.navigate(action.all_after(':'), true)
		if action.starts_with('tab-open-background:') { app.select_browser_tab(previous) }
		return
	}
	match action {
		'tab-new' {
			owner := page.Page.create(1.0) or { return }
			mut client := owner.client()
			client.set_event_recording(false)
			mut tab := &BrowserApp{
				restrict_to_optimized_sites:     current.restrict_to_optimized_sites
				tabs:                           app.tabs
				zoom_levels:                    current.zoom_levels
				browsing_history:               current.browsing_history
				browsing_history_error:         current.browsing_history_error
				bookmarks:                      current.bookmarks
				bookmarks_error:                current.bookmarks_error
				ctx:                            current.ctx
				page_model:                     owner
				js_engine:                      current.js_engine
				script_policy:                  current.script_policy
				use_document_font:              current.use_document_font
				paint_canvas_culling_disabled:  current.paint_canvas_culling_disabled
				viewport_width:                 current.viewport_width
				viewport_height:                current.viewport_height
				chrome_debug:                   current.chrome_debug
				native_address_bar:             current.native_address_bar
				initial_window_frame_presented: true
				navigation_results:             chan NavigationResult{cap: 4}
				background_resource_results:    chan PreloadedResource{cap: max_cached_resources}
			}
			tab.install_document_frame_request_hook()
			tab.install_chrome_widget_input_bridge()
			app.tabs.pages << tab
			app.select_browser_tab(app.tabs.pages.len - 1)
			tab.install_loaded_page(LoadedPage{
				url:          browser_new_tab_url
				content_type: 'text/html'
				status:       'New Tab'
			}, true)
			tab.address = ''
			tab.sync_address_bar()
			tab.focus_address_bar()
		}
		'tab-next' { app.select_browser_tab((app.tabs.selected + 1) % app.tabs.pages.len) }
		'tab-previous' {
			app.select_browser_tab((app.tabs.selected + app.tabs.pages.len - 1) % app.tabs.pages.len)
		}
		'tab-last' { app.select_browser_tab(app.tabs.pages.len - 1) }
		'tab-close' { app.close_browser_tab(app.tabs.selected) }
		else {
			if action.starts_with('tab-select:') {
				app.select_browser_tab(action.all_after(':').int())
			} else if action.starts_with('tab-close:') {
				app.close_browser_tab(action.all_after(':').int())
			} else if action.starts_with('tab-move:') {
				indices := action.all_after(':').split(':')
				if indices.len == 2 { app.move_browser_tab(indices[0].int(), indices[1].int()) }
			} else if action.starts_with('tab-detach:') {
				app.detach_browser_tab(action.all_after(':').int())
			}
		}
	}
	request_browser_frame()
}

fn (mut app BrowserApp) move_browser_tab(from int, to int) {
	if app.tabs == unsafe { nil } || from < 0 || to < 0
		|| from >= app.tabs.pages.len || to >= app.tabs.pages.len {
		return
	}
	// Move owners, never their contents: document callbacks retain these addresses.
	moving := app.tabs.pages[from]
	if from < to {
		for i in from .. to { app.tabs.pages[i] = app.tabs.pages[i + 1] }
	} else {
		for i := from; i > to; i-- { app.tabs.pages[i] = app.tabs.pages[i - 1] }
	}
	app.tabs.pages[to] = moving
	if app.tabs.selected == from {
		app.tabs.selected = to
	} else if from < app.tabs.selected && app.tabs.selected <= to {
		app.tabs.selected--
	} else if to <= app.tabs.selected && app.tabs.selected < from {
		app.tabs.selected++
	}
	mut selected := app.active_browser_tab()
	$if macos {
		C.native_hide_cached_snapshot()
	}
	selected.snapshot_visible = false
	selected.snapshot_hold = false
	selected.snapshot_cached = true
	chrome := selected.browser_chrome
	selected.browser_chrome = BrowserChromeState{}
	selected.update_browser_chrome(chrome.width, chrome.height)
}

fn (mut app BrowserApp) select_browser_tab(index int) {
	if app.tabs == unsafe { nil } || index < 0 || index >= app.tabs.pages.len { return }
	mut previous := app.active_browser_tab()
	$if linux || ui2_custom_rendering ? { previous.stop_browser_memory_chrome() }
	previous.dismiss_browser_popup()
	previous.blur_address_bar()
	previous.hovered_link = ''
	if previous.document != unsafe { nil } {
		previous.document.set_embedder_window_active(false)
		previous.document.update_the_visibility_state(.hidden)
	}
	$if macos {
		C.native_hide_cached_snapshot()
	}
	previous.snapshot_visible = false
	previous.snapshot_hold = false
	app.tabs.selected = index
	mut selected := app.active_browser_tab()
	selected.chrome_debug = previous.chrome_debug
	selected.browser_chrome = BrowserChromeState{}
	selected.snapshot_cached = true // Window snapshots contain a particular tab strip.
	selected.sync_address_bar()
	selected.sync_window_activity()
	if selected.document != unsafe { nil } {
		selected.document.update_the_visibility_state(.visible)
	}
	selected.update_window_title()
	if selected.ctx != unsafe { nil } {
		size := browser_window_size()
		selected.update_browser_chrome(size.width, size.height)
	}
}

fn (mut app BrowserApp) close_browser_tab(index int) {
	if app.tabs == unsafe { nil } || index < 0 || index >= app.tabs.pages.len { return }
	app.tabs.drag = none
	// Keep a useful window when its final tab is closed.
	if app.tabs.pages.len == 1 { app.activate_tab_chrome('tab-new') }
	mut closing := app.tabs.pages[index]
	was_selected := app.tabs.selected == index
	if was_selected { closing.blur_address_bar() }
	app.tabs.pages.delete(index)
	if app.tabs.selected > index { app.tabs.selected-- }
	app.tabs.selected = math.min(app.tabs.selected, app.tabs.pages.len - 1)
	closing.dispose_browser_tab()
	if was_selected {
		app.select_browser_tab(app.tabs.selected)
	} else {
		mut selected := app.active_browser_tab()
		selected.update_browser_chrome(selected.browser_chrome.width, selected.browser_chrome.height)
	}
}

fn (mut app BrowserApp) dispose_browser_tab() {
	$if linux || ui2_custom_rendering ? { app.stop_browser_memory_chrome() }
	app.dismiss_browser_popup()
	app.release_native_replay_scratch()
	mut retiring := app.document
	layout_handle := if retiring != unsafe { nil } {
		retiring.layout_engine_handle()
	} else {
		unsafe { nil }
	}
	app.navigation_generation++
	app.pending_navigation = none
	app.cancel_page_preload()
	app.pending_native_navigation = none
	app.deferred_page_input = []DeferredPageInput{}
	if mut loader := app.image_request_loader { loader.cancel() }
	app.image_request_loader = none
	if mut loader := app.script_request_loader { loader.cancel() }
	app.script_request_loader = none
	if app.js_runtime != unsafe { nil } {
		app.js_runtime.close()
		app.js_runtime = unsafe { nil }
	}
	if retiring != unsafe { nil } {
		retiring.destroy_a_document_and_its_descendants()
		retiring.finalize()
	}
	app.document = unsafe { nil }
	app.page_model = unsafe { nil }
	// The original tab remains the window callback owner after it closes.
	// Release its retained page graph as well as the live Document pointer.
	app.root_box = layout.BlockBox{}
	layout.release_paint_tree(app.paint_tree_storage)
	app.paint_tree_storage = unsafe { nil }
	app.release_paint_commands()
	layout.retire_native_document_layout(layout_handle)
	if retiring != unsafe { nil } { retiring.release_native_storage() }
	app.chromium_raster_plan = layout.ChromiumRasterLayerPlan{}
	app.chromium_raster_tiles = [][]i32{}
	app.history = []HistoryEntry{}
	app.resource_cache = map[string]PreloadedResource{}
	app.markup = ''
}

fn (mut app BrowserApp) draw_browser_tabs() {
	app.start_process_tabs()
	$if macos {
		if app.ctx != unsafe { nil } && app.ctx.native_rendering
			&& C.vox_browser_has_paint_context() == 0 {
			return
		}
	}
	if app.browser_tabs_busy() || platform.arena_entered() {
		// Cooperative navigation can consume a redraw while servicing AppKit.
		// Keep queued tab actions scheduled until the owning work scope unwinds.
		$if macos {
			C.native_wake_browser_after(16)
		}
		return
	}
	if !app.browser_tabs_busy() && app.tabs != unsafe { nil } {
		pending := app.tabs.pending_actions.clone()
		app.tabs.pending_actions.clear()
		for action in pending { app.activate_tab_chrome(action) }
	}
	app.poll_process_tabs()
	app.poll_detached_tab_windows()
	mut active := app.active_browser_tab()
	if app.tabs != unsafe { nil } {
		for i in 0 .. app.tabs.pages.len {
			mut tab := app.tabs.pages[i]
			if voidptr(tab) != voidptr(active) { tab.poll_background_browser_tab() }
		}
	}
	active.draw()
}

fn (mut app BrowserApp) poll_background_browser_tab() {
	mut work := app.begin_navigation_work()
	defer { work.finish() }
	app.start_pending_navigation()
	app.poll_navigation_and_background_resources()
	app.poll_javascript_tasks()
	if app.document != unsafe { nil } {
		app.document.update_the_visibility_state(.hidden)
		app.document.set_embedder_window_active(false)
	}
}

fn (mut app BrowserApp) cleanup_browser_tabs() {
	if app.process_tabs() {
		if app.tabs.process_timer != unsafe { nil } { app.tabs.process_timer.stop() }
		if app.tabs.closing_process {
			app.tabs.session.leave() or {}
		} else {
			app.tabs.session.shutdown() or {}
		}
	}
	app.unmount_address_bar()
	if app.tabs != unsafe { nil } {
		for pending in app.tabs.pending_detaches { os.rmdir_all(pending.folder) or {} }
		app.tabs.pending_detaches.clear()
		for mut tab in app.tabs.pages { tab.dispose_browser_tab() }
		app.tabs.pages.clear()
	}
}

fn browser_tab_shortcut(key gg.KeyCode, modifier gg.Modifier) string {
	command := modifier.has(.super) || modifier.has(.ctrl)
	if modifier.has(.alt) { return '' }
	if command && !modifier.has(.shift) {
		if key == .t { return 'tab-new' }
		if key == .w { return 'tab-close' }
		if int(key) >= int(gg.KeyCode._1) && int(key) <= int(gg.KeyCode._8) {
			return 'tab-select:${int(key) - int(gg.KeyCode._1)}'
		}
		if key == ._9 { return 'tab-last' }
	}
	if modifier.has(.ctrl) && key == .tab {
		return if modifier.has(.shift) { 'tab-previous' } else { 'tab-next' }
	}
	if modifier.has(.super) && modifier.has(.shift) {
		if key == .left_bracket { return 'tab-previous' }
		if key == .right_bracket { return 'tab-next' }
	}
	return ''
}

fn (app &BrowserApp) browser_tab_snapshot_key() string {
	if app.process_tabs() { return app.tabs.session.encoded_state() }
	if app.tabs == unsafe { nil } { return 'single' }
	mut parts := ['${app.tabs.selected}']
	for tab in app.tabs.pages { parts << '${tab.address}:${tab.browser_tab_title()}' }
	return parts.join('\n')
}

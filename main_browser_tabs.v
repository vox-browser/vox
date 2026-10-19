module main

import gg
import layout
import math
import page

const tab_strip_height = 29.0
const tab_strip_leading_width = 62.0

// Each tab keeps a stable BrowserApp address: document and platform callbacks
// retain that owner. Only the window and its chrome are shared.
@[heap]
struct BrowserTabs {
mut:
	pages           []&BrowserApp
	selected        int
	pending_actions []string
}

fn (mut app BrowserApp) initialize_browser_tabs() {
	if app.tabs != unsafe { nil } { return }
	app.tabs = &BrowserTabs{ pages: [unsafe { &BrowserApp(app) }] }
}

fn (app &BrowserApp) active_browser_tab() &BrowserApp {
	if app.tabs == unsafe { nil } || app.tabs.pages.len == 0 {
		return unsafe { &BrowserApp(app) }
	}
	return app.tabs.pages[app.tabs.selected]
}

fn (app &BrowserApp) is_active_browser_tab() bool {
	return app.active_browser_tab() == app
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
		title := document_title(app.document).replace('\n', ' ').replace('\r', ' ')
		if title.trim_space() != '' { return title }
	}
	if app.address in ['', 'about:blank'] { return 'New Tab' }
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
	if app.browser_tabs_busy() {
		app.tabs.pending_actions << action
		request_browser_frame()
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
			client.set_request_frame_hook(request_browser_frame)
			mut tab := &BrowserApp{
				tabs:                           app.tabs
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
			tab.install_chrome_widget_input_bridge()
			app.tabs.pages << tab
			app.select_browser_tab(app.tabs.pages.len - 1)
			tab.install_loaded_page(LoadedPage{
				url:          'about:blank'
				markup:       '<!doctype html><html><head><title>New Tab</title></head><body></body></html>'
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
			}
		}
	}
	request_browser_frame()
}

fn (mut app BrowserApp) select_browser_tab(index int) {
	if app.tabs == unsafe { nil } || index < 0 || index >= app.tabs.pages.len { return }
	mut previous := app.active_browser_tab()
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
	app.navigation_generation++
	app.pending_navigation = none
	app.pending_cached_page = none
	app.cancel_page_preload()
	app.pending_native_navigation = none
	app.deferred_page_input = []DeferredPageInput{}
	if app.document != unsafe { nil } {
		app.document.destroy_a_document_and_its_descendants()
		app.document.finalize()
	}
	if app.js_runtime != unsafe { nil } {
		app.js_runtime.close()
		app.js_runtime = unsafe { nil }
	}
	app.document = unsafe { nil }
	app.page_model = unsafe { nil }
	// The original tab remains the window callback owner after it closes.
	// Release its retained page graph as well as the live Document pointer.
	app.root_box = layout.BlockBox{}
	app.paint_display_list = unsafe { nil }
	app.paint_commands = []layout.PaintCommand{}
	app.chromium_raster_plan = layout.ChromiumRasterLayerPlan{}
	app.chromium_raster_tiles = [][]int{}
	app.history = []HistoryEntry{}
	app.resource_cache = map[string]PreloadedResource{}
	app.markup = ''
}

fn (mut app BrowserApp) draw_browser_tabs() {
	$if macos {
		if app.ctx != unsafe { nil } && app.ctx.native_rendering
			&& C.vox_browser_has_paint_context() == 0 {
			return
		}
	}
	if app.browser_tabs_busy() {
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
	app.install_pending_cached_page()
	app.start_pending_navigation()
	app.poll_navigation()
	app.poll_navigation_and_background_resources(true)
	app.poll_javascript_tasks()
	if app.document != unsafe { nil } {
		app.document.update_the_visibility_state(.hidden)
		app.document.set_embedder_window_active(false)
	}
}

fn (mut app BrowserApp) cleanup_browser_tabs() {
	app.unmount_address_bar()
	if app.tabs != unsafe { nil } {
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
	if app.tabs == unsafe { nil } { return 'single' }
	mut parts := ['${app.tabs.selected}']
	for tab in app.tabs.pages { parts << '${tab.address}:${tab.browser_tab_title()}' }
	return parts.join('\n')
}

module main

import browserui
import platform
import ui2

fn (app &BrowserApp) browser_document_loading() bool {
	if pending := app.pending_navigation {
		if pending.generation == app.navigation_generation { return true }
	}
	if app.has_navigation_fetch_in_flight() { return true }
	if pending := app.pending_page_preload {
		if pending.generation == app.navigation_generation { return true }
	}
	return app.document != unsafe { nil }
		&& (app.document.readiness() != .complete || app.document.anything_is_delaying_the_load_event())
}

fn (app &BrowserApp) browser_tab_loading_states() []bool {
	// Chrome outlives the frame scratch. Keep immutable snapshots in persistent
	// storage, and allocate only when a tab's state or the tab count changes.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut state := app.browser_ui()
	count := app.browser_tab_count()
	mut states := unsafe { state.tab_loading }
	mut changed := states.len != count
	if changed { states = []bool{len: count} }
	for index in 0 .. count {
		loading := app.browser_tab_is_loading(index)
		if states[index] != loading {
			if !changed {
				states = states.clone()
				changed = true
			}
			states[index] = loading
		}
	}
	if changed { state.tab_loading = states }
	return state.tab_loading
}

fn (app &BrowserApp) browser_tab_is_loading(index int) bool {
	if app.process_tabs() {
		tab := app.tabs.session.state.tabs[index]
		return if tab.id == app.tabs.session.id {
			app.browser_document_loading()
		} else {
			tab.loading
		}
	}
	tab := if app.tabs == unsafe { nil } { app } else { app.tabs.pages[index] }
	return tab.browser_document_loading()
}

fn (mut app BrowserApp) sync_browser_tab_loading_animation(chrome BrowserChromeState) {
	first, end := browser_visible_tabs(chrome.width, chrome.tab_titles.len, chrome.selected_tab)
	mut loading := false
	for index in first .. end {
		if index < chrome.tab_loading.len && chrome.tab_loading[index] {
			loading = true
			break
		}
	}
	if app.process_tabs() && !app.tabs.process_visible { loading = false }
	if !loading {
		app.stop_browser_tab_loading_animation()
		return
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut state := app.browser_ui()
	if state.tab_loading_timer == unsafe { nil } {
		owner := voidptr(&app)
		state.tab_loading_timer = platform.Timer.create_repeating(16, fn [owner] () {
			mut app := unsafe { &BrowserApp(owner) }
			app.animate_browser_tab_loading()
		})
	}
	state.tab_loading_timer.start()
}

fn (mut app BrowserApp) stop_browser_tab_loading_animation() {
	if app.browser_ui_ == unsafe { nil } { return }
	mut state := app.browser_ui()
	if state.tab_loading_timer != unsafe { nil } { state.tab_loading_timer.stop() }
}

fn (mut app BrowserApp) animate_browser_tab_loading() {
	if app.browser_tabs_busy() || platform.arena_entered() { return }
	$if vox_ui2 ? {
		if !app.native_address_bar || !ui2.embedded_control_attached('tab-strip') {
			app.stop_browser_tab_loading_animation()
			return
		}
	}
	mut state := app.browser_ui()
	state.tab_loading_frame = (state.tab_loading_frame + 1) % 60
	$if vox_ui2 ? {
		// Reconcile load completion normally, then refresh only the animated icons.
		// The address editor, tab actions and document pixels stay untouched.
		app.update_browser_chrome(app.browser_chrome.width, app.browser_chrome.height)
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		for index, loading in app.browser_chrome.tab_loading {
			if loading {
				icon := browserui.tab_loading_icon(index, state.tab_loading_frame)
				ui2.refresh_element(icon.id, icon)
			}
		}
	} $else {
		request_browser_frame()
	}
}

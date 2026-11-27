module main

import platform
import time

// Background tabs that stay invisible longer than this are hibernated: their
// live document, scripts and caches are discarded while the tab keeps its
// address, history and form values. Selecting the tab restores them.
const tab_hibernation_timeout_ns = i64(30) * 60 * 1_000_000_000

struct HibernatedTab {
	session       DetachedTabSession
	title         string
	hibernated_at i64
}

// is_browser_tab_hibernated reports whether a tab's live content is
// currently discarded. The selected tab is never hibernated.
fn (app &BrowserApp) is_browser_tab_hibernated(index int) bool {
	if app.process_tabs() {
		if app.tabs.session == unsafe { nil } {
			return false
		}
		return app.tabs.session.is_hibernated(index)
	}
	if app.tabs == unsafe { nil } {
		return false
	}
	return app.browser_tab_identity(index) in app.tabs.hibernated
}

fn (app &BrowserApp) browser_tab_hibernated_states() []bool {
	count := app.browser_tab_count()
	mut states := []bool{len: count}
	for index in 0 .. count {
		states[index] = app.is_browser_tab_hibernated(index)
	}
	return states
}

fn (app &BrowserApp) hibernated_browser_tab_title(index int) string {
	if app.process_tabs() || app.tabs == unsafe { nil } {
		return ''
	}
	key := app.browser_tab_identity(index)
	if record := app.tabs.hibernated[key] {
		return record.title
	}
	return ''
}

fn (mut app BrowserApp) note_browser_tab_activity(index int) {
	if app.process_tabs() || app.tabs == unsafe { nil } {
		return
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	app.tabs.tab_activity[app.browser_tab_identity(index)] = i64(time.sys_mono_now())
}

// hibernate_browser_tab discards a background tab's live document, scripts
// and caches while keeping a restorable snapshot. It refuses the selected
// tab, tabs that are already hibernated, and tabs with navigation work in
// flight, so hibernation never loses an in-progress page.
fn (mut app BrowserApp) hibernate_browser_tab(index int) bool {
	if app.process_tabs() {
		if app.tabs.session == unsafe { nil } {
			return false
		}
		app.tabs.session.hibernate(index) or { return false }
		request_browser_frame()
		return true
	}
	if app.tabs == unsafe { nil } {
		return false
	}
	if index < 0 || index >= app.tabs.pages.len {
		return false
	}
	if index == app.tabs.selected {
		return false
	}
	mut tab := app.tabs.pages[index]
	if app.browser_tab_identity(index) in app.tabs.hibernated {
		return false
	}
	if tab.navigation_work_depth > 0 || tab.has_navigation_fetch_in_flight() {
		return false
	}
	if tab.pending_navigation != none {
		return false
	}
	if tab.pending_page_preload != none || tab.navigation_results.len > 0 {
		return false
	}
	if tab.document == unsafe { nil } {
		return false
	}
	if tab.browser_document_loading() {
		return false
	}
	snapshot := tab.detached_tab_session()
	title := tab.browser_tab_title()
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	key := app.browser_tab_identity(index)
	app.tabs.hibernated[key] = HibernatedTab{
		session:       snapshot
		title:         title.clone()
		hibernated_at: i64(time.sys_mono_now())
	}
	// Retire through the session owner like tab closure does, then publish a
	// fresh empty session so every nil-document guard keeps holding. History,
	// address and the snapshot above stay reachable for the wake restore.
	mut session := tab.document_session()
	session.retire()
	tab.DocumentSessionRef = new_document_session()
	tab.NavigationController.cancel_pending_navigation()
	tab.clear_back_forward_cache()
	tab.resource_cache = map[string]PreloadedResource{}
	tab.deferred_navigation_input = none
	tab.deferred_page_input = []DeferredPageInput{}
	tab.replaying_deferred_page_input = false
	tab.frame_aligned_wheel = none
	tab.dispatching_frame_aligned_wheel = false
	tab.pointer_clicks = BrowserPointerClicks{}
	tab.stop_browser_tab_loading_animation()
	request_browser_frame()
	return true
}

// wake_browser_tab restores a hibernated tab's page from its snapshot. Live
// tabs report false without changing anything.
fn (mut app BrowserApp) wake_browser_tab(index int) bool {
	if app.process_tabs() {
		if app.tabs.session == unsafe { nil } {
			return false
		}
		if !app.tabs.session.is_hibernated(index) {
			return false
		}
		// The process still owns its document; waking only clears the mark.
		// Selecting the tab publishes the switch to the group.
		app.tabs.session.wake(index) or { return false }
		request_browser_frame()
		return true
	}
	if app.tabs == unsafe { nil } {
		return false
	}
	if index < 0 || index >= app.tabs.pages.len {
		return false
	}
	key := app.browser_tab_identity(index)
	record := app.tabs.hibernated[key] or { return false }
	mut tab := app.tabs.pages[index]
	tab.restore_detached_tab(record.session)
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	app.tabs.hibernated.delete(key)
	app.tabs.tab_activity[key] = i64(time.sys_mono_now())
	request_browser_frame()
	return true
}

// auto_hibernate_browser_tabs_at hibernates every background tab whose last
// recorded activity is older than the hibernation timeout. Tabs without
// recorded activity are left alone, so freshly created tabs never hibernate
// before their first selection.
fn (mut app BrowserApp) auto_hibernate_browser_tabs_at(now_ns i64) {
	if app.process_tabs() || app.tabs == unsafe { nil } {
		return
	}
	if app.browser_tabs_busy() || platform.arena_entered() {
		return
	}
	for index in 0 .. app.tabs.pages.len {
		if index == app.tabs.selected {
			continue
		}
		if app.is_browser_tab_hibernated(index) {
			continue
		}
		last := app.tabs.tab_activity[app.browser_tab_identity(index)] or { continue }
		if now_ns - last < tab_hibernation_timeout_ns {
			continue
		}
		app.hibernate_browser_tab(index)
	}
}

fn (mut app BrowserApp) auto_hibernate_browser_tabs() {
	app.auto_hibernate_browser_tabs_at(i64(time.sys_mono_now()))
}

fn (app &BrowserApp) browser_tab_hibernate_action(index int) string {
	if app.process_tabs() {
		if app.tabs.session == unsafe { nil } {
			return ''
		}
		if index < 0 || index >= app.tabs.session.state.tabs.len {
			return ''
		}
		if index == app.tabs.session.selected_index() {
			return ''
		}
		return if app.tabs.session.is_hibernated(index) { 'tab-wake:${index}' } else { 'tab-hibernate:${index}' }
	}
	if app.tabs == unsafe { nil } {
		return ''
	}
	if index < 0 || index >= app.tabs.pages.len || index == app.tabs.selected {
		return ''
	}
	return if app.is_browser_tab_hibernated(index) { 'tab-wake:${index}' } else { 'tab-hibernate:${index}' }
}

fn (mut app BrowserApp) drop_browser_tab_hibernation(index int) {
	if app.process_tabs() || app.tabs == unsafe { nil } {
		return
	}
	key := app.browser_tab_identity(index)
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	app.tabs.hibernated.delete(key)
	app.tabs.tab_activity.delete(key)
}

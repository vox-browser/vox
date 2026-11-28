module main

import dom
import html

// Ladybird's force-dark setting uses the existing navigable paint policy.
// Keep the last applied profile value with the document so a cached owner
// can refresh before pageshow, without overwriting internals on every poll.
fn (mut session DocumentSession) apply_browser_force_dark(navigable &dom.Navigable, enabled bool) bool {
	if session.document == unsafe { nil } { return false }
	if previous := session.force_dark_setting {
		if previous == enabled { return false }
	}
	mut model := html.navigable_model_for_host(navigable) or { return false }
	model.set_force_dark_enabled(enabled)
	model.set_force_dark_thresholds(150, 205)
	session.force_dark_setting = enabled
	// The navigable may still point at the outgoing document during a cache
	// restore. Invalidate this owner's retained style as well as the live one.
	mut document := session.document
	document.bump_style_environment_version()
	document.set_needs_media_query_evaluation()
	document.set_needs_full_style_update(true)
	document.set_needs_repaint()
	session.paint_commands_pending = true
	return true
}

fn (mut app BrowserApp) refresh_browser_appearance(enabled bool) {
	if app.document == unsafe { nil } { return }
	navigable := app.document.navigable() or { return }
	mut session := app.document_session()
	if !session.apply_browser_force_dark(navigable, enabled) { return }
	$if macos {
		if app.snapshot_visible { C.native_hide_cached_snapshot() }
	}
	app.snapshot_visible = false
	app.snapshot_hold = false
	app.snapshot_hold_until = 0
	app.snapshot_cached = false
	request_browser_frame()
}

fn apply_browser_appearance_to_open_tabs(enabled bool) {
	if address_bar_owner.app == unsafe { nil } { return }
	mut app := address_bar_owner.app.active_browser_tab()
	if app.tabs == unsafe { nil } {
		app.refresh_browser_appearance(enabled)
		return
	}
	for tab in app.tabs.pages {
		mut owner := unsafe { &BrowserApp(tab) }
		owner.refresh_browser_appearance(enabled)
	}
}

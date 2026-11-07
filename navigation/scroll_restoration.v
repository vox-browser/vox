module main

import html

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#restore-scroll-position-data
// Back, forward and reload install an entry's document again. Its viewport
// returns to the offset the user left it at. Like Ladybird, which restores
// when the history step is applied and once more when the document completes,
// the offset is reapplied while the page loads and its content can first reach
// it; a user scroll ends the restoration.
struct HistoryScrollRestoration {
	target     f64
	generation int
	// The document shown when the traversal began. A reload keeps it visible
	// until the response arrives; restoration applies to its replacement.
	replaced voidptr
mut:
	document voidptr
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#save-persisted-state
// Records the displayed document's offset in its entry as navigation leaves it.
fn (mut app BrowserApp) save_history_scroll_position() {
	if app.document == unsafe { nil } || app.history_index < 0 || app.history_index >= app.history.len {
		app.history_scroll_restoration = none
		return
	}
	// A page left before its restored content arrived keeps the restored offset.
	position := app.history_scroll_restoration_target() or { app.scroll_y }
	app.history_scroll_restoration = none
	app.history[app.history_index] = HistoryEntry{
		...app.history[app.history_index]
		scroll_y: if app.document_scroll_restoration_is_manual() { ?f64(none) } else { ?f64(position) }
	}
}

// history.scrollRestoration = "manual" leaves the entry's scroll position to
// the page. Only page scripts can set it; their documents own an HTML Window.
fn (app &BrowserApp) document_scroll_restoration_is_manual() bool {
	if app.js_runtime == unsafe { nil } || app.document == unsafe { nil } { return false }
	window_pointer := app.document.get_window() or { return false }
	window := unsafe { &html.WindowModel(window_pointer) }
	history := window.history()
	if history == unsafe { nil } { return false }
	mode := history.scroll_restoration() or { return false }
	return mode == .manual
}

// Starts restoring the current entry's saved offset on the document that
// replaces `replaced`. A traversal passes the document it is about to replace.
fn (mut app BrowserApp) start_history_scroll_restoration(replaced voidptr) {
	app.history_scroll_restoration = none
	if app.history_index < 0 || app.history_index >= app.history.len { return }
	target := app.history[app.history_index].scroll_y or { return }
	app.history_scroll_restoration = HistoryScrollRestoration{
		target:     target
		generation: app.navigation_generation
		replaced:   replaced
	}
	// A synchronous installation (fetch-free contexts) has already replaced it.
	if _ := app.history_scroll_restoration_target() {
		app.set_scroll_y(app.history_restored_scroll_y(), app.viewport_height + app.chrome_height())
	}
}

// The saved offset while it still applies to the displayed document.
fn (mut app BrowserApp) history_scroll_restoration_target() ?f64 {
	mut restoration := app.history_scroll_restoration or { return none }
	if restoration.generation != app.navigation_generation || app.document == unsafe { nil } {
		app.history_scroll_restoration = none
		return none
	}
	current := voidptr(app.document)
	if restoration.document == unsafe { nil } {
		if current == restoration.replaced { return none }
		restoration.document = current
		app.history_scroll_restoration = restoration
	} else if restoration.document != current {
		app.history_scroll_restoration = none
		return none
	}
	return restoration.target
}

// Relayout writes the shell's offset back to the document. While a restoration
// is in progress the saved offset replaces it, so content that grows while the
// page loads scrolls to that offset as soon as it can reach it.
fn (mut app BrowserApp) history_restored_scroll_y() f64 {
	if app.history_scroll_restoration == none { return app.scroll_y }
	return app.history_scroll_restoration_target() or { app.scroll_y }
}

// The user scrolled the restored document: their offset wins from now on. A
// reload still waiting for its response keeps the offset it was started with.
fn (mut app BrowserApp) cancel_history_scroll_restoration() {
	restoration := app.history_scroll_restoration or { return }
	if restoration.document == unsafe { nil } && restoration.generation == app.navigation_generation
		&& voidptr(app.document) == restoration.replaced {
		return
	}
	app.history_scroll_restoration = none
}

// Once the document has loaded, apply the offset a final time, as Ladybird
// does when the document completes, then leave scrolling to the page.
fn (mut app BrowserApp) finish_history_scroll_restoration(window_height int) {
	if app.history_scroll_restoration == none { return }
	target := app.history_scroll_restoration_target() or { return }
	if app.initial_layout_pending || app.browser_document_loading() { return }
	app.set_scroll_y(target, window_height)
	app.history_scroll_restoration = none
}

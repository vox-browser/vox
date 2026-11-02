module main

import browserbookmarks
import gg
import platform

const bookmark_bar_height = 28.0

fn browser_bookmark_shortcut(key gg.KeyCode, modifier gg.Modifier) string {
	if modifier.has(.alt) { return '' }
	$if macos {
		if !modifier.has(.super) || modifier.has(.ctrl) { return '' }
	} $else {
		if !modifier.has(.ctrl) || modifier.has(.super) { return '' }
	}
	if key == .b && modifier.has(.shift) { return 'bookmarks-toggle' }
	if key == .d && !modifier.has(.shift) { return 'bookmark-add' }
	return ''
}

fn (mut app BrowserApp) initialize_browser_bookmarks() {
	if app.bookmarks != unsafe { nil } { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	app.bookmarks = browserbookmarks.open(browserbookmarks.default_path()) or {
		app.bookmarks_error = 'Bookmarks could not be opened: ${err.msg()}'
		browserbookmarks.open('') or { panic(err) }
	}
	if app.restrict_to_optimized_sites {
		app.bookmarks.seed_optimized_sites() or { app.report_bookmarks_error(err.msg()) }
		app.bookmarks.seed_forum_news_sites() or { app.report_bookmarks_error(err.msg()) }
	}
}

fn (app &BrowserApp) bookmark_bar_visible() bool {
	return app.bookmarks != unsafe { nil } && (app.optimized_sites_only() || app.bookmarks.visible)
}

fn (app &BrowserApp) bookmark_bar_top() f64 {
	return tab_strip_height + browser_toolbar_height(app.chrome_debug)
}

fn (mut app BrowserApp) activate_browser_bookmarks(action string) {
	app.initialize_browser_bookmarks()
	if app.optimized_sites_only() && !action.starts_with('bookmark-open:') && action !in ['bookmarks-more', 'bookmarks-dismiss'] { return }
	match action {
		'bookmarks-more' { app.bookmark_overflow_open = !app.bookmark_overflow_open }
		'bookmarks-dismiss' { app.bookmark_overflow_open = false }
		'bookmarks-toggle' {
			app.bookmark_overflow_open = false
			app.bookmarks.toggle_visible() or {
				app.report_bookmarks_error(err.msg())
				return
			}
		}
		'bookmark-add' {
			// The address editor may contain an unsubmitted URL. Bookmark the
			// committed document, including its title and current fragment.
			if app.document == unsafe { nil } { return }
			app.bookmarks.add(app.document.url_string(), app.document.title()) or {
				app.report_bookmarks_error(err.msg())
				return
			}
		}
		else {
			if action.starts_with('bookmark-open:') {
				index := action.all_after(':').int()
				items := app.browser_bar_bookmarks()
				if index < 0 || index >= items.len { return }
				app.bookmark_overflow_open = false
				app.blur_address_bar()
				app.navigate(items[index].url, true)
				return
			}
			if !action.starts_with('bookmark-remove:') { return }
			app.bookmarks.remove(action.all_after(':').int()) or {
				app.report_bookmarks_error(err.msg())
				return
			}
		}
	}
	// Window snapshots include the bar and the resulting document viewport.
	$if macos {
		if app.snapshot_visible { C.native_hide_cached_snapshot() }
	}
	app.snapshot_visible = false
	app.snapshot_hold = false
	app.snapshot_hold_until = 0
	app.snapshot_cached = false
	app.update_browser_chrome(app.browser_chrome.width, app.browser_chrome.height)
	request_browser_frame()
}

fn (mut app BrowserApp) report_bookmarks_error(message string) {
	persistent := platform.enter_persistent()
	app.bookmarks_error = 'Bookmarks could not be saved: ${message}'
	platform.leave_persistent(persistent)
	app.update_browser_chrome(app.browser_chrome.width, app.browser_chrome.height)
	request_browser_frame()
}

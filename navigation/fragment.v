module main

import dom
import url

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate-fragid
// A URL that differs from the active document's only in its fragment scrolls
// that document instead of fetching and installing it again.
fn (mut app BrowserApp) navigate_to_a_fragment(resolved string) bool {
	if app.document == unsafe { nil } { return false }
	old_url := app.document.url.serialize()
	if !is_same_document_url(old_url, resolved) || url_fragment(resolved) == '' { return false }
	if app.history_index >= 0 && app.history_index < app.history.len {
		current := app.history[app.history_index]
		// "auto" history handling replaces the entry when the URL is unchanged.
		if resolved == old_url {
			app.history[app.history_index] = HistoryEntry{
				...current
				scroll_y: none
			}
		} else {
			app.history[app.history_index] = HistoryEntry{
				...current
				scroll_y: app.scroll_y
			}
			if app.history_index + 1 < app.history.len {
				app.history = app.history[..app.history_index + 1].clone()
			}
			app.history << HistoryEntry{
				...current
				url: resolved
				scroll_y: none
			}
			app.history_index = app.history.len - 1
		}
	}
	app.apply_fragment_navigation(old_url, resolved, none)
	return true
}

// Back/forward between entries of the same document only changes its URL and
// restores the scroll position the user left (scroll restoration "auto").
fn (mut app BrowserApp) traverse_to_a_fragment(from_index int, to_index int) bool {
	if app.document == unsafe { nil } || from_index < 0 || from_index >= app.history.len
		|| to_index < 0 || to_index >= app.history.len {
		return false
	}
	from := app.history[from_index]
	to := app.history[to_index]
	if from.markup != to.markup || from.content_type != to.content_type { return false }
	old_url := app.document.url.serialize()
	if old_url != from.url || !is_same_document_url(old_url, to.url) { return false }
	app.history[from_index] = HistoryEntry{
		...from
		scroll_y: app.scroll_y
	}
	app.apply_fragment_navigation(old_url, to.url, to.scroll_y)
	return true
}

fn is_same_document_url(old_url string, new_url string) bool {
	current := url.parse(old_url) or { return false }
	destination := url.parse(new_url) or { return false }
	return destination.scheme in ['http', 'https', 'file'] && destination.equals(&current, true)
}

// A missing fragment differs from an empty one: "page" to "page#" fires hashchange.
fn url_fragment(address string) string {
	parsed := url.parse(address) or { return '' }
	fragment := parsed.fragment or { return '' }
	return '#' + fragment
}

fn (mut app BrowserApp) apply_fragment_navigation(old_url string, new_url string, restored_scroll ?f64) {
	mut document := unsafe { &dom.Document(app.document) }
	destination := dom.dom_url_parse(new_url, dom.url_about_blank(), 'UTF-8') or { return }
	document.set_url(destination)
	app.address = new_url
	app.address_cursor = app.address.runes().len
	app.address_select = false
	app.sync_address_bar()
	if app.js_runtime != unsafe { nil } {
		app.js_runtime.evaluate_host('typeof __ladybirdHistoryURLChanged==="function"&&__ladybirdHistoryURLChanged()') or {}
	}
	// Sets the :target element and scrolls it (or the top of the document) into view.
	document.scroll_to_the_fragment()
	if scroll := restored_scroll {
		app.set_scroll_y(scroll, app.viewport_height + app.chrome_height())
	} else {
		app.adopt_document_viewport_scroll()
	}
	if url_fragment(old_url) != url_fragment(new_url) {
		if window := document.get_window() {
			mut event := dom.HashChangeEvent.create('hashchange', dom.HashChangeEventInit{
				old_url: old_url
				new_url: new_url
			})
			mut base := unsafe { &dom.Event(event) }
			base.set_is_trusted(true)
			dom.event_target_dispatch_event(&window.EventTarget, base)
		}
	}
	if app.js_runtime != unsafe { nil } {
		app.js_runtime.mark_document_state_dirty()
		app.poll_javascript_tasks()
	}
	document.set_needs_repaint()
	request_browser_frame()
}

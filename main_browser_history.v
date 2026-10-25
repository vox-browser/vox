module main

import browserhistory
import css
import dom
import gg
import html
import platform
import time
import url

const browser_history_url = 'vox://history'

// Titles and URLs also appear in quoted attributes on this privileged page.
fn browser_history_escape(value string) string {
	return html_escape(value).replace('"', '&quot;').replace("'", '&#39;')
}

fn (app &BrowserApp) browser_history_document_storage() platform.RetainedArenaScope {
	mut storage := app.document.native_storage()
	if storage == unsafe { nil } { return platform.RetainedArenaScope{} }
	return storage.enter_nested()
}

@[heap]
struct BrowserHistoryPage {
mut:
	query         string
	selected      map[i64]bool
	menu          i64
	dialog        string
	range_seconds i64 = 3600
	limit         int = 150
	version       u64
	error         string
}

fn is_browser_history_url(address string) bool {
	return address.trim_right('/') in ['about:history', browser_history_url, 'chrome://history']
}

fn browser_history_shortcut(key gg.KeyCode, modifier gg.Modifier) bool {
	if modifier.has(.alt) { return false }
	$if macos {
		return modifier.has(.super) && !modifier.has(.ctrl)
			&& ((key == .y && !modifier.has(.shift)) || (key == .h && modifier.has(.shift)))
	} $else {
		return key == .h && modifier.has(.ctrl) && !modifier.has(.shift) && !modifier.has(.super)
	}
}

fn (mut app BrowserApp) initialize_browser_history() {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	app.browsing_history = browserhistory.open(browserhistory.default_path(), browserhistory.now()) or {
		// Keep a corrupt/unreadable profile intact. Report the problem in the UI.
		app.browsing_history_error = 'History could not be opened: ${err.msg()}'
		browserhistory.open('', browserhistory.now()) or { panic(err) }
	}
}

fn (mut app BrowserApp) open_browser_history() {
	app.initialize_browser_tabs()
	for index, tab in app.tabs.pages {
		if is_browser_history_url(tab.source_label) {
			app.activate_tab_chrome('tab-select:${index}')
			return
		}
	}
	app.activate_tab_chrome('tab-open:${browser_history_url}')
}

fn (mut app BrowserApp) record_browser_visit(loaded LoadedPage) {
	if app.browsing_history == unsafe { nil } || !browserhistory.eligible_url(loaded.url)
		|| loaded.status == 'Navigation error' {
		return
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	app.browsing_history.record_with_favicon(loaded.url, document_title(app.document),
		browser_document_favicon_url(app.document), browserhistory.now()) or {
		app.browsing_history_error = 'History could not be saved: ${err.msg()}'
	}
}

fn browser_document_favicon_url(document &dom.Document) string {
	// The last declared icon wins. Resolve against the live document base so
	// relative and CDN-hosted icons survive navigation and browser restarts.
	mut favicon := ''
	for link in css.query_selector_all(document.as_node(), 'link[rel][href]') {
		if 'icon' !in link_relations(link) { continue }
		href := link.get_attribute_value('href').trim_space()
		if href == '' { continue }
		address := document.encoding_parse_url(href) or { continue }
		if browser_new_tab_allows_favicon_url(address) { favicon = address.serialize() }
	}
	return favicon
}

fn browser_history_host(address string) string {
	parsed := url.parse(address) or { return address }
	if parsed.scheme == 'file' { return 'Local file' }
	host := parsed.host or { return address }
	return host.serialize().trim_string_left('www.')
}

fn browser_history_day(visited_at i64, now time.Time) string {
	visited := time.unix(visited_at).local()
	date := visited.custom_format('YYYY-MM-DD')
	label := visited.custom_format('dddd, MMMM D, YYYY')
	if date == now.custom_format('YYYY-MM-DD') { return 'Today - ${label}' }
	if date == now.add_days(-1).custom_format('YYYY-MM-DD') { return 'Yesterday - ${label}' }
	return label
}

fn (app &BrowserApp) browser_history_results() string {
	state := app.history_page
	if state == unsafe { nil } || app.browsing_history == unsafe { nil } { return '' }
	visits := app.browsing_history.search(state.query)
	if visits.len == 0 {
		return '<div class="empty"><div class="empty-icon">&#8630;</div><h2>${if state.query == '' {
			'Your history is empty'
		} else {
			'No search results'
		}}</h2><p>${if state.query == '' {
			'Pages you visit will appear here.'
		} else {
			'Try a different search.'
		}}</p></div>'
	}
	now := time.now()
	mut result := []string{}
	if state.query != '' {
		result << '<p class="result-count">${visits.len} results for &ldquo;${browser_history_escape(state.query)}&rdquo;</p>'
	}
	mut previous_day := ''
	for index, visit in visits {
		if index >= state.limit { break }
		day := browser_history_day(visit.visited_at, now)
		if day != previous_day {
			if previous_day != '' { result << '</section>' }
			result << '<section class="day-card"><h2>${day}</h2>'
			previous_day = day
		}
		host := browser_history_host(visit.url)
		initial := if host != '' { host.runes()[0].str().to_upper() } else { '' }
		title := if visit.title.trim_space() != '' { visit.title } else { visit.url }
		checked := if state.selected[visit.id] { ' checked' } else { '' }
		clock := time.unix(visit.visited_at).local().custom_format('h:mm A')
		result << '<div class="history-row${if checked != '' { ' selected' } else { '' }}"><input type="checkbox" data-history-action="select" data-visit="${visit.id}" aria-label="Select ${browser_history_escape(title)}"${checked}><span class="visit-time">${clock}</span><span class="site-icon" aria-hidden="true">${browser_history_escape(initial)}</span><a class="visit-title" href="${browser_history_escape(visit.url)}" title="${browser_history_escape(title)}">${browser_history_escape(title)}</a><span class="visit-host">${browser_history_escape(host)}</span><button class="more icon-button" data-history-action="menu" data-visit="${visit.id}" aria-label="More actions" aria-expanded="${state.menu == visit.id}">&#8942;</button>'
		if state.menu == visit.id {
			result << '<div class="row-menu"><button data-history-action="site" data-visit="${visit.id}">More from this site</button><button data-history-action="remove" data-visit="${visit.id}">Remove from history</button></div>'
		}
		result << '</div>'
	}
	result << '</section>'
	if visits.len > state.limit {
		result << '<button class="load-more" data-history-action="more">Show more</button>'
	}
	return result.join('')
}

fn (app &BrowserApp) browser_history_selection() string {
	count := app.history_page.selected.len
	if count == 0 { return '' }
	return '<button class="icon-button" data-history-action="unselect" aria-label="Cancel selection">&#10005;</button><span>${count} selected</span><button class="text-button" data-history-action="select-all">Select all</button><button class="primary" data-history-action="delete-selected">Delete</button>'
}

fn (app &BrowserApp) browser_history_dialog() string {
	state := app.history_page
	if state.dialog == '' { return '' }
	mut controls := ''
	if state.dialog == 'clear' {
		controls = '<p>Remove browsing history from this device.</p><p class="range-label">Time range</p><div class="ranges">'
		for seconds, label in {
			i64(3600):    'Last hour'
			i64(86400):   'Last 24 hours'
			i64(604800):  'Last 7 days'
			i64(2419200): 'Last 4 weeks'
			i64(0):       'All time'
		} {
			controls += '<button class="range${if seconds == state.range_seconds {
				' active'
			} else {
				''
			}}" data-history-action="range" data-seconds="${seconds}" aria-pressed="${seconds == state.range_seconds}">${label}</button>'
		}
		controls += '</div><p class="dialog-note">Cookies, saved passwords, and downloaded files are kept.</p>'
	} else {
		controls = '<p>Delete ${state.selected.len} selected items from your history?</p>'
	}
	return '<div class="dialog-backdrop"><div class="dialog" role="dialog" aria-modal="true" aria-labelledby="dialog-title"><h2 id="dialog-title">${if state.dialog == 'clear' {
		'Delete browsing data'
	} else {
		'Delete from history?'
	}}</h2>${controls}<div class="dialog-actions"><button class="text-button" data-history-action="cancel">Cancel</button><button id="history-confirm" class="primary" data-history-action="confirm">Delete</button></div></div></div>'
}

fn (mut app BrowserApp) browser_history_markup() string {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if app.browsing_history == unsafe { nil } {
		app.browsing_history = browserhistory.open('', browserhistory.now()) or { panic(err) }
	}
	app.history_page = &BrowserHistoryPage{ version: app.browsing_history.version, error: app.browsing_history_error }
	return '<!doctype html><html><head><meta charset="utf-8"><title>History</title><style>${browser_history_css}</style></head><body><header class="history-header"><div class="history-brand"><svg viewBox="0 0 24 24" width="24" height="24" aria-hidden="true"><path d="M3 11a9 9 0 1 1 2.6 7M3 4v7h7M12 7v5l3 2" fill="none" stroke="currentColor" stroke-width="2"/></svg><h1>History</h1></div><div class="search-box"><svg viewBox="0 0 24 24" width="24" height="24" aria-hidden="true"><circle cx="10" cy="10" r="6" fill="none" stroke="currentColor" stroke-width="2"/><path d="m15 15 5 5" stroke="currentColor" stroke-width="2"/></svg><input id="history-search" type="search" placeholder="Search history" aria-label="Search history"><button class="icon-button" data-history-action="clear-search" aria-label="Clear search">&#10005;</button></div><div id="history-selection" class="selection-bar"></div></header><aside class="sidebar"><button class="nav-item current" data-history-action="all-history"><span aria-hidden="true"><svg viewBox="0 0 24 24" width="20" height="20"><path d="M3 11a9 9 0 1 1 2.6 7M3 4v7h7M12 7v5l3 2" fill="none" stroke="currentColor" stroke-width="2"/></svg></span>History</button><div class="sidebar-divider"></div><button class="nav-item" data-history-action="clear"><span aria-hidden="true"><svg viewBox="0 0 24 24" width="20" height="20"><path d="M4 6h16M9 6V3h6v3M6 6l1 15h10l1-15M10 10v7M14 10v7" fill="none" stroke="currentColor" stroke-width="2"/></svg></span>Delete browsing data</button></aside><main><div id="history-error" role="alert">${browser_history_escape(app.history_page.error)}</div><div id="history-results">${app.browser_history_results()}</div></main><div id="history-dialog"></div></body></html>'
}

fn (app &BrowserApp) is_browser_history_document() bool {
	return app.source_label == browser_history_url && app.document != unsafe { nil }
		&& app.document.url_string() == browser_history_url && app.history_page != unsafe { nil }
}

fn (mut app BrowserApp) install_browser_history_listeners() {
	if !app.is_browser_history_document() { return }
	mut allocations := app.browser_history_document_storage()
	defer { allocations.finish() }
	owner := voidptr(app)
	document := app.document
	for event_name in ['click', 'input', 'change'] {
		listener := dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [owner, document] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				mut app := unsafe { &BrowserApp(owner) }
				if voidptr(app.document) != voidptr(document) || !app.is_browser_history_document() {
					return dom.js_undefined()
				}
				app.handle_browser_history_event(event)
				return dom.js_undefined()
			}
		})
		unsafe { &dom.EventTarget(document) }.add_event_listener_without_options(event_name, listener)
	}
	app.blur_address_bar()
	if input := document.get_element_by_id('history-search') {
		dom.run_focusing_steps_for_node(input.as_node(), none, .other)
	}
}

fn (mut app BrowserApp) handle_browser_history_event(event &dom.Event) {
	if !app.is_browser_history_document() { return }
	target := event.target() or { return }
	if target.data.kind != .node { return }
	mut element := unsafe { &dom.Node(target) }.as_element() or { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut state := app.history_page
	if event.type_name() == 'input' && element.get_attribute_value('id') == 'history-search' {
		model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		state.query = model.value().clone()
		state.selected.clear()
		state.menu = 0
		state.limit = 150
		app.refresh_browser_history_page()
		return
	}
	for element.get_attribute_value('data-history-action') == '' {
		element = element.as_node().parent_element() or {
			if event.type_name() == 'click' && state.menu != 0 {
				state.menu = 0
				app.refresh_browser_history_page()
			}
			return
		}
	}
	action := element.get_attribute_value('data-history-action')
	id := element.get_attribute_value('data-visit').i64()
	if action == 'select' {
		if event.type_name() != 'change' { return }
		model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		if model.checked() { state.selected[id] = true } else { state.selected.delete(id) }
	} else {
		if event.type_name() != 'click' { return }
		if state.dialog != '' && action !in ['range', 'cancel', 'confirm'] { return }
		match action {
			'menu' { state.menu = if state.menu == id { 0 } else { id } }
			'unselect' { state.selected.clear() }
			'select-all' {
				for visit in app.browsing_history.search(state.query) {
					state.selected[visit.id] = true
				}
			}
			'delete-selected' {
				if state.selected.len > 0 { state.dialog = 'selection' }
			}
			'clear' { state.dialog = 'clear' }
			'cancel' { state.dialog = '' }
			'range' { state.range_seconds = element.get_attribute_value('data-seconds').i64() }
			'confirm' {
				if state.dialog == 'clear' {
					cutoff := if state.range_seconds == 0 {
						i64(0)
					} else {
						browserhistory.now() - state.range_seconds
					}
					app.browsing_history.clear_since(cutoff) or { state.error = 'Could not delete history: ${err.msg()}' }
				} else if state.dialog == 'selection' {
					app.browsing_history.remove(state.selected.keys()) or { state.error = 'Could not delete history: ${err.msg()}' }
				}
				state.dialog = ''
				state.selected.clear()
			}
			'remove' {
				app.browsing_history.remove([id]) or { state.error = 'Could not delete history: ${err.msg()}' }
				state.selected.delete(id)
				state.menu = 0
			}
			'more' { state.limit += 150 }
			'clear-search', 'all-history', 'site' {
				state.query = ''
				if action == 'site' {
					for visit in app.browsing_history.visits {
						if visit.id == id { state.query = browser_history_host(visit.url).clone() }
					}
				}
				state.selected.clear()
				state.menu = 0
				if input := app.document.get_element_by_id('history-search') {
					mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(input) })
					model.set_value(state.query) or {}
				}
			}
			else { return }
		}
	}
	app.refresh_browser_history_page()
}

fn (mut app BrowserApp) refresh_browser_history_page() {
	if !app.is_browser_history_document() { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	// Preserve keyboard position when replacing rows or dialog controls.
	focused := app.document.focused_area() or { unsafe { nil } }
	mut focus_selector := ''
	if focused != unsafe { nil } {
		if element := focused.as_element() {
			action := element.get_attribute_value('data-history-action')
			if action != '' {
				focus_selector = '[data-history-action="${action}"]'
				for attribute in ['data-visit', 'data-seconds'] {
					value := element.get_attribute_value(attribute)
					if value != '' { focus_selector += '[${attribute}="${value}"]' }
				}
			}
		}
	}
	if app.history_page.selected.len > 0 {
		mut retained := map[i64]bool{}
		for visit in app.browsing_history.visits {
			if app.history_page.selected[visit.id] { retained[visit.id] = true }
		}
		app.history_page.selected = retained
	}
	mut allocations := app.browser_history_document_storage()
	defer { allocations.finish() }
	for id, markup in {
		'history-results':   app.browser_history_results()
		'history-selection': app.browser_history_selection()
		'history-dialog':    app.browser_history_dialog()
		'history-error':     browser_history_escape(app.history_page.error)
	} {
		if mut element := app.document.get_element_by_id(id) {
			element.set_inner_html(markup) or {}
		}
	}
	app.history_page.version = app.browsing_history.version
	if app.history_page.dialog != '' && !focus_selector.starts_with('[data-history-action="range"]') {
		focus_selector = '#history-confirm'
	}
	if focus_selector != '' {
		if element := css.query_selector(app.document.as_node(), focus_selector) {
			dom.run_focusing_steps_for_node(element.as_node(), none, .other)
		} else if input := app.document.get_element_by_id('history-search') {
			dom.run_focusing_steps_for_node(input.as_node(), none, .other)
		}
	}
	request_browser_frame()
}

fn (mut app BrowserApp) handle_browser_history_key(key gg.KeyCode, modifier gg.Modifier) bool {
	if !app.is_browser_history_document() || app.address_active { return false }
	if key == .escape {
		if app.history_page.dialog == '' && app.history_page.menu == 0 {
			app.history_page.selected.clear()
		}
		app.history_page.dialog = ''
		app.history_page.menu = 0
		app.refresh_browser_history_page()
		return true
	}
	if app.history_page.dialog != '' && key == .tab {
		buttons := css.query_selector_all(app.document.as_node(), '#history-dialog button')
		if buttons.len == 0 { return true }
		focused := app.document.focused_area() or { unsafe { nil } }
		mut next := if modifier.has(.shift) { buttons.len - 1 } else { 0 }
		for index, button in buttons {
			if voidptr(button.as_node()) == voidptr(focused) {
				next = (index + buttons.len + if modifier.has(.shift) { -1 } else { 1 }) % buttons.len
				break
			}
		}
		dom.run_focusing_steps_for_node(buttons[next].as_node(), none, .other)
		return true
	}
	return false
}

fn (mut app BrowserApp) poll_browser_history_page() {
	if app.is_browser_history_document() && app.browsing_history.version != app.history_page.version {
		app.refresh_browser_history_page()
	}
}

const browser_history_css = browserhistory.stylesheet

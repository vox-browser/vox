module main

import browserhistory
import css
import dom
import gg
import html
import page

$if vox_ui2 ? {
	import ui2
	#include "@VMODROOT/native/include/native_address_bar_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_address_shortcut(field voidptr, owner voidptr, callback fn (voidptr, int), key u16, shift int) int
	fn C.native_test_chrome_click(control voidptr)

	fn test_history_native_toolbar_and_address_editor_shortcuts() {
		window := C.native_test_address_window()
		mut app := history_test_app()
		mut owner := unsafe { address_bar_owner }
		owner.app = app
		defer {
			app.unmount_address_bar()
			history_test_close(mut app)
			C.native_test_address_close(window)
		}
		field := app.mount_ui2_chrome(C.native_test_address_parent(window), 1000, 784) or { panic(err) }
		app.focus_address_bar()
		assert C.native_test_address_shortcut(field, app, address_bar_shortcut, 16, 0) == 1
		assert app.active_browser_tab().is_browser_history_document()
		assert app.tabs.pages.len == 2
		app.activate_tab_chrome('tab-select:0')
		app.focus_address_bar()
		assert C.native_test_address_shortcut(field, app, address_bar_shortcut, 4, 1) == 1
		assert app.active_browser_tab().is_browser_history_document()
		assert app.tabs.pages.len == 2
		app.activate_tab_chrome('tab-select:0')
		C.native_test_chrome_click(ui2.embedded_browser_control('history'))
		assert app.active_browser_tab().is_browser_history_document()
		assert app.tabs.pages.len == 2
	}
}

fn history_test_app() &BrowserApp {
	mut app := &BrowserApp{
		page_model:                  page.Page.create(1) or { panic(err) }
		browsing_history:            browserhistory.open('', browserhistory.now()) or { panic(err) }
		viewport_width:              1000
		viewport_height:             700
		navigation_results:          chan NavigationResult{cap: 4}
		background_resource_results: chan PreloadedResource{cap: max_cached_resources}
	}
	app.install_chrome_widget_input_bridge()
	app.initialize_browser_tabs()
	return app
}

fn history_test_close(mut app BrowserApp) {
	for mut tab in app.tabs.pages { tab.dispose_browser_tab() }
}

fn history_test_load(mut app BrowserApp, address string, title string) {
	app.install_loaded_page(LoadedPage{
		url:          address
		markup:       '<!doctype html><title>${html_escape(title)}</title><p>Content</p>'
		content_type: 'text/html'
	}, true)
}

fn history_test_event(mut app BrowserApp, selector string, name string) {
	element := css.query_selector(app.document.as_node(), selector) or { panic(selector) }
	dom.event_target_dispatch_event(unsafe { &dom.EventTarget(element) }, dom.Event.create(name, dom.EventInit{ bubbles: true }))
}

fn history_test_search(mut app BrowserApp, query string) {
	input := app.document.get_element_by_id('history-search') or { panic('search') }
	mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(input) })
	model.set_value(query) or { panic(err) }
	dom.run_focusing_steps_for_node(input.as_node(), none, .key)
	history_test_event(mut app, '#history-search', 'input')
	assert voidptr(app.document.focused_area() or { panic('lost search focus') }) == voidptr(input.as_node())
}

fn test_history_records_committed_pages_shares_tabs_and_reuses_history_tab() {
	mut app := history_test_app()
	defer { history_test_close(mut app) }
	history_test_load(mut app, 'https://example.com/first', 'First page')
	history_test_load(mut app, 'https://example.com/second', 'Second page')
	assert app.browsing_history.visits.len == 2
	app.open_browser_history()
	mut history := app.active_browser_tab()
	assert app.tabs.pages.len == 2
	assert voidptr(history.browsing_history) == voidptr(app.browsing_history)
	assert history.is_browser_history_document()
	assert history.document.title() == 'History'
	assert app.browsing_history.visits.len == 2
	links := css.query_selector_all(history.document.as_node(), '.visit-title')
	assert links.len == 2
	assert links[0].get_attribute_value('href') == 'https://example.com/second'
	app.activate_tab_chrome('tab-select:0')
	app.open_browser_history()
	assert app.tabs.pages.len == 2
	assert voidptr(app.active_browser_tab()) == voidptr(history)
	app.activate_tab_chrome('tab-select:0')
	history_test_load(mut app, 'https://example.com/third', 'Third page')
	history.poll_browser_history_page()
	assert css.query_selector_all(history.document.as_node(), '.history-row').len == 3
	// Back to an internal page regenerates its data instead of replaying stale markup.
	history_test_load(mut history, 'https://example.com/fourth', 'Fourth page')
	history.history_go(-1)
	assert history.is_browser_history_document()
	assert css.query_selector_all(history.document.as_node(), '.history-row').len == 4
}

fn test_history_live_search_bulk_delete_cancel_and_individual_removal() {
	mut app := history_test_app()
	defer { history_test_close(mut app) }
	title := '<Documentation> & " data-history-action="clear'
	history_test_load(mut app, 'https://docs.example/a', title)
	history_test_load(mut app, 'https://news.example/', 'News')
	history_test_load(mut app, 'https://docs.example/b', 'Second documentation')
	app.navigate('chrome://history/', true)
	assert app.address == browser_history_url
	history_test_search(mut app, 'DOCUMENTATION docs')
	assert css.query_selector_all(app.document.as_node(), '.history-row').len == 2
	assert app.document.get_element_by_id('history-search')?.get_attribute_value('placeholder') == 'Search history'
	assert css.query_selector(app.document.as_node(), '.visit-title')?.text_content()? == 'Second documentation'
	links := css.query_selector_all(app.document.as_node(), '.visit-title')
	assert links[1].text_content()? == title
	assert links[1].get_attribute_value('title') == title
	assert links[1].get_attribute_value('data-history-action') == ''
	checkbox := css.query_selector(app.document.as_node(), '[data-history-action="select"]')?
	mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(checkbox) })
	model.set_checked(true)
	history_test_event(mut app, '[data-history-action="select"]', 'change')
	assert app.history_page.selected.len == 1
	history_test_event(mut app, '[data-history-action="select-all"]', 'click')
	assert app.history_page.selected.len == 2
	history_test_event(mut app, '[data-history-action="delete-selected"]', 'click')
	assert app.history_page.dialog == 'selection'
	assert app.handle_browser_history_key(.tab, .shift)
	assert app.handle_browser_history_key(.escape, unsafe { gg.Modifier(0) })
	assert app.browsing_history.visits.len == 3
	history_test_event(mut app, '[data-history-action="delete-selected"]', 'click')
	history_test_event(mut app, '#history-confirm', 'click')
	assert app.browsing_history.visits.len == 1
	assert css.query_selector_all(app.document.as_node(), '.history-row').len == 0
	history_test_event(mut app, '[data-history-action="clear-search"]', 'click')
	assert app.history_page.query == ''
	history_test_event(mut app, '[data-history-action="menu"]', 'click')
	history_test_event(mut app, '[data-history-action="remove"]', 'click')
	assert app.browsing_history.visits.len == 0
	assert css.query_selector(app.document.as_node(), '.empty') != none
}

fn test_history_clear_range_security_and_aliases() {
	mut app := history_test_app()
	defer { history_test_close(mut app) }
	now := browserhistory.now()
	app.browsing_history.record('https://older.example/', 'Older', now - 90000)!
	app.browsing_history.record('https://recent.example/', 'Recent', now)!
	app.navigate('about:history', true)
	assert app.is_browser_history_document()
	history_test_event(mut app, '[data-history-action="clear"]', 'click')
	history_test_event(mut app, '[data-seconds="86400"]', 'click')
	history_test_event(mut app, '#history-confirm', 'click')
	assert app.browsing_history.visits.len == 1
	assert app.browsing_history.visits[0].title == 'Older'
	history_test_event(mut app, '[data-history-action="clear"]', 'click')
	history_test_event(mut app, '[data-seconds="0"]', 'click')
	history_test_event(mut app, '[data-history-action="cancel"]', 'click')
	assert app.browsing_history.visits.len == 1
	history_test_event(mut app, '[data-history-action="clear"]', 'click')
	history_test_event(mut app, '[data-seconds="0"]', 'click')
	history_test_event(mut app, '#history-confirm', 'click')
	assert app.browsing_history.visits.len == 0
	app.install_loaded_page(LoadedPage{
		url:          'https://malicious.example/'
		markup:       '<button data-history-action="clear">Clear</button><button id="history-confirm" data-history-action="confirm">Delete</button>'
		content_type: 'text/html'
	}, true)
	app.install_browser_history_listeners()
	history_test_event(mut app, '[data-history-action="clear"]', 'click')
	history_test_event(mut app, '#history-confirm', 'click')
	assert app.browsing_history.visits.len == 1
	assert resolve_url('chrome://history', 'https://example.com/') == browser_history_url
	assert !is_browser_history_url('https://history/')
	$if macos {
		assert browser_history_shortcut(.y, .super)
		assert browser_history_shortcut(.h, .super | .shift)
		assert !browser_history_shortcut(.h, .super)
	} $else {
		assert browser_history_shortcut(.h, .ctrl)
	}
	assert !browser_history_shortcut(.h, .alt | .ctrl)
}

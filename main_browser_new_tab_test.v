module main

import browserhistory
import css
import dom
import page

$if macos {
	#include "native_address_bar_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_close(voidptr)
}

fn new_tab_test_app() &BrowserApp {
	mut app := &BrowserApp{
		page_model: page.Page.create(1) or { panic(err) }
		browsing_history: browserhistory.open('', browserhistory.now()) or { panic(err) }
		viewport_width: 800
		viewport_height: 600
		navigation_results: chan NavigationResult{cap: 4}
		background_resource_results: chan PreloadedResource{cap: max_cached_resources}
	}
	app.install_chrome_widget_input_bridge()
	app.initialize_browser_tabs()
	return app
}

fn new_tab_test_close(mut app BrowserApp) {
	for mut tab in app.tabs.pages { tab.dispose_browser_tab() }
}

fn test_new_tab_renders_centered_history_shortcuts_and_keeps_address_focus() {
	mut window := voidptr(0)
	$if macos { window = C.native_test_address_window() }
	defer {
		$if macos { C.native_test_address_close(window) }
	}
	mut app := new_tab_test_app()
	defer { new_tab_test_close(mut app) }
	now := browserhistory.now()
	app.browsing_history.record('https://docs.example/start', 'Docs', now - 200)!
	app.browsing_history.record('https://news.example/', 'News', now - 100)!
	app.browsing_history.record('https://docs.example/guide', 'Documentation', now)!
	app.activate_tab_chrome('tab-new')
	mut tab := app.active_browser_tab()
	assert tab.browser_tab_title() == 'New Tab'
	assert tab.address == ''
	assert tab.address_active
	assert tab.history.len == 1
	assert tab.history[0].url == browser_new_tab_url
	assert app.browsing_history.visits.len == 3
	tab.address = 'unfinished search'
	tab.cancel_address_bar()
	assert tab.address == ''
	tab.focus_address_bar()
	links := css.query_selector_all(tab.document.as_node(), '.site-tile')
	assert links.len == 2
	assert links[0].get_attribute_value('href') == 'https://docs.example/guide'
	assert links[0].text_content()?.contains('Documentation')
	first := links[0].get_bounding_client_rect()
	second := links[1].get_bounding_client_rect()
	assert first.width == 112
	assert first.x + first.width <= second.x
	assert first.x + (second.x + second.width - first.x) / 2 == 400
	assert first.y > 200 && first.y + first.height < 600
	x := f32(first.x + first.width / 2)
	y := f32(first.y + first.height / 2) + tab.page_top()
	assert tab.link_at_point(x, y)? == 'https://docs.example/guide'
	tab.blur_address_bar()
	dom.run_focusing_steps_for_node(links[0].as_node(), none, .key)
	assert voidptr(tab.document.focused_area()?) == voidptr(links[0].as_node())
}

fn test_new_tab_refreshes_shared_history_and_regenerates_after_reload_and_back() {
	mut app := new_tab_test_app()
	defer { new_tab_test_close(mut app) }
	app.navigate('about:newtab', true)
	assert css.query_selector(app.document.as_node(), '.empty') != none
	app.browsing_history.record('https://example.com/', '', browserhistory.now())!
	app.poll_browser_new_tab_page()
	assert css.query_selector_all(app.document.as_node(), '.site-tile').len == 1
	assert css.query_selector(app.document.as_node(), '.site-title')?.text_content()? == 'example.com'
	app.reload()
	assert app.address == ''
	assert app.history.len == 1
	app.install_loaded_page(LoadedPage{
		url: 'https://second.example/'
		markup: '<!doctype html><title>Second</title>'
		content_type: 'text/html'
	}, true)
	app.history_go(-1)
	assert app.source_label == browser_new_tab_url
	assert app.address == ''
	assert css.query_selector_all(app.document.as_node(), '.site-tile').len == 2
	app.browsing_history.clear_since(0)!
	app.poll_browser_new_tab_page()
	assert css.query_selector_all(app.document.as_node(), '.site-tile').len == 0
	assert css.query_selector(app.document.as_node(), '.empty') != none
}

fn test_new_tab_escapes_history_labels_and_wraps_shortcuts_on_narrow_viewports() {
	mut app := new_tab_test_app()
	defer { new_tab_test_close(mut app) }
	title := '<img src=x onerror=alert(1)> & "Quoted"'
	address := 'https://example.com/?a=1&b=%22'
	app.browsing_history.record(address, title, browserhistory.now())!
	for index in 0 .. 9 {
		app.browsing_history.record('https://site${index}.example/', 'Site ${index}', browserhistory.now() - index - 1)!
	}
	app.navigate('chrome://newtab/', true)
	assert css.query_selector_all(app.document.as_node(), '.site-tile').len == 8
	assert css.query_selector_all(app.document.as_node(), 'img, script').len == 0
	link := css.query_selector(app.document.as_node(), '.site-tile')?
	assert link.get_attribute_value('href') == address
	assert link.get_attribute_value('title') == title
	assert css.query_selector(app.document.as_node(), '.site-title')?.text_content()? == title
	for width in [360, 800] {
		app.relayout(width, 600 + app.chrome_height())
		links := css.query_selector_all(app.document.as_node(), '.site-tile')
		for tile in links {
			rect := tile.get_bounding_client_rect()
			assert rect.x >= 0 && rect.x + rect.width <= width
		}
		assert links[0].get_bounding_client_rect().y < links[links.len - 1].get_bounding_client_rect().y
	}
}

fn test_initial_page_is_new_tab_and_explicit_blank_remains_empty() {
	address, markup, _ := initial_document('')
	assert address == browser_new_tab_url
	assert markup.contains('New Tab')
	mut app := new_tab_test_app()
	defer { new_tab_test_close(mut app) }
	app.navigate('about:blank', true)
	assert app.document.url_string() == 'about:blank'
	assert css.query_selector(app.document.as_node(), '.sites') == none
	assert resolve_url('about:newtab', '') == browser_new_tab_url
	assert !is_browser_new_tab_url('https://newtab/')
}

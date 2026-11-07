module main

import browserjs
import dom
import os
import page
import time

const restoration_tall_markup = '<!doctype html><style>html,body{margin:0}#tall{height:4000px}</style><div id="tall"></div>'
const restoration_short_markup = '<!doctype html><style>html,body{margin:0}#tall{height:100px}</style><div id="tall"></div>'

fn scroll_restoration_app() &BrowserApp {
	return &BrowserApp{
		page_model:      page.Page.create(1) or { panic(err) }
		viewport_width:  800
		viewport_height: 600
	}
}

fn install_restoration_page(mut app BrowserApp, name string, markup string) {
	app.install_loaded_page(LoadedPage{
		url:          'https://restore.example.test/${name}'
		markup:       markup
		content_type: 'text/html'
	}, true)
}

fn restoration_window_height(app &BrowserApp) int {
	return app.viewport_height + app.chrome_height()
}

// Going back reinstalled the page from its history entry at the top.
fn test_back_and_forward_restore_each_page_scroll_position() {
	mut app := scroll_restoration_app()
	defer { app.dispose_browser_tab() }
	height := restoration_window_height(app)
	install_restoration_page(mut app, 'first', restoration_tall_markup)
	app.scroll_by(1200, height)
	install_restoration_page(mut app, 'second', restoration_tall_markup)
	assert app.scroll_y == 0
	app.scroll_by(300, height)
	app.history_go(-1)
	assert app.document.url_string() == 'https://restore.example.test/first'
	assert app.scroll_y == 1200
	assert app.document.viewport_rect().y * app.page_zoom == 1200
	app.relayout(800, height)
	assert app.scroll_y == 1200
	app.history_go(1)
	assert app.document.url_string() == 'https://restore.example.test/second'
	assert app.scroll_y == 300
	// A new navigation starts at the top and still saves the page it leaves.
	install_restoration_page(mut app, 'third', restoration_tall_markup)
	assert app.scroll_y == 0
	app.history_go(-1)
	assert app.scroll_y == 300
}

// Content that a page builds after it is installed reaches the saved offset
// later. The restoration follows it until the user scrolls.
fn test_restoration_follows_content_that_grows_after_installation() {
	mut app := scroll_restoration_app()
	defer { app.dispose_browser_tab() }
	height := restoration_window_height(app)
	install_restoration_page(mut app, 'feed', restoration_tall_markup)
	app.scroll_by(2500, height)
	install_restoration_page(mut app, 'article', restoration_tall_markup)
	app.history[0] = HistoryEntry{
		...app.history[0]
		markup: restoration_short_markup
	}
	app.history_go(-1)
	assert app.scroll_y == 0
	mut tall := app.document.get_element_by_id('tall') or { panic('missing #tall') }
	tall.set_attribute_value('style', 'height:1500px')
	app.relayout(800, height)
	assert app.scroll_y == app.maximum_scroll(height)
	assert app.scroll_y > 0 && app.scroll_y < 2500
	tall.set_attribute_value('style', 'height:4000px')
	app.relayout(800, height)
	assert app.scroll_y == 2500
	// Leaving before the content arrives keeps the offset the user left.
	app.history_go(1)
	assert app.history[0].scroll_y or { -1.0 } == 2500
}

fn test_a_user_scroll_ends_the_restoration() {
	mut app := scroll_restoration_app()
	defer { app.dispose_browser_tab() }
	height := restoration_window_height(app)
	install_restoration_page(mut app, 'feed', restoration_tall_markup)
	app.scroll_by(2500, height)
	install_restoration_page(mut app, 'article', restoration_tall_markup)
	app.history[0] = HistoryEntry{
		...app.history[0]
		markup: restoration_short_markup
	}
	app.history_go(-1)
	assert app.history_scroll_restoration != none
	// A horizontal gesture (the swipe that went back) has no vertical delta.
	app.scroll_by(0, height)
	assert app.history_scroll_restoration != none
	app.scroll_by(40, height)
	assert app.history_scroll_restoration == none
	mut tall := app.document.get_element_by_id('tall') or { panic('missing #tall') }
	tall.set_attribute_value('style', 'height:4000px')
	app.relayout(800, height)
	assert app.scroll_y == 0
}

// Once the page has loaded, its own later growth no longer moves it.
fn test_restoration_ends_when_the_document_has_loaded() {
	mut app := scroll_restoration_app()
	defer { app.dispose_browser_tab() }
	height := restoration_window_height(app)
	install_restoration_page(mut app, 'feed', restoration_tall_markup)
	app.scroll_by(2500, height)
	install_restoration_page(mut app, 'article', restoration_tall_markup)
	app.history[0] = HistoryEntry{
		...app.history[0]
		markup: restoration_short_markup
	}
	app.history_go(-1)
	app.document.update_readiness(.complete)
	assert !app.browser_document_loading()
	app.finish_history_scroll_restoration(height)
	assert app.history_scroll_restoration == none
	mut tall := app.document.get_element_by_id('tall') or { panic('missing #tall') }
	tall.set_attribute_value('style', 'height:4000px')
	app.relayout(800, height)
	assert app.scroll_y == 0
}

fn test_reload_restores_the_scroll_position() {
	path := os.join_path(os.temp_dir(), 'vox-scroll-restoration-${os.getpid()}.html')
	os.write_file(path, restoration_tall_markup)!
	defer { os.rm(path) or {} }
	mut app := scroll_restoration_app()
	defer { app.dispose_browser_tab() }
	height := restoration_window_height(app)
	app.navigate('file://' + path, true)
	first := voidptr(app.document)
	app.scroll_by(1700, height)
	app.reload()
	assert voidptr(app.document) != first
	assert app.history.len == 1
	assert app.scroll_y == 1700
}

// history.scrollRestoration = "manual" leaves the page to position itself.
fn test_manual_scroll_restoration_does_not_save_the_position() {
	page_url := 'https://restore.example.test/manual'
	mut owner := page.Page.create(1) or { panic(err) }
	mut document := parse_browser_navigation_document_for_page_with_response_time(restoration_tall_markup,
		dom.URL{ value: page_url }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, page_url, ['history.scrollRestoration="manual"'], runtime, mut
		messages)
	assert messages == []string{}
	mut app := &BrowserApp{ document: document, page_model: owner, js_runtime: runtime }
	app.history << HistoryEntry{ url: page_url, markup: restoration_tall_markup }
	app.history_index = 0
	app.relayout(320, 312)
	app.set_scroll_y(500, 312)
	app.save_history_scroll_position()
	assert app.history[0].scroll_y == none
	assert runtime.evaluate_host('history.scrollRestoration="auto";history.scrollRestoration')! == 'auto'
	app.save_history_scroll_position()
	assert app.history[0].scroll_y or { -1.0 } == 500
}

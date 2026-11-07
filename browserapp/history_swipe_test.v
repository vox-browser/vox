module main

import dom
import page

fn history_swipe_test_app() &BrowserApp {
	mut app := &BrowserApp{
		page_model:      page.Page.create(1) or { panic(err) }
		viewport_width:  800
		viewport_height: 600
	}
	for name in ['first', 'second'] {
		app.install_loaded_page(LoadedPage{
			url:          'https://swipe.example/${name}'
			markup:       '<!doctype html><style>body{margin:0}#scroller{width:200px;height:100px;overflow:auto}#wide{width:1000px;height:50px}#plain{height:1000px}</style><div id="scroller"><div id="wide"></div></div><div id="plain">Swipe here</div>'
			content_type: 'text/html'
		}, true)
	}
	return app
}

fn test_history_swipe_traverses_back_forward_and_checks_history_bounds() {
	mut app := history_swipe_test_app()
	defer { app.dispose_browser_tab() }
	mut token := unsafe { voidptr(nil) }
	y := app.page_top() + 150
	assert begin_browser_history_swipe(app, -1, 50, y, 12, -1, &token) == 2
	assert token == voidptr(app.document)
	assert app.scroll_y == 0 // Slight vertical drift must not defeat a swipe.
	assert app.history_index == 1 // No navigation before native tracking completes.
	commit_browser_history_swipe(app, token, -1)
	assert app.history_index == 0
	assert app.document.url_string() == 'https://swipe.example/first'
	assert begin_browser_history_swipe(app, -1, 50, y, 12, 0, &token) == 0
	assert begin_browser_history_swipe(app, 1, 50, y, -12, 0, &token) == 2
	commit_browser_history_swipe(app, token, 1)
	assert app.history_index == 1 && app.history.len == 2
	assert app.document.url_string() == 'https://swipe.example/second'
}

fn test_history_swipe_preserves_horizontal_scrollers_and_cancelled_wheel_events() {
	mut app := history_swipe_test_app()
	defer { app.dispose_browser_tab() }
	mut token := unsafe { voidptr(nil) }
	// Forward wheel motion consumes the inner scroller before a history swipe.
	app.history_go(-1)
	assert begin_browser_history_swipe(app, 1, 50, app.page_top() + 25, -12, 0, &token) == 1
	scroller := app.document.get_element_by_id('scroller') or { panic('missing scroller') }
	assert scroller.el_scroll_offset().x() > 0
	assert app.history_index == 0
	plain := app.document.get_element_by_id('plain') or { panic('missing plain') }
	callback := &dom.CallbackType{
		handle_event: fn (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert unsafe { &dom.WheelEvent(event) }.delta_y() == -4.2
			mut wheel := unsafe { &dom.Event(event) }
			wheel.prevent_default()
			return dom.js_undefined()
		}
	}
	unsafe { &dom.EventTarget(plain) }.add_event_listener_without_options('wheel',
		dom.IDLEventListener.create(callback))
	assert begin_browser_history_swipe(app, 1, 50, app.page_top() + 150, -12, 1, &token) == 1
	assert app.history_index == 0
}

fn test_history_swipe_rejects_chrome_busy_navigation_and_stale_document_tokens() {
	mut app := history_swipe_test_app()
	defer { app.dispose_browser_tab() }
	mut token := unsafe { voidptr(nil) }
	y := app.page_top() + 150
	assert begin_browser_history_swipe(app, -1, 50, 0, 12, 0, &token) == 0
	assert begin_browser_history_swipe(app, -1, -1, y, 12, 0, &token) == 0
	assert begin_browser_history_swipe(app, 0, 50, y, 12, 0, &token) == 0
	app.navigation_work_depth = 1
	assert begin_browser_history_swipe(app, -1, 50, y, 12, 0, &token) == 0
	app.navigation_work_depth = 0
	assert begin_browser_history_swipe(app, -1, 50, y, 12, 0, &token) == 2
	app.history_go(-1)
	commit_browser_history_swipe(app, token, 1)
	assert app.history_index == 0
	commit_browser_history_swipe(app, unsafe { nil }, 1)
	assert app.history_index == 0
}

fn test_history_swipe_cannot_navigate_a_different_selected_tab() {
	mut shell := history_swipe_test_app()
	mut other := history_swipe_test_app()
	defer {
		shell.dispose_browser_tab()
		other.dispose_browser_tab()
	}
	shell.tabs = &BrowserTabs{ pages: [shell, other] }
	other.tabs = shell.tabs
	mut token := unsafe { voidptr(nil) }
	assert begin_browser_history_swipe(shell, -1, 50, shell.page_top() + 150, 12, 0,
		&token) == 2
	shell.tabs.selected = 1
	commit_browser_history_swipe(shell, token, -1)
	assert shell.history_index == 1 && other.history_index == 1
}

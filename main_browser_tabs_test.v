module main

import gg
import page

$if vox_ui2 ? {
	import ui2
}

fn browser_tabs_test_app() &BrowserApp {
	owner := page.Page.create(1.0) or { panic(err) }
	mut app := &BrowserApp{
		page_model:                  owner
		script_policy:               .enabled
		viewport_width:              800
		viewport_height:             516
		navigation_results:          chan NavigationResult{cap: 4}
		background_resource_results: chan PreloadedResource{cap: max_cached_resources}
	}
	app.install_chrome_widget_input_bridge()
	app.initialize_browser_tabs()
	app.install_loaded_page(LoadedPage{
		url:          'https://tabs.example/first'
		markup:       '<!doctype html><title>First page</title><input id="editor" value="first"><script>var tabValue = 41;</script>'
		content_type: 'text/html'
	}, true)
	return app
}

fn browser_tabs_test_cleanup(mut app BrowserApp) {
	for mut tab in app.tabs.pages { tab.dispose_browser_tab() }
}

fn test_tabs_keep_independent_dom_javascript_history_and_scroll() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	first_document := app.document
	first_runtime := app.js_runtime
	app.scroll_y = 123
	mut editor := first_document.get_element_by_id('editor') or { panic('missing editor') }
	editor.set_attribute_value('value', 'edited')
	app.activate_tab_chrome('tab-new')
	mut second := app.active_browser_tab()
	assert second != app
	assert second.page_model != app.page_model
	assert second.document != first_document
	assert second.address_active
	assert second.address == ''
	assert second.history.len == 1
	second.install_loaded_page(LoadedPage{
		url:          'https://tabs.example/second'
		markup:       '<!doctype html><title>Second page</title><script>var tabValue = 99;</script>'
		content_type: 'text/html'
	}, true)
	assert second.js_runtime.evaluate('tabValue')! == '99'
	assert second.history.len == 2
	app.activate_tab_chrome('tab-select:0')
	assert app.active_browser_tab() == app
	assert app.document == first_document
	assert app.js_runtime == first_runtime
	assert app.js_runtime.evaluate('tabValue += 1; tabValue')! == '42'
	assert app.scroll_y == 123
	assert app.history.len == 1
	assert app.history_index == 0
	assert app.document.get_element_by_id('editor')?.get_attribute('value')? == 'edited'
	app.activate_tab_chrome('tab-next')
	assert app.active_browser_tab() == second
	assert second.js_runtime.evaluate('tabValue')! == '99'
	chrome := second.browser_chrome_state(800, 600)
	assert chrome.tab_titles == ['First page', 'Second page']
	assert chrome.selected_tab == 1
}

fn test_tab_close_disposes_only_its_owner_and_last_tab_becomes_blank() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	first := app.document
	app.activate_tab_chrome('tab-new')
	mut second := app.active_browser_tab()
	second_document := second.document
	app.activate_tab_chrome('tab-close:0')
	assert first.has_been_destroyed()
	assert app.tabs.pages.len == 1
	assert app.active_browser_tab() == second
	assert !second_document.has_been_destroyed()
	app.activate_tab_chrome('tab-close')
	assert second_document.has_been_destroyed()
	assert app.tabs.pages.len == 1
	assert app.active_browser_tab().browser_tab_title() == 'New Tab'
	assert app.active_browser_tab().address == ''
	assert app.tabs.selected == 0
}

fn test_tab_actions_wait_until_reentrant_navigation_finishes() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	app.navigation_work_depth = 1
	app.activate_tab_chrome('tab-new')
	assert app.tabs.pages.len == 1
	assert app.tabs.pending_actions == ['tab-new']
	app.navigation_work_depth = 0
	// Drain without entering the windowed draw callback.
	pending := app.tabs.pending_actions.clone()
	app.tabs.pending_actions.clear()
	for action in pending { app.activate_tab_chrome(action) }
	assert app.tabs.pages.len == 2
	app.activate_tab_chrome('tab-select:99')
	app.activate_tab_chrome('tab-close:-1')
	assert app.tabs.pages.len == 2
	assert app.tabs.selected == 1
}

fn test_background_navigation_preserves_the_selected_page_and_address() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	first := app.document
	app.activate_tab_chrome('tab-new')
	mut background := app.active_browser_tab()
	app.activate_tab_chrome('tab-select:0')
	app.focus_address_bar()
	background.navigation_results <- NavigationResult{
		generation:  background.navigation_generation
		add_history: true
		loaded:      LoadedPage{
			url:          'https://tabs.example/background'
			markup:       '<!doctype html><title>Background</title><p>Loaded in another tab</p>'
			content_type: 'text/html'
		}
	}
	background.poll_background_browser_tab()
	assert app.active_browser_tab() == app
	assert app.document == first
	assert app.address == 'https://tabs.example/first'
	assert app.address_active
	assert background.browser_tab_title() == 'Background'
	assert background.document.hidden()
	app.activate_tab_chrome('tab-close:1')
	assert app.document == first
	assert app.address_active
}

fn test_tab_shortcuts_and_overflow_keep_all_tabs_reachable() {
	assert browser_tab_shortcut(.t, .super) == 'tab-new'
	assert browser_tab_shortcut(.w, .ctrl) == 'tab-close'
	assert browser_tab_shortcut(.tab, .ctrl) == 'tab-next'
	assert browser_tab_shortcut(.tab, .ctrl | .shift) == 'tab-previous'
	assert browser_tab_shortcut(.left_bracket, .super | .shift) == 'tab-previous'
	assert browser_tab_shortcut(._4, .super) == 'tab-select:3'
	assert browser_tab_shortcut(._9, .super) == 'tab-last'
	assert browser_tab_shortcut(.t, .super | .alt) == ''
	assert browser_tab_shortcut(.t, unsafe { gg.Modifier(0) }) == ''
	for selected in 0 .. 50 {
		first, end := browser_visible_tabs(640, 50, selected)
		assert selected >= first && selected < end
		assert tab_strip_leading_width + 12 + (end - first) * browser_tab_width(640, end - first) + 28 <= 640
	}
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	app.activate_tab_chrome('tab-new')
	app.activate_tab_chrome('tab-next')
	assert app.tabs.selected == 0
	app.activate_tab_chrome('tab-previous')
	assert app.tabs.selected == 1
}

fn test_tab_keyboard_dispatch_runs_before_address_and_page_editing() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	app.handle_key(.t, .super)
	assert app.tabs.pages.len == 2
	mut second := app.active_browser_tab()
	assert second.address_active
	second.handle_key(.t, .super)
	assert app.tabs.pages.len == 3
	mut third := app.active_browser_tab()
	third.handle_key(.w, .super)
	assert app.tabs.pages.len == 2
	mut selected := app.active_browser_tab()
	selected.handle_key(.tab, .ctrl | .shift)
	assert app.active_browser_tab() == app
}

fn test_modified_link_pointer_dispatch_opens_a_background_tab() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	app.install_loaded_page(LoadedPage{
		url:          'https://tabs.example/link'
		markup:       '<!doctype html><style>a{display:block;width:200px;height:40px}</style><a id="link" href="about:home">Open another tab</a>'
		content_type: 'text/html'
	}, false)
	original := app.document
	link := original.get_element_by_id('link') or { panic('missing link') }
	rect := link.get_bounding_client_rect()
	x := f32(rect.x + rect.width / 2)
	y := f32(rect.y + rect.height / 2) + app.page_top()
	app.handle_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: x, mouse_y: y, modifiers: u32(gg.Modifier.super) })
	assert app.pending_tab_link? == 'about:home'
	app.handle_click(x, y)
	app.handle_event(&gg.Event{ typ: .mouse_up, mouse_button: .left, mouse_x: x, mouse_y: y, modifiers: u32(gg.Modifier.super) })
	assert app.tabs.pages.len == 2
	assert app.active_browser_tab() == app
	assert app.document == original
	assert app.pending_native_navigation == none
	assert app.tabs.pages[1].address == 'about:home'
}

$if vox_ui2 ? {
	#include "native_browser_tabs_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_address_shortcut(field voidptr, owner voidptr, callback fn (voidptr, int), key u16, shift int)
	fn C.native_test_tabs_count() int
	fn C.native_test_tabs_click(index int, close int)
	fn C.native_test_tabs_geometry() int
	fn C.native_test_tabs_snapshot()

	fn test_native_tab_buttons_shortcuts_and_live_address_bar_follow_selection() {
		window := C.native_test_address_window()
		mut app := browser_tabs_test_app()
		app.ctx = gg.new_context(native_rendering: true)
		mut owner := unsafe { address_bar_owner }
		owner.app = app
		field := app.mount_ui2_chrome(C.native_test_address_parent(window), 800, 600)!
		defer {
			app.unmount_address_bar()
			browser_tabs_test_cleanup(mut app)
			C.native_test_address_close(window)
		}
		assert C.native_test_tabs_count() == 1
		assert C.native_test_tabs_geometry() == 1
		C.native_test_tabs_click(-1, 0)
		assert app.tabs.pages.len == 2
		assert app.tabs.selected == 1
		mut second := app.active_browser_tab()
		second.update_browser_chrome(800, 600)
		assert C.native_test_tabs_count() == 2
		assert ui2.text('address') == ''
		assert ui2.focused_id() == 'address'
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 18, 0)
		assert app.tabs.selected == 0
		assert ui2.text('address') == 'https://tabs.example/first'
		C.native_test_tabs_click(1, 0)
		assert app.tabs.selected == 1
		second.update_browser_chrome(800, 600)
		C.native_test_tabs_snapshot()
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 13, 0)
		assert app.tabs.pages.len == 1
		assert app.active_browser_tab() == app
		assert ui2.text('address') == 'https://tabs.example/first'
		app.update_browser_chrome(640, 600)
		assert C.native_test_tabs_count() == 1
		assert C.native_test_tabs_geometry() == 1
	}
}

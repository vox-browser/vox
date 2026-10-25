module main

import gg
import page
import platform
import sokol.sapp

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

fn test_tab_reordering_preserves_owners_selection_and_live_page_state() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	first_document := app.document
	first_runtime := app.js_runtime
	app.scroll_y = 123
	app.activate_tab_chrome('tab-new')
	second := app.active_browser_tab()
	app.activate_tab_chrome('tab-new')
	third := app.active_browser_tab()
	app.activate_tab_chrome('tab-select:0')
	app.activate_tab_chrome('tab-move:0:2')
	assert voidptr(app.tabs.pages[0]) == voidptr(second)
	assert voidptr(app.tabs.pages[1]) == voidptr(third)
	assert voidptr(app.tabs.pages[2]) == voidptr(app)
	assert app.tabs.selected == 2
	assert voidptr(app.active_browser_tab()) == voidptr(app)
	assert voidptr(app.document) == voidptr(first_document)
	assert voidptr(app.js_runtime) == voidptr(first_runtime)
	assert app.js_runtime.evaluate('tabValue += 1; tabValue')! == '42'
	assert app.scroll_y == 123
	assert app.history.len == 1 && app.history_index == 0
	assert !first_document.hidden()
	assert second.document.hidden() && third.document.hidden()
	assert app.browser_chrome_state(800, 600).tab_titles == ['New Tab', 'New Tab', 'First page']
	// Moving a background tab across the selection must keep the same page active.
	app.activate_tab_chrome('tab-select:1')
	app.activate_tab_chrome('tab-move:2:0')
	assert app.tabs.selected == 2
	assert voidptr(app.active_browser_tab()) == voidptr(third)
	app.activate_tab_chrome('tab-move:0:2')
	assert app.tabs.selected == 1
	assert voidptr(app.active_browser_tab()) == voidptr(third)
	for action in ['tab-move:-1:0', 'tab-move:0:99', 'tab-move:99:0', 'tab-move:1:1'] {
		app.activate_tab_chrome(action)
	}
	assert voidptr(app.tabs.pages[0]) == voidptr(second)
	assert app.tabs.selected == 1
	app.activate_tab_chrome('tab-next')
	assert voidptr(app.active_browser_tab()) == voidptr(app)
	app.activate_tab_chrome('tab-close:0')
	assert app.tabs.selected == 1
	assert voidptr(app.active_browser_tab()) == voidptr(app)
}

fn test_tab_reordering_waits_for_navigation_work() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	app.activate_tab_chrome('tab-new')
	selected := app.active_browser_tab()
	app.navigation_work_depth = 1
	app.activate_tab_chrome('tab-move:1:0')
	assert app.tabs.selected == 1
	assert app.tabs.pending_actions == ['tab-move:1:0']
	app.navigation_work_depth = 0
	pending := app.tabs.pending_actions.clone()
	app.tabs.pending_actions.clear()
	for action in pending { app.activate_tab_chrome(action) }
	assert app.tabs.selected == 0
	assert voidptr(app.active_browser_tab()) == voidptr(selected)
}

fn browser_tabs_test_pointer(mut app BrowserApp, typ sapp.EventType, x f32, y f32) bool {
	return app.handle_browser_tab_drag(&gg.Event{typ: typ, mouse_button: .left, mouse_x: x, mouse_y: y}, 800)
}

fn test_tab_drag_moves_in_both_directions_and_captures_page_release() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	app.activate_tab_chrome('tab-new')
	app.activate_tab_chrome('tab-new')
	assert browser_tabs_test_pointer(mut app, .mouse_down, 100, 15)
	app.active_browser_tab().handle_click(100, 15)
	assert app.tabs.drag != none
	assert browser_tabs_test_pointer(mut app, .mouse_move, 470, 15)
	assert app.tabs.drag?.moving
	assert browser_tabs_test_pointer(mut app, .mouse_up, 470, 15)
	assert app.tabs.drag == none
	assert app.tabs.selected == 2
	assert voidptr(app.active_browser_tab()) == voidptr(app)
	assert browser_tabs_test_pointer(mut app, .mouse_down, 470, 15)
	assert browser_tabs_test_pointer(mut app, .mouse_move, 100, 15)
	assert browser_tabs_test_pointer(mut app, .mouse_up, 100, 15)
	assert app.tabs.selected == 0
	assert voidptr(app.tabs.pages[0]) == voidptr(app)
	assert browser_tabs_test_pointer(mut app, .mouse_down, 100, 15)
	assert browser_tabs_test_pointer(mut app, .mouse_move, 470, 15)
	assert browser_tabs_test_pointer(mut app, .mouse_up, 470, 200)
	assert app.tabs.selected == 0
	assert voidptr(app.tabs.pages[0]) == voidptr(app)
}

fn test_tab_drag_threshold_close_button_and_cancellation() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	app.activate_tab_chrome('tab-new')
	assert browser_tabs_test_pointer(mut app, .mouse_down, 100, 15)
	assert browser_tabs_test_pointer(mut app, .mouse_move, 102, 15)
	assert !app.tabs.drag?.moving
	assert browser_tabs_test_pointer(mut app, .mouse_up, 102, 15)
	assert app.tabs.selected == 0
	assert !browser_tabs_test_pointer(mut app, .mouse_down, 225, 15) // Close button.
	assert !browser_tabs_test_pointer(mut app, .mouse_down, 455, 15) // New tab.
	assert !browser_tabs_test_pointer(mut app, .mouse_down, 100, 100)
	assert browser_tabs_test_pointer(mut app, .mouse_down, 100, 15)
	assert !browser_tabs_test_pointer(mut app, .mouse_leave, 400, -1)
	assert app.tabs.drag?.cancelled
	assert browser_tabs_test_pointer(mut app, .mouse_up, 400, 15)
	assert app.tabs.drag == none
	assert app.tabs.selected == 0
}

fn test_tabs_keep_zoom_across_navigation_and_start_new_tabs_at_normal_scale() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	app.activate_browser_zoom('zoom-in')
	app.install_loaded_page(LoadedPage{
		url: 'https://tabs.example/zoomed-navigation'
		markup: '<!doctype html><p>Zoomed navigation</p>'
		content_type: 'text/html'
	}, true)
	assert app.page_zoom == 1.1
	assert app.document.viewport_rect().width == f64(app.viewport_width) / 1.1
	app.activate_tab_chrome('tab-new')
	mut second := app.active_browser_tab()
	assert second.page_zoom == 1
	second.activate_browser_zoom('zoom-out')
	app.activate_tab_chrome('tab-select:0')
	assert app.active_browser_tab().page_zoom == 1.1
	app.activate_tab_chrome('tab-select:1')
	assert app.active_browser_tab().page_zoom == 0.9
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
	assert voidptr(second) != voidptr(app)
	assert voidptr(second.page_model) != voidptr(app.page_model)
	assert voidptr(second.document) != voidptr(first_document)
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
	assert voidptr(app.active_browser_tab()) == voidptr(app)
	assert voidptr(app.document) == voidptr(first_document)
	assert voidptr(app.js_runtime) == voidptr(first_runtime)
	assert app.js_runtime.evaluate('tabValue += 1; tabValue')! == '42'
	assert app.scroll_y == 123
	assert app.history.len == 1
	assert app.history_index == 0
	assert app.document.get_element_by_id('editor')?.get_attribute('value')? == 'edited'
	app.activate_tab_chrome('tab-next')
	assert voidptr(app.active_browser_tab()) == voidptr(second)
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
	assert voidptr(app.active_browser_tab()) == voidptr(second)
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

fn test_tab_actions_wait_until_document_scratch_retires_and_native_clients_do_not_log_frames() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	mut scratch := platform.new_arena('tab callback ownership')
	entry := scratch.enter()
	app.activate_tab_chrome('tab-new'.clone())
	$if prealloc {
		assert app.tabs.pages.len == 1
		assert app.tabs.pending_actions == ['tab-new']
	}
	scratch.leave(entry)
	scratch.release()
	$if prealloc {
		pending := app.tabs.pending_actions.clone()
		app.tabs.pending_actions.clear()
		for action in pending { app.activate_tab_chrome(action) }
	}
	assert app.tabs.pages.len == 2
	mut second := app.active_browser_tab()
	mut client := second.page_model.client()
	for _ in 0 .. 1024 {
		client.will_begin_rendering_update()
		client.did_finish_rendering_update()
	}
	assert client.events.len == 0
	app.close_browser_tab(0)
	assert voidptr(app.active_browser_tab()) == voidptr(second)
	client.will_begin_rendering_update()
	client.did_finish_rendering_update()
	assert client.events.len == 0
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
	assert voidptr(app.active_browser_tab()) == voidptr(app)
	assert voidptr(app.document) == voidptr(first)
	assert app.address == 'https://tabs.example/first'
	assert app.address_active
	assert background.browser_tab_title() == 'Background'
	assert background.document.hidden()
	app.activate_tab_chrome('tab-close:1')
	assert voidptr(app.document) == voidptr(first)
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
	assert voidptr(app.active_browser_tab()) == voidptr(app)
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
	assert voidptr(app.active_browser_tab()) == voidptr(app)
	assert voidptr(app.document) == voidptr(original)
	assert app.pending_native_navigation == none
	assert app.tabs.pages[1].address == 'about:home'
}

$if vox_ui2 ? {
	#include "native_browser_tabs_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_address_shortcut(field voidptr, owner voidptr, callback fn (voidptr, int), key u16, shift int) int
	fn C.native_test_tabs_count() int
	fn C.native_test_tabs_click(index int, close int)
	fn C.native_test_tabs_geometry() int
	fn C.native_test_tabs_snapshot()
	fn C.native_test_tabs_drag(index int, dx f64, dy f64)

	fn test_native_tab_drag_survives_chrome_refresh_and_preserves_close_actions() {
		window := C.native_test_address_window()
		mut app := browser_tabs_test_app()
		app.ctx = gg.new_context(native_rendering: true)
		mut owner := unsafe { address_bar_owner }
		owner.app = app
		app.mount_ui2_chrome(C.native_test_address_parent(window), 800, 600)!
		defer {
			app.unmount_address_bar()
			browser_tabs_test_cleanup(mut app)
			C.native_test_address_close(window)
		}
		app.activate_tab_chrome('tab-new')
		app.activate_tab_chrome('tab-new')
		mut third := app.active_browser_tab()
		third.update_browser_chrome(800, 600)
		C.native_test_tabs_drag(0, 368, 0)
		assert app.tabs.selected == 2, app.tabs.pending_actions.str()
		assert voidptr(app.active_browser_tab()) == voidptr(app)
		assert ui2.text('address') == 'https://tabs.example/first'
		C.native_test_tabs_drag(2, -368, 0)
		assert app.tabs.selected == 0
		assert voidptr(app.tabs.pages[0]) == voidptr(app)
		C.native_test_tabs_drag(0, 368, 100)
		assert app.tabs.selected == 0
		assert voidptr(app.tabs.pages[0]) == voidptr(app)
		C.native_test_tabs_drag(0, 2, 0)
		assert app.tabs.selected == 0
		assert C.native_test_tabs_geometry() == 1
		C.native_test_tabs_click(1, 1)
		assert app.tabs.pages.len == 2
		assert voidptr(app.active_browser_tab()) == voidptr(app)
		assert voidptr(app.tabs.pages[1]) == voidptr(third)
		// Overflow selection must not slide the tab slots underneath the pointer.
		for _ in 0 .. 10 { app.activate_tab_chrome('tab-new') }
		mut last := app.active_browser_tab()
		last.update_browser_chrome(800, 600)
		assert C.native_browser_tabs_first() == 3
		source := app.tabs.pages[3]
		C.native_test_tabs_drag(3, 620, 0)
		assert app.tabs.selected == 11
		assert voidptr(app.tabs.pages[11]) == voidptr(source)
		C.native_test_tabs_drag(3, 2, 0)
		assert app.tabs.selected == 3
		assert C.native_browser_tabs_first() == 0
		assert C.native_browser_tabs_end() == 9
		assert C.native_test_tabs_geometry() == 1
	}

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
		assert C.native_test_address_shortcut(field, app, address_bar_shortcut, 24, 1) == 1
		assert second.page_zoom == 1.1 && app.page_zoom == 1
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 18, 0)
		assert app.tabs.selected == 0
		assert app.active_browser_tab().page_zoom == 1
		assert ui2.text('address') == 'https://tabs.example/first'
		C.native_test_tabs_click(1, 0)
		assert app.tabs.selected == 1
		second.update_browser_chrome(800, 600)
		C.native_test_tabs_snapshot()
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 13, 0)
		assert app.tabs.pages.len == 1
		assert voidptr(app.active_browser_tab()) == voidptr(app)
		assert ui2.text('address') == 'https://tabs.example/first'
		app.update_browser_chrome(640, 600)
		assert C.native_test_tabs_count() == 1
		assert C.native_test_tabs_geometry() == 1
	}
}

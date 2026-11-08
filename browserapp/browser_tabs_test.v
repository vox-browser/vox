module main

import gg
import dom
import html
import json2
import os
import time
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
	assert browser_tabs_test_pointer(mut app, .mouse_up, 470, 40)
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
	assert !browser_tabs_test_pointer(mut app, .mouse_down, 236, 15) // Restored 16px close button.
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

fn test_tabs_share_domain_zoom_and_reset_without_changing_other_domains() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	app.activate_browser_zoom('zoom-in')
	app.activate_tab_chrome('tab-new')
	mut second := app.active_browser_tab()
	second.install_loaded_page(LoadedPage{
		url: 'http://tabs.example:8080/second'
		markup: '<!doctype html><p>Same domain</p>'
		content_type: 'text/html'
	}, true)
	assert second.page_zoom == 1.1
	assert second.page_model.client().zoom_level() == 1.1
	app.scroll_y = 110
	app.snapshot_cached = true
	app.snapshot_hold = true
	second.activate_browser_zoom('zoom-in')
	assert second.page_zoom == 1.25 && app.page_zoom == 1.25
	assert app.scroll_y > 124.999999 && app.scroll_y < 125.000001
	assert !app.snapshot_cached && !app.snapshot_hold
	app.activate_tab_chrome('tab-new')
	mut third := app.active_browser_tab()
	third.install_loaded_page(LoadedPage{
		url: 'https://other.example/'
		markup: '<!doctype html><p>Different domain</p>'
		content_type: 'text/html'
	}, true)
	third.activate_browser_zoom('zoom-out')
	assert third.page_zoom == 0.9
	second.activate_browser_zoom('zoom-reset')
	assert app.page_zoom == 1 && second.page_zoom == 1
	assert third.page_zoom == 0.9
	app.activate_tab_chrome('tab-select:0')
	assert app.page_model.client().zoom_level() == 1
	app.install_loaded_page(LoadedPage{
		url: 'https://tabs.example/after-reset'
		markup: '<!doctype html><p>Reset</p>'
		content_type: 'text/html'
	}, true)
	assert app.page_zoom == 1
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
	#include "@VMODROOT/native/include/native_browser_tabs_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_address_shortcut(field voidptr, owner voidptr, callback fn (voidptr, int), key u16, shift int) int
	fn C.native_test_tabs_count(control voidptr) int
	fn C.native_test_tabs_click(control voidptr)
	fn C.native_test_tabs_geometry(control voidptr) int
	fn C.native_test_tabs_snapshot(control voidptr)
	fn C.native_test_tabs_drag(control voidptr, dx f64, dy f64)

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
		C.native_test_tabs_drag(ui2.embedded_browser_control('tab-0'), 368, 0)
		assert app.tabs.selected == 2, app.tabs.pending_actions.str()
		assert voidptr(app.active_browser_tab()) == voidptr(app)
		assert ui2.text('address') == 'https://tabs.example/first'
		C.native_test_tabs_drag(ui2.embedded_browser_control('tab-2'), -368, 0)
		assert app.tabs.selected == 0
		assert voidptr(app.tabs.pages[0]) == voidptr(app)
		C.native_test_tabs_drag(ui2.embedded_browser_control('tab-0'), 368, 25)
		assert app.tabs.selected == 0
		assert voidptr(app.tabs.pages[0]) == voidptr(app)
		C.native_test_tabs_drag(ui2.embedded_browser_control('tab-0'), 2, 0)
		assert app.tabs.selected == 0
		assert C.native_test_tabs_geometry(ui2.embedded_browser_control('tab-strip')) == 1
		C.native_test_tabs_click(ui2.embedded_browser_control('tab-close:1'))
		assert app.tabs.pages.len == 2
		assert voidptr(app.active_browser_tab()) == voidptr(app)
		assert voidptr(app.tabs.pages[1]) == voidptr(third)
		// Overflow selection must not slide the tab slots underneath the pointer.
		for _ in 0 .. 10 { app.activate_tab_chrome('tab-new') }
		mut last := app.active_browser_tab()
		last.update_browser_chrome(800, 600)
		assert ui2.embedded_browser_control('tab-3') != unsafe { nil }
		assert ui2.embedded_browser_control('tab-2') == unsafe { nil }, 'width=${last.browser_chrome.width} count=${last.browser_chrome.tab_titles.len} selected=${last.browser_chrome.selected_tab} drag=${app.tabs.drag != none}'
		source := app.tabs.pages[3]
		C.native_test_tabs_drag(ui2.embedded_browser_control('tab-3'), 620, 0)
		assert app.tabs.selected == 11
		assert voidptr(app.tabs.pages[11]) == voidptr(source)
		C.native_test_tabs_drag(ui2.embedded_browser_control('tab-3'), 2, 0)
		assert app.tabs.selected == 3
		assert ui2.embedded_browser_control('tab-0') != unsafe { nil }
		assert ui2.embedded_browser_control('tab-8') != unsafe { nil }
		assert ui2.embedded_browser_control('tab-9') == unsafe { nil }
		assert C.native_test_tabs_geometry(ui2.embedded_browser_control('tab-strip')) == 1
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
		assert C.native_test_tabs_count(ui2.embedded_browser_control('tab-strip')) == 1
		assert C.native_test_tabs_geometry(ui2.embedded_browser_control('tab-strip')) == 1
		C.native_test_tabs_click(ui2.embedded_browser_control('tab-new'))
		assert app.tabs.pages.len == 2
		assert app.tabs.selected == 1
		mut second := app.active_browser_tab()
		second.update_browser_chrome(800, 600)
		assert C.native_test_tabs_count(ui2.embedded_browser_control('tab-strip')) == 2
		assert ui2.text('address') == ''
		assert ui2.focused_id() == 'address'
		assert C.native_test_address_shortcut(field, app, address_bar_shortcut, 24, 1) == 1
		assert second.page_zoom == 1.1 && app.page_zoom == 1
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 18, 0)
		assert app.tabs.selected == 0
		assert app.active_browser_tab().page_zoom == 1
		assert ui2.text('address') == 'https://tabs.example/first'
		C.native_test_tabs_drag(ui2.embedded_browser_control('tab-1'), 0, 0)
		assert app.tabs.selected == 1
		second.update_browser_chrome(800, 600)
		C.native_test_tabs_snapshot(ui2.embedded_browser_control('tab-strip'))
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 13, 0)
		assert app.tabs.pages.len == 1
		assert voidptr(app.active_browser_tab()) == voidptr(app)
		assert ui2.text('address') == 'https://tabs.example/first'
		app.update_browser_chrome(640, 600)
		assert C.native_test_tabs_count(ui2.embedded_browser_control('tab-strip')) == 1
		assert C.native_test_tabs_geometry(ui2.embedded_browser_control('tab-strip')) == 1
	}
}

fn tab_detach_test_accept(path string) ! {
	_ = read_detached_tab_session(path)!
}

fn tab_detach_test_fail(_ string) ! { return error('test launch failure') }

fn test_tab_detach_launch_options_and_session_validation() {
	path := os.join_path(os.temp_dir(), 'vox tab session-${time.sys_mono_now()}.json')
	defer { os.rm(path) or {} }
	options := parse_launch_options(['--restore-tab', path])!
	assert options.restore_tab == path
	if _ := parse_launch_options(['--restore-tab']) {
		assert false, 'a restore requires a session path'
	}
	os.write_file(path, json2.encode(DetachedTabSession{
		url: 'https://tabs.example/invalid'
		width: 0
		height: 600
		history_index: -1
	}))!
	if _ := read_detached_tab_session(path) {
		assert false, 'invalid window dimensions must not start a detached window'
	}
}

fn test_tab_detach_restores_history_zoom_scroll_and_form_values() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	app.install_loaded_page(LoadedPage{
		url: 'https://tabs.example/forms'
		markup: '<!doctype html><input id="text" value="old"><input id="check" type="checkbox"><textarea id="area">old</textarea><select><option>A</option><option id="chosen">B</option></select><div style="height:2000px"></div>'
		content_type: 'text/html'
	}, true)
	text_element := app.document.get_element_by_id('text') or { panic('missing text input') }
	mut text := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(text_element) })
	text.set_value('unsaved text')!
	check_element := app.document.get_element_by_id('check') or { panic('missing checkbox') }
	mut check := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(check_element) })
	check.set_checked(true)
	check.set_indeterminate(true)
	area_element := app.document.get_element_by_id('area') or { panic('missing textarea') }
	mut area := html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(area_element) })
	area.set_value('unsaved\ntextarea')
	chosen := app.document.get_element_by_id('chosen') or { panic('missing option') }
	html.html_option_element_set_selected(unsafe { &dom.HTMLOptionElement(chosen) }, true)
	app.page_zoom = 1.25
	app.scroll_y = 125
	// Retain forward history, too.
	app.history << HistoryEntry{url: 'https://tabs.example/forward', markup: '<p>Forward</p>'}
	session := json2.decode[DetachedTabSession](json2.encode(app.detached_tab_session()))!
	mut restored := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut restored) }
	restored.restore_detached_tab(session)
	assert restored.source_label == app.source_label
	assert restored.history == app.history
	assert restored.history_index == app.history_index
	assert restored.page_zoom == 1.25 && restored.scroll_y == 125
	assert restored.page_model.client().zoom_level_ == 1.25
	restored_session := restored.detached_tab_session()
	assert restored_session.forms == session.forms
	restored.history_go(1)
	assert restored.source_label == 'https://tabs.example/forward'
	assert restored.page_zoom == 1.25
}

fn test_tab_detach_waits_for_ready_and_tracks_the_owner_after_reordering() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	app.tabs.open_window = tab_detach_test_accept
	app.activate_tab_chrome('tab-new')
	selected := app.active_browser_tab()
	app.activate_tab_chrome('tab-detach:0')
	assert app.tabs.pages.len == 2
	assert app.tabs.pending_detaches.len == 1
	folder := app.tabs.pending_detaches[0].folder
	defer { os.rmdir_all(folder) or {} }
	app.activate_tab_chrome('tab-detach:0') // Ignore duplicate drops during launch.
	assert app.tabs.pending_detaches.len == 1
	app.activate_tab_chrome('tab-move:0:1')
	os.write_file(os.join_path(folder, 'ready'), 'ready')!
	app.poll_detached_tab_windows()
	assert app.tabs.pages.len == 1
	assert voidptr(app.active_browser_tab()) == voidptr(selected)
	assert app.tabs.pending_detaches.len == 0
	assert !os.exists(folder)
}

fn test_tab_detach_failure_timeout_and_final_tab_keep_a_useful_window() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	app.tabs.open_window = tab_detach_test_fail
	app.activate_tab_chrome('tab-detach:0')
	assert app.tabs.pages.len == 1 && app.tabs.pending_detaches.len == 0
	assert app.status.contains('test launch failure')
	app.tabs.open_window = tab_detach_test_accept
	app.activate_tab_chrome('tab-detach:0')
	pending := app.tabs.pending_detaches[0]
	app.tabs.pending_detaches[0] = PendingTabDetach{...pending, started: time.sys_mono_now() - 61_000_000_000}
	app.poll_detached_tab_windows()
	assert app.tabs.pages.len == 1 && app.tabs.pending_detaches.len == 0
	assert app.status.contains('timed out')
	assert !os.exists(pending.folder)
	app.activate_tab_chrome('tab-detach:0')
	folder := app.tabs.pending_detaches[0].folder
	os.write_file(os.join_path(folder, 'ready'), 'ready')!
	app.poll_detached_tab_windows()
	assert app.tabs.pages.len == 1 && app.tabs.pending_detaches.len == 0
	assert app.active_browser_tab().source_label == browser_new_tab_url
}

fn test_tab_detach_vertical_drag_requires_a_drop_below_the_strip() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	app.tabs.open_window = tab_detach_test_accept
	assert browser_tabs_test_pointer(mut app, .mouse_down, 100, 15)
	assert browser_tabs_test_pointer(mut app, .mouse_up, 100, 50)
	assert app.tabs.pending_detaches.len == 0
	assert browser_tabs_test_pointer(mut app, .mouse_down, 100, 15)
	assert browser_tabs_test_pointer(mut app, .mouse_move, 100, 60)
	assert browser_tabs_test_pointer(mut app, .mouse_up, 100, 80)
	assert app.tabs.pages.len == 1 && app.tabs.pending_detaches.len == 1
	folder := app.tabs.pending_detaches[0].folder
	defer { os.rmdir_all(folder) or {} }
	assert read_detached_tab_session(os.join_path(folder, 'session.json'))!.url == 'https://tabs.example/first'
}

$if vox_ui2 ? {
	fn test_native_tab_vertical_drag_opens_a_window_after_the_detach_threshold() {
		window := C.native_test_address_window()
		mut app := browser_tabs_test_app()
		app.ctx = gg.new_context(native_rendering: true)
		app.tabs.open_window = tab_detach_test_accept
		mut owner := unsafe { address_bar_owner }
		owner.app = app
		app.mount_ui2_chrome(C.native_test_address_parent(window), 800, 600)!
		defer {
			for pending in app.tabs.pending_detaches { os.rmdir_all(pending.folder) or {} }
			app.unmount_address_bar()
			browser_tabs_test_cleanup(mut app)
			C.native_test_address_close(window)
		}
		app.activate_tab_chrome('tab-new')
		app.active_browser_tab().update_browser_chrome(800, 600)
		C.native_test_tabs_drag(ui2.embedded_browser_control('tab-0'), 0, 25)
		assert app.tabs.pending_detaches.len == 0
		C.native_test_tabs_drag(ui2.embedded_browser_control('tab-0'), 0, 80)
		assert app.tabs.pages.len == 2 && app.tabs.pending_detaches.len == 1
		assert voidptr(app.tabs.pending_detaches[0].page) == voidptr(app)
		os.write_file(os.join_path(app.tabs.pending_detaches[0].folder, 'ready'), 'ready')!
		app.poll_detached_tab_windows()
		assert app.tabs.pages.len == 1
	}
}

fn test_overlapping_tab_shoulders_keep_the_identity_hit_by_ui2() {
	mut app := browser_tabs_test_app()
	defer { browser_tabs_test_cleanup(mut app) }
	app.activate_tab_chrome('tab-new')
	// Tab 0's visible foot extends into slot 1. UI2 selected tab 0's surface.
	assert app.handle_browser_tab_drag_target(&gg.Event{typ: .mouse_down, mouse_button: .left, mouse_x: 251, mouse_y: 27}, 800, 0)
	assert app.tabs.selected == 0
	assert app.handle_browser_tab_drag_target(&gg.Event{typ: .mouse_up, mouse_button: .left, mouse_x: 251, mouse_y: 27}, 800, 0)
	assert app.tabs.selected == 0
	// Restoring the smaller close button must not leave a dead area beside it.
	app.select_browser_tab(1)
	assert app.handle_browser_tab_drag_target(&gg.Event{typ: .mouse_down, mouse_button: .left, mouse_x: 220, mouse_y: 15}, 800, 0)
	assert app.tabs.selected == 0
	assert app.handle_browser_tab_drag_target(&gg.Event{typ: .mouse_up, mouse_button: .left, mouse_x: 220, mouse_y: 15}, 800, 0)
}

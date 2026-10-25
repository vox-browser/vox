module main

import gg
import page

$if macos {
	#include "native_link_context_menu_test_darwin.h"
	fn C.vox_link_test_begin() voidptr
	fn C.vox_link_test_end(voidptr)
	fn C.vox_link_test_count() int
	fn C.vox_link_test_cancel()
	fn C.vox_link_test_open_in_new_tab()
	fn C.vox_link_test_clipboard_matches(&u8, int) int
	fn C.vox_link_test_position_matches(voidptr, f64, f64) int
}

fn link_context_menu_test_app() &BrowserApp {
	owner := page.Page.create(1) or { panic(err) }
	mut app := &BrowserApp{ page_model: owner, script_policy: .disabled, viewport_width: 800, viewport_height: 516 }
	app.install_loaded_page(LoadedPage{
		url:          'https://links.example/path/page.html'
		markup:       '<!doctype html><base href="https://cdn.example/assets/"><style>a{display:block;width:300px;height:30px}</style><a id="link" href="../download?q=one&amp;lang=ru#part"><strong id="label">Nested link</strong></a><a id="empty" href="">Empty href</a><a id="missing">No href</a><p id="plain">Plain text</p>'
		content_type: 'text/html'
	}, false)
	return app
}

fn link_context_menu_test_point(app &BrowserApp, id string) (f32, f32) {
	rect := app.document.get_element_by_id(id) or { panic('missing ${id}') }.get_bounding_client_rect()
	assert rect.width > 0 && rect.height > 0, 'missing hit geometry for ${id}'
	return f32((rect.x + rect.width / 2) * app.page_zoom), f32((rect.y + rect.height / 2) * app.page_zoom) + app.page_top()
}

fn link_context_menu_test_click(mut app BrowserApp, x f32, y f32, button gg.MouseButton) {
	app.handle_event(&gg.Event{ typ: .mouse_down, mouse_button: button, mouse_x: x, mouse_y: y })
	app.handle_event(&gg.Event{ typ: .mouse_up, mouse_button: button, mouse_x: x, mouse_y: y })
}

fn test_link_url_uses_clicked_ancestor_document_base_and_live_href() {
	$if macos {
		window := C.vox_link_test_begin()
		defer { C.vox_link_test_end(window) }
		mut app := link_context_menu_test_app()
		defer { app.dispose_browser_tab() }
		x, y := link_context_menu_test_point(app, 'label')
		assert app.link_at_point(x, y)? == 'https://cdn.example/download?q=one&lang=ru#part'
		ex, ey := link_context_menu_test_point(app, 'empty')
		empty_destination := app.link_at_point(ex, ey) or { panic('empty href missed at ${ex}, ${ey}') }
		assert empty_destination == 'https://cdn.example/assets/'
		mx, my := link_context_menu_test_point(app, 'missing')
		assert app.link_at_point(mx, my) == none
		mut link := app.document.get_element_by_id('link')?
		link.set_attribute_value('href', 'mailto:hello@example.com')
		assert app.link_at_point(x, y)? == 'mailto:hello@example.com'
		link.remove_attribute('href')
		assert app.link_at_point(x, y) == none
	}
}

fn test_right_click_copies_link_url_without_navigation_and_cancel_preserves_clipboard() {
	$if macos {
		window := C.vox_link_test_begin()
		defer { C.vox_link_test_end(window) }
		mut app := link_context_menu_test_app()
		defer { app.dispose_browser_tab() }
		document := app.document
		app.address = 'unfinished address edit'
		app.hovered_link = 'https://wrong.example/hovered'
		x, y := link_context_menu_test_point(app, 'label')
		link_context_menu_test_click(mut app, x, y, .right)
		expected := 'https://cdn.example/download?q=one&lang=ru#part'
		assert C.vox_link_test_count() == 1
		assert C.vox_link_test_position_matches(window, x, y) == 1
		assert C.vox_link_test_clipboard_matches(expected.str, expected.len) == 1
		assert voidptr(app.document) == voidptr(document)
		assert app.pending_native_navigation == none
		assert app.platform_pointer_buttons == 0
		assert app.navigation_generation == 0
		C.vox_link_test_cancel()
		ex, ey := link_context_menu_test_point(app, 'empty')
		link_context_menu_test_click(mut app, ex, ey, .right)
		assert C.vox_link_test_count() == 2
		assert C.vox_link_test_clipboard_matches(expected.str, expected.len) == 1
	}
}

fn test_right_click_ignores_nonlinks_and_chrome_and_hit_tests_zoomed_links() {
	$if macos {
		window := C.vox_link_test_begin()
		defer { C.vox_link_test_end(window) }
		mut app := link_context_menu_test_app()
		defer { app.dispose_browser_tab() }
		for id in ['missing', 'plain'] {
			x, y := link_context_menu_test_point(app, id)
			link_context_menu_test_click(mut app, x, y, .right)
		}
		link_context_menu_test_click(mut app, 10, 10, .right)
		assert C.vox_link_test_count() == 0
		app.page_zoom = 2
		app.relayout(800, 600)
		x, y := link_context_menu_test_point(app, 'label')
		link_context_menu_test_click(mut app, x, y, .right)
		assert C.vox_link_test_count() == 1
		expected := 'https://cdn.example/download?q=one&lang=ru#part'
		assert C.vox_link_test_clipboard_matches(expected.str, expected.len) == 1
	}
}

fn test_link_context_menu_opens_a_background_tab_after_navigation_work_unwinds() {
	$if macos {
		window := C.vox_link_test_begin()
		defer { C.vox_link_test_end(window) }
		mut app := link_context_menu_test_app()
		app.initialize_browser_tabs()
		defer { app.cleanup_browser_tabs() }
		document := app.document
		x, y := link_context_menu_test_point(app, 'label')
		link_context_menu_test_click(mut app, x, y, .right)
		copied := 'https://cdn.example/download?q=one&lang=ru#part'
		mut link := document.get_element_by_id('link')?
		link.set_attribute_value('href', 'about:home')
		app.address = 'unfinished address edit'
		app.hovered_link = 'https://wrong.example/hovered'
		C.vox_link_test_open_in_new_tab()
		// Production mouse-up holds navigation work while the menu tracks.
		app.navigation_work_depth = 1
		app.show_link_context_menu(x, y)
		assert C.vox_link_test_count() == 2
		assert app.tabs.pages.len == 1
		assert app.tabs.pending_actions == ['tab-open-background:about:home']
		assert C.vox_link_test_clipboard_matches(copied.str, copied.len) == 1
		app.navigation_work_depth = 0
		pending := app.tabs.pending_actions.clone()
		app.tabs.pending_actions.clear()
		for action in pending { app.activate_tab_chrome(action) }
		assert app.tabs.pages.len == 2
		assert voidptr(app.active_browser_tab()) == voidptr(app)
		assert voidptr(app.document) == voidptr(document)
		assert app.document.url_string() == 'https://links.example/path/page.html'
		assert app.tabs.pages[1].address == 'about:home'
		assert app.tabs.pages[1].document.url_string() == 'about:home'
		assert app.pending_native_navigation == none
		assert app.platform_pointer_buttons == 0
		// The same choice also opens immediately when no work scope is active.
		link_context_menu_test_click(mut app, x, y, .right)
		assert C.vox_link_test_count() == 3
		assert app.tabs.pages.len == 3
		assert app.tabs.pages[2].document.url_string() == 'about:home'
		assert voidptr(app.active_browser_tab()) == voidptr(app)
		assert voidptr(app.document) == voidptr(document)
	}
}

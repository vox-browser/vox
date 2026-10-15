module main

import gg
import page

$if macos {
	#include "native_navigation_work_test_darwin.h"
}

fn C.vox_test_navigation_frame_guard() int
fn C.vox_test_navigation_ui_pump() int

fn test_navigation_requested_during_engine_work_waits_for_a_safe_frame() {
	mut app := &BrowserApp{ ctx: &gg.Context{} }
	mut outer := app.begin_navigation_work()
	defer { outer.finish() }
	app.navigate('about:home', true)
	assert app.navigation_generation == 0
	assert voidptr(app.document) == unsafe { nil }
	assert app.deferred_navigation_input?.address == 'about:home'
	mut inner := app.begin_navigation_work()
	app.draw()
	app.poll_deferred_navigation_input()
	assert voidptr(app.document) == unsafe { nil }
	inner.finish()
	assert app.navigation_work_depth == 1
	outer.finish()
	outer.finish()
	assert app.navigation_work_depth == 0
	app.ctx = unsafe { nil }
	app.poll_deferred_navigation_input()
	assert app.navigation_generation == 1
	assert app.deferred_navigation_input == none
	mut document := app.document
	defer { document.finalize() }
	assert app.address == 'about:home'
	assert app.paint_commands.len > 0
}

fn test_input_during_engine_work_preserves_physical_buttons_without_touching_partial_layout() {
	mut app := &BrowserApp{ ctx: &gg.Context{} }
	mut scope := app.begin_navigation_work()
	defer { scope.finish() }
	app.handle_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: 10, mouse_y: 100 })
	assert app.platform_pointer_buttons == 1
	app.handle_event(&gg.Event{ typ: .mouse_up, mouse_button: .left, mouse_x: 10, mouse_y: 100 })
	assert app.platform_pointer_buttons == 0
	app.handle_event(&gg.Event{ typ: .resized, window_width: 900, window_height: 600 })
	app.handle_event(&gg.Event{ typ: .mouse_scroll, scroll_y: 10 })
	app.handle_key(.down, unsafe { gg.Modifier(0) })
	assert voidptr(app.document) == unsafe { nil }
	assert app.paint_commands.len == 0
	assert app.scroll_y == 0
	app.history_go(-1)
	app.history_go(-1)
	assert app.deferred_navigation_input?.is_history
	assert app.deferred_navigation_input?.history_delta == -2
}

fn test_native_frame_updates_keep_the_last_frame_during_document_work_and_reentry() {
	$if macos {
		assert C.vox_test_navigation_frame_guard() == 7
	}
}

fn test_queued_mouse_release_completes_its_link_click_after_preparation() {
	mut owner := page.Page.create(1)!
	mut app := &BrowserApp{ page_model: owner, viewport_width: 320, viewport_height: 200 }
	app.install_loaded_page(LoadedPage{ url: 'https://www.wikipedia.org/', markup: '<!doctype html><a id="italian" href="about:home"><strong>Italiano</strong></a>', content_type: 'text/html' }, false)
	mut original := app.document
	defer { original.finalize() }
	rect := app.document.get_element_by_id('italian')?.get_bounding_client_rect()
	x := f32(rect.x + rect.width / 2)
	y := f32(rect.y + rect.height / 2) + app.page_top()
	app.ctx = &gg.Context{}
	mut scope := app.begin_navigation_work()
	app.handle_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: x, mouse_y: y })
	app.handle_event(&gg.Event{ typ: .mouse_up, mouse_button: .left, mouse_x: x, mouse_y: y })
	assert app.deferred_page_input.len == 2
	assert app.navigation_generation == 0
	scope.finish()
	app.ctx = unsafe { nil }
	app.poll_deferred_page_input()
	assert app.deferred_page_input.len == 0
	assert app.navigation_generation == 1
	assert app.address == 'about:home'
	mut document := app.document
	defer { document.finalize() }
}

fn test_superseded_navigation_discards_queued_page_coordinates() {
	mut app := &BrowserApp{ ctx: &gg.Context{} }
	mut scope := app.begin_navigation_work()
	app.handle_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: 10, mouse_y: 100 })
	app.handle_event(&gg.Event{ typ: .mouse_up, mouse_button: .left, mouse_x: 10, mouse_y: 100 })
	scope.finish()
	app.ctx = unsafe { nil }
	app.navigation_generation++
	app.poll_deferred_page_input()
	assert app.deferred_page_input.len == 0
	assert app.platform_pointer_buttons == 0
	assert app.navigation_generation == 1
}

fn test_native_work_pump_receives_input_posted_from_another_thread() {
	$if macos {
		assert C.vox_test_navigation_ui_pump() == 3
	}
}

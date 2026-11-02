module main

import gg
import page
import browserjs
import platform
import os

fn C.GC_get_free_space_divisor() uint
fn C.GC_call_with_alloc_lock(fn (voidptr) voidptr, voidptr) voidptr

$if gcboehm ? {
	struct NavigationHeapObservation { mut: divisor uint }
	fn navigation_heap_read(context voidptr) voidptr {
		mut state := unsafe { &NavigationHeapObservation(context) }
		state.divisor = C.GC_get_free_space_divisor()
		return unsafe { nil }
	}
	fn navigation_heap_divisor() uint {
		mut state := NavigationHeapObservation{}
		C.GC_call_with_alloc_lock(navigation_heap_read, &state)
		return state.divisor
	}
}

fn test_navigation_guard_keeps_active_heap_policy_until_all_nested_cleanup_finishes() {
	$if gcboehm ? {
		_ = platform.initialize_browser_heap_policy()
		original := navigation_heap_divisor()
		explicit := os.getenv('GC_INITIAL_HEAP_SIZE') != '' || os.getenv('GC_MAXIMUM_HEAP_SIZE') != '' || os.getenv('GC_FREE_SPACE_DIVISOR') != ''
		expected := if explicit || original <= 3 { original } else { uint(3) }
		mut app := &BrowserApp{ctx: &gg.Context{}}
		mut outer := app.begin_navigation_work()
		assert navigation_heap_divisor() == expected
		mut inner := app.begin_navigation_work()
		inner.finish()
		assert navigation_heap_divisor() == expected
		outer.finish()
		assert navigation_heap_divisor() == original
	}
}

$if macos {
	#include "native_navigation_work_test_darwin.h"
}

fn C.vox_test_navigation_frame_guard() int
fn C.vox_test_navigation_ui_pump() int
fn C.vox_test_navigation_ui_redraw_generation() int
fn C.vox_test_queue_navigation_redraw()
fn C.vox_test_navigation_native_size_invalidations() int
fn C.vox_test_begin_prepared_frame()
fn C.vox_test_end_prepared_frame()

fn test_native_frame_consumes_preparation_wakes_but_retains_pending_document_work() {
	$if !macos { return }
	mut owner := page.Page.create(1)!
	mut app := &BrowserApp{page_model: owner, ctx: &gg.Context{}, viewport_width: 320, viewport_height: 200}
	app.install_loaded_page(LoadedPage{url: 'https://frame-work.example/', content_type: 'text/html', markup: '<!doctype html><p>ready</p>'}, false)
	mut document := app.document
	defer { document.finalize() }
	C.vox_test_begin_prepared_frame()
	defer { C.vox_test_end_prepared_frame() }
	app.begin_frame_preparation()
	app.poll_javascript_tasks()
	app.poll_background_resources()
	app.finish_frame_preparation()
	C.vox_browser_frame_prepared()
	assert app.native_frame_consumed_work()
	app.background_resource_pending['https://frame-work.example/image'] = true
	assert !app.native_frame_consumed_work()
	app.background_resource_pending.clear()
	mut images := &BrowserImageRequestLoader{
		document: document
		results: chan PreloadedResource{cap: 1}
		active_fetches: 1
	}
	app.image_request_loader = images
	// Waiting on a fetch does not need continuous frames. A completion arriving
	// after the resource poll must keep its wake, even before the paint boundary.
	assert app.native_frame_consumed_work()
	images.results <- PreloadedResource{url: 'https://frame-work.example/image'}
	C.vox_test_queue_navigation_redraw()
	for _ in 0 .. 1000 { if C.vox_service_navigation_ui() != 0 { break } }
	C.vox_browser_frame_prepared()
	assert !app.native_frame_consumed_work()
	_ = <-images.results
	assert app.native_frame_consumed_work()
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	app.js_runtime = runtime
	runtime.mark_document_state_dirty()
	assert !app.native_frame_consumed_work()
	assert runtime.take_document_state_dirty()
	assert app.native_frame_consumed_work()
	// A new invalidation delivered after the paint boundary remains pending.
	C.vox_test_queue_navigation_redraw()
	for _ in 0 .. 1000 { if C.vox_service_navigation_ui() != 0 { break } }
	assert !app.native_frame_consumed_work()
}

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
	// Layout uses display pixels on Retina; native input uses CSS viewport pixels.
	scale := app.document.layout_coordinate_scale()
	x := f32((rect.x + rect.width / 2) / scale * app.page_zoom)
	y := f32((rect.y + rect.height / 2) / scale * app.page_zoom) + app.page_top()
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

fn test_deferred_input_backing_survives_the_recording_checkpoint_that_queued_it() {
	mut app := &BrowserApp{ctx: &gg.Context{}}
	mut scope := app.begin_navigation_work()
	mut recording := platform.new_arena('input recording checkpoint')
	entry := recording.enter()
	app.handle_event(&gg.Event{typ: .mouse_move, mouse_x: 17, mouse_y: 100})
	app.handle_event(&gg.Event{typ: .mouse_down, mouse_button: .left, mouse_x: 19, mouse_y: 100})
	app.handle_event(&gg.Event{typ: .mouse_up, mouse_button: .left, mouse_x: 23, mouse_y: 100})
	recording.leave(entry)
	recording.release()
	assert app.deferred_page_input.len == 3
	assert app.deferred_page_input[0].event.mouse_x == 17
	assert app.deferred_page_input[1].event.mouse_x == 19
	assert app.deferred_page_input[2].event.mouse_x == 23
	scope.finish()
	app.ctx = unsafe { nil }
	app.navigation_generation++
	app.poll_deferred_page_input()
	assert app.deferred_page_input.len == 0
}

fn test_native_work_pump_receives_input_posted_from_another_thread() {
	$if macos {
		assert C.vox_test_navigation_ui_pump() == 3
	}
}

fn test_native_work_pump_preserves_actual_resource_redraws_without_creating_idle_redraws() {
	$if macos {
		assert C.vox_test_navigation_ui_redraw_generation() == 7
		mut app := &BrowserApp{ctx: &gg.Context{}}
		mut scope := app.begin_navigation_work()
		service_navigation_ui(voidptr(app))
		assert !app.navigation_work_yielded
		C.vox_test_queue_navigation_redraw()
		for _ in 0 .. 16 {
			service_navigation_ui(voidptr(app))
			if app.navigation_work_yielded { break }
		}
		assert app.navigation_work_yielded
		scope.finish()
		// Finishing preserves the consumed resource wake once, after which an
		// idle checkpoint must not turn that follow-up frame into a feedback loop.
		service_navigation_ui(voidptr(app))
		mut idle_scope := app.begin_navigation_work()
		service_navigation_ui(voidptr(app))
		assert !app.navigation_work_yielded
		idle_scope.finish()
	}
}

fn test_native_work_pump_preserves_changed_view_size_and_backing_invalidations() {
	$if macos {
		assert C.vox_test_navigation_native_size_invalidations() == 7
	}
}

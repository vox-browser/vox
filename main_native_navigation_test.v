module main

import dom
import page

$if darwin {
	#include "native_navigation_test_darwin.h"
}

fn C.vox_navigation_test_window() voidptr
fn C.vox_navigation_test_close_window(voidptr)

fn native_navigation_test_app(scripts string) &BrowserApp {
	mut owner := page.Page.create(1) or { panic(err) }
	mut app := &BrowserApp{ page_model: owner, script_policy: .enabled, viewport_width: 320, viewport_height: 200 }
	app.install_loaded_page(LoadedPage{
		url:          'https://www.wikipedia.org/'
		markup:       '<!doctype html><a id="italian" href="https://it.wikipedia.org/">Italiano</a>' + scripts
		content_type: 'text/html'
	}, false)
	return app
}

fn native_navigation_test_click(mut app BrowserApp) (f32, f32) {
	link := app.document.get_element_by_id('italian') or { panic('missing link') }
	rect := link.get_bounding_client_rect()
	x := rect.x + rect.width / 2
	y := rect.y + rect.height / 2
	_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', 0, x, y)
	_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', 0, x, y)
	return f32(x), f32(y) + app.page_top()
}

fn test_native_link_activation_hands_off_without_replacing_the_active_document() {
	mut app := native_navigation_test_app('')
	mut document := app.document
	defer { document.finalize() }
	_, _ = native_navigation_test_click(mut app)
	assert app.pending_native_navigation? == 'https://it.wikipedia.org/'
	assert voidptr(app.document) == voidptr(document)
	assert document.is_fully_active()
	assert document.navigable()?.active_document()? == document
	assert app.navigation_generation == 0
	assert app.history.len == 0
}

fn test_compact_click_cancellation_discards_native_navigation() {
	$if !darwin {
		return
	}
	window := C.vox_navigation_test_window()
	defer { C.vox_navigation_test_close_window(window) }
	mut app := native_navigation_test_app('<script>globalThis.cancelCalls=0;document.getElementById("italian").addEventListener("click",function(event){cancelCalls++;event.preventDefault()});</script>')
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	assert app.js_runtime.evaluate_host('cancelCalls')! == '0'
	x, y := native_navigation_test_click(mut app)
	assert app.pending_native_navigation != none
	hit := app.element_at_window_point(x, y) or { panic('compact click missed its native target') }
	assert hit.get_attribute_value('id') == 'italian'
	app.replay_compact_javascript_click(x, y)
	assert app.js_runtime.evaluate_host('cancelCalls')! == '1'
	assert app.pending_native_navigation == none
	assert voidptr(app.document) == voidptr(document)
	assert document.is_fully_active()
	assert app.navigation_generation == 0
}

fn test_native_click_cancellation_leaves_no_navigation_request() {
	mut app := native_navigation_test_app('')
	mut document := app.document
	defer { document.finalize() }
	link := document.get_element_by_id('italian') or { panic('missing link') }
	mut target := unsafe { &dom.EventTarget(link) }
	target.add_event_listener_without_options('click', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut mutable_event := unsafe { &dom.Event(event) }
			mutable_event.prevent_default()
			return dom.js_undefined()
		}
	}))
	_, _ = native_navigation_test_click(mut app)
	assert app.pending_native_navigation == none
	assert !app.page_model.event_handler.last_click_allowed()
	assert document.is_fully_active()
}

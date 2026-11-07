module main

import dom
import page

$if darwin {
	#include "@VMODROOT/native_navigation_test_darwin.h"
}

fn C.vox_navigation_test_window() voidptr
fn C.vox_navigation_test_close_window(voidptr)

fn native_navigation_test_app(scripts string) &BrowserApp {
	return native_navigation_test_markup('<a id="italian" href="https://it.wikipedia.org/">Italiano</a>' + scripts)
}

fn native_navigation_test_markup(markup string) &BrowserApp {
	mut owner := page.Page.create(1) or { panic(err) }
	mut app := &BrowserApp{ page_model: owner, script_policy: .enabled, viewport_width: 320, viewport_height: 200 }
	app.install_loaded_page(LoadedPage{
		url:          'https://www.wikipedia.org/'
		markup:       '<!doctype html>' + markup
		content_type: 'text/html'
	}, false)
	return app
}

fn test_native_link_text_inside_nested_labels_activates_navigation() {
	mut app := native_navigation_test_markup('<a id="italian" href="https://it.wikipedia.org/" style="display:block;width:160px;padding:12px;text-align:center"><strong id="label">Italiano</strong><br><small id="count">1.989.000+ <span id="unit">voci</span></small></a>')
	mut document := app.document
	defer { document.finalize() }
	for id in ['label', 'count', 'unit'] {
		element := document.get_element_by_id(id) or { panic('missing label') }
		rect := element.get_bounding_client_rect()
		x := rect.x + rect.width / 2
		y := rect.y + rect.height / 2
		_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', 0, x, y)
		_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', 0, x, y)
		assert app.page_model.event_handler.last_click_allowed(), id
		assert app.pending_native_navigation? == 'https://it.wikipedia.org/', id
		assert voidptr(app.document) == voidptr(document)
		assert document.is_fully_active()
		app.pending_native_navigation = none
	}
}

fn test_native_link_click_survives_subpixel_movement_between_its_labels() {
	mut app := native_navigation_test_markup('<style>strong,small{display:block;height:20px}</style><a id="italian" href="https://it.wikipedia.org/" style="display:block;width:160px;padding:12px"><strong id="label">Italiano</strong><small id="count">1.989.000+ voci</small></a>')
	mut document := app.document
	defer { document.finalize() }
	label := document.get_element_by_id('label') or { panic('missing label') }
	rect := label.get_bounding_client_rect()
	x := rect.x + rect.width / 2
	y := rect.y + rect.height
	assert app.hit_test_at_viewport_point(x, y - 0.25)?.element.get_attribute_value('id') == 'label'
	assert app.hit_test_at_viewport_point(x, y + 0.25)?.element.get_attribute_value('id') == 'count'
	_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', 0, x, y - 0.25)
	_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', 0, x, y + 0.25)
	assert app.page_model.event_handler.last_click_allowed()
	assert app.pending_native_navigation? == 'https://it.wikipedia.org/'
	assert voidptr(app.document) == voidptr(document)
	assert document.is_fully_active()
}

fn test_compact_cancellation_on_shared_link_ancestor_blocks_moving_click() {
	mut app := native_navigation_test_markup('<a id="italian" href="https://it.wikipedia.org/" style="display:block;padding:12px"><strong id="label">Italiano</strong></a><script>globalThis.cancelCalls=0;document.getElementById("italian").addEventListener("click",function(event){cancelCalls++;event.preventDefault()});</script>')
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	label := document.get_element_by_id('label') or { panic('missing label') }
	link := document.get_element_by_id('italian') or { panic('missing link') }
	rect := label.get_bounding_client_rect()
	padding := link.get_bounding_client_rect()
	_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', 0, rect.x + rect.width / 2, rect.y + rect.height / 2)
	_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', 0, padding.x + 2, padding.y + 2)
	assert app.page_model.event_handler.last_click_allowed()
	assert app.pending_native_navigation != none
	app.replay_compact_javascript_click()
	assert app.js_runtime.evaluate_host('cancelCalls')! == '1'
	assert app.pending_native_navigation == none
	assert app.navigation_generation == 0
	assert voidptr(app.document) == voidptr(document)
}

fn test_release_over_a_different_link_replays_the_common_parent_without_navigation() {
	mut app := native_navigation_test_markup('<div id="container"><a id="italian" href="https://it.wikipedia.org/">Italiano</a><a id="other" href="about:home">Other link</a></div><script>globalThis.parentCalls=0;globalThis.otherCalls=0;document.getElementById("container").addEventListener("click",function(){parentCalls++});document.getElementById("other").addEventListener("click",function(){otherCalls++});</script>')
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	first := document.get_element_by_id('italian')?.get_bounding_client_rect()
	other := document.get_element_by_id('other')?.get_bounding_client_rect()
	_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', 0, first.x + first.width / 2, first.y + first.height / 2)
	_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', 0, other.x + other.width / 2, other.y + other.height / 2)
	assert app.page_model.event_handler.last_click_allowed()
	assert app.pending_native_navigation == none
	app.replay_compact_javascript_click()
	assert app.js_runtime.evaluate_host('parentCalls')! == '1'
	assert app.js_runtime.evaluate_host('otherCalls')! == '0'
	assert app.navigation_generation == 0
	assert voidptr(app.document) == voidptr(document)
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
	app.replay_compact_javascript_click()
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

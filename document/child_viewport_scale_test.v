module main

import dom
import html
import layout
import page
import time

// A parent laid out in device coordinates still gives a hosted document a
// viewport in CSS pixels; the hidden Cloudflare frame on 4chan reads it as
// innerWidth.
fn test_device_layout_parent_keeps_child_viewport_in_css_pixels() {
	$if !darwin {
		return
	}
	owner := page.Page.create(1) or { panic(err) }
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><body style="margin:0"><iframe style="width:300px;height:150px;border:0;visibility:hidden" srcdoc="<p>child"></iframe>',
		dom.URL{ value: 'https://device-frame.example/' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut host := browser_child_document_host(document, .javascriptcore)
	layout.enable_native_paint_tree_storage(document)
	mut messages := []string{}
	host.discover(document, mut messages)
	mut app := &BrowserApp{ document: document, page_model: owner, child_document_host: host, viewport_width: 320, viewport_height: 200 }
	defer {
		if mut owned := app.child_document_host { owned.close() }
		app.document.destroy_a_document_and_its_descendants()
		app.document.finalize()
		app.document.release_native_storage()
	}
	mut loop := html.main_thread_event_loop()
	deadline := time.sys_mono_now() + 10 * time.second
	loop.spin_until(fn [app, deadline] () bool {
		mut browser := unsafe { &BrowserApp(app) }
		browser.begin_frame_preparation()
		browser.poll_browser_child_documents()
		browser.finish_frame_preparation()
		host := browser.child_document_host or { return false }
		service := host.children[0].service or { return false }
		return service.initialized || time.sys_mono_now() >= deadline
	})
	service := app.child_document_host?.children[0].service?
	assert service.initialized
	app.document.set_layout_coordinate_scale(2)
	app.relayout(320, 200 + app.chrome_height())
	_ = layout.document_layout_result(app.document)?.paint_tree.paint_commands()
	viewport := service.document.viewport_rect()
	assert viewport.width == 300 && viewport.height == 150, '${viewport}'
}

module main

import dom
import encoding.base64
import html
import os

const lazy_native_png = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='
const lazy_native_wide_png = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8AAQv8BD/kD/YURmXYAAAAASUVORK5CYII='

fn lazy_native_test_app(markup string, scripting bool) &BrowserApp {
	mut document := parse_loaded_browser_navigation_document(LoadedPage{
		url: 'about:blank'
		markup: '<!doctype html><style>html,body{margin:0}</style>${markup}'
	}, dom.url_about_blank(), none, none, none, scripting)
	document.set_viewport_rect(dom.Rect{width:320,height:200})
	mut app := &BrowserApp{document:document,viewport_width:320,viewport_height:200}
	loader := new_browser_image_request_loader(document, map[string]PreloadedResource{})
	app.image_request_loader = loader
	install_static_browser_image_fetch_hooks_with_loader(document, map[string]bool{}, loader)
	return app
}

fn lazy_native_test_model(app &BrowserApp, id string) &html.HTMLImageElementModel {
	element := app.document.get_element_by_id(id) or { panic('missing ${id}') }
	return html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
}

fn test_native_lazy_images_wait_for_geometry_and_load_when_scrolled_near() {
	mut app := lazy_native_test_app('<img id="near" loading="LaZy" width="1" height="1" src="${lazy_native_png}"><div style="height:4000px"></div><img id="far" loading="lazy" width="2" height="1" src="${lazy_native_wide_png}">', true)
	defer { if mut owner := app.image_request_loader { owner.cancel() }; app.document.finalize() }
	loader := app.image_request_loader?
	near := lazy_native_test_model(app, 'near')
	far := lazy_native_test_model(app, 'far')
	assert loader.deferred_lazy_images.len == 2
	assert !near.complete() && !far.complete()
	assert !app.document.anything_is_delaying_the_load_event()
	assert !app.resume_deferred_lazy_image_requests()
	app.begin_frame_preparation()
	app.relayout(320, 284)
	app.finish_frame_preparation()
	assert near.complete() && near.natural_width() == 1
	assert !far.complete() && far.event_count('load') == 0
	assert loader.deferred_lazy_images.len == 1
	app.set_scroll_y(4000, 284)
	assert app.resume_deferred_lazy_image_requests()
	assert far.complete() && far.natural_width() == 2
	assert near.event_count('load') == 1 && far.event_count('load') == 1
	assert loader.deferred_lazy_images.len == 0
	assert !app.resume_deferred_lazy_image_requests()
}

fn test_lazy_image_negative_probe_is_reused_until_geometry_or_policy_changes() {
	mut app := lazy_native_test_app('<div style="height:5000px"></div><img id="far" loading="lazy" width="1" height="1" src="${lazy_native_png}">', true)
	defer { if mut owner := app.image_request_loader { owner.cancel() }; app.document.finalize() }
	app.relayout(320, 284)
	loader := app.image_request_loader?
	assert !app.resume_deferred_lazy_image_requests()
	assert loader.lazy_image_probe.valid
	probe := loader.lazy_image_probe
	for _ in 0 .. 3 {
		assert !app.has_resumable_lazy_image_requests()
		assert !app.resume_deferred_lazy_image_requests()
		assert loader.lazy_image_probe == probe
	}
	mut image := app.document.get_element_by_id('far')?
	image.set_attribute_value('loading', 'eager')
	app.relayout(320, 284)
	assert app.has_resumable_lazy_image_requests()
	assert app.resume_deferred_lazy_image_requests()
	assert lazy_native_test_model(app, 'far').complete()
}

fn test_lazy_image_negative_probe_observes_nested_scrolling_without_new_commands() {
	mut app := lazy_native_test_app('<div id="scroller" style="height:200px;overflow:auto"><div style="height:5000px"></div><img id="far" loading="lazy" width="1" height="1" src="${lazy_native_png}"></div>', true)
	defer { if mut owner := app.image_request_loader { owner.cancel() }; app.document.finalize() }
	app.relayout(320, 284)
	assert !app.resume_deferred_lazy_image_requests()
	loader := app.image_request_loader?
	assert loader.lazy_image_probe.valid
	probe := loader.lazy_image_probe
	generation := app.paint_generation
	mut scroller := app.document.get_element_by_id('scroller')?
	scroller.set_scroll_top(4900)
	assert app.paint_generation == generation
	assert app.has_resumable_lazy_image_requests()
	assert (app.deferred_lazy_image_probe(loader) or { panic('missing scroll probe') }) != probe
	assert app.resume_deferred_lazy_image_requests()
	assert lazy_native_test_model(app, 'far').complete()
}

fn test_lazy_image_negative_probe_still_discards_a_superseded_model_request() {
	mut app := lazy_native_test_app('<div style="height:5000px"></div><img id="far" loading="lazy" width="1" height="1" src="${lazy_native_png}">', true)
	defer { if mut owner := app.image_request_loader { owner.cancel() }; app.document.finalize() }
	app.relayout(320, 284)
	assert !app.resume_deferred_lazy_image_requests()
	loader := app.image_request_loader?
	assert loader.lazy_image_probe.valid
	mut model := lazy_native_test_model(app, 'far')
	// This public model operation changes request ownership without touching
	// the DOM or any of the geometry revisions in the negative probe.
	model.upgrade_pending_request_to_current_request()
	assert model.pending_request() == none
	assert !app.resume_deferred_lazy_image_requests()
	assert loader.deferred_lazy_images.len == 0
}

fn test_native_lazy_images_resume_on_reveal_or_eager_attribute_change() {
	for reveal in [false,true] {
		mut app := lazy_native_test_app('<img id="image" loading="lazy" style="display:none" src="${lazy_native_png}">', true)
		defer { if mut owner := app.image_request_loader { owner.cancel() }; app.document.finalize() }
		app.relayout(320,284)
		assert !app.resume_deferred_lazy_image_requests()
		mut element := app.document.get_element_by_id('image')?
		if reveal { element.set_attribute_value('style','display:block') }
		else { element.set_attribute_value('loading','eager') }
		app.relayout(320,284)
		assert app.resume_deferred_lazy_image_requests()
		model := lazy_native_test_model(app,'image')
		assert model.complete() && model.natural_width() == 1
		assert model.event_count('load') == 1 && model.event_count('error') == 0
	}
}

fn test_native_lazy_image_source_replacement_discards_the_old_completion() {
	mut app := lazy_native_test_app('<div style="height:4000px"></div><img id="image" loading="lazy" width="2" height="1" src="${lazy_native_wide_png}">',true)
	defer { if mut owner := app.image_request_loader { owner.cancel() }; app.document.finalize() }
	mut element := app.document.get_element_by_id('image')?
	element.set_attribute_value('src',lazy_native_png)
	// Match the native binding's ordered DOM write and image-model hook.
	html.html_image_element_form_associated_element_attribute_changed(
		unsafe { &dom.HTMLImageElement(element) },'src',lazy_native_wide_png,lazy_native_png,none)
	loader := app.image_request_loader?
	assert loader.deferred_lazy_images.len == 2
	app.relayout(320,284)
	assert !app.has_resumable_lazy_image_requests()
	assert !app.resume_deferred_lazy_image_requests()
	assert loader.deferred_lazy_images.len == 1
	app.set_scroll_y(4000,284)
	assert app.has_resumable_lazy_image_requests()
	assert app.resume_deferred_lazy_image_requests()
	model := lazy_native_test_model(app,'image')
	assert model.complete() && model.natural_width() == 1
	assert model.event_count('load') == 1 && model.event_count('error') == 0
}

fn test_native_lazy_images_keep_eager_loading_without_scripting_and_cancel_cleanly() {
	mut eager := lazy_native_test_app('<img id="image" loading="lazy" style="display:none" src="${lazy_native_png}">',false)
	defer { eager.document.finalize() }
	assert lazy_native_test_model(eager,'image').complete()
	assert eager.image_request_loader?.deferred_lazy_images.len == 0
	mut lazy := lazy_native_test_app('<img id="image" loading="lazy" src="${lazy_native_png}">',true)
	defer { lazy.document.finalize() }
	mut loader := lazy.image_request_loader?
	assert loader.deferred_lazy_images.len == 1
	loader.cancel()
	assert loader.deferred_lazy_images.len == 0
	lazy.relayout(320,284)
	assert !lazy.has_resumable_lazy_image_requests()
	assert !lazy.resume_deferred_lazy_image_requests()
	assert lazy_native_test_model(lazy,'image').event_count('load') == 0
	assert lazy_native_test_model(lazy,'image').event_count('error') == 0
}

fn test_capture_waits_for_started_lazy_request_but_not_distant_deferred_images() {
	address := 'https://lazy-native.test/visible.png'
	mut app := lazy_native_test_app('<img id="image" loading="lazy" width="1" height="1" src="${address}"><div style="height:4000px"></div><img loading="lazy" width="1" height="1" src="${lazy_native_png}">',true)
	defer { if mut owner := app.image_request_loader { owner.cancel() }; app.document.finalize() }
	mut loader := app.image_request_loader?
	// Deliver the real request completion through the loader's transport seam,
	// keeping the response under test control without starting network I/O.
	request := loader.deferred_lazy_images[0]
	loader.deferred_lazy_images.delete(0)
	key := app.document.url.serialize()+'\n'+address
	loader.pending[key] = [request.complete]
	loader.active_fetches = 1
	app.relayout(320,284)
	app.document.update_readiness(.complete)
	loop := html.main_thread_event_loop()
	loop.update_font_face_sets_pending_on_the_environment([app.document])
	assert !app.document.anything_is_delaying_the_load_event()
	assert app.font_resources_ready_for_capture()
	assert !app.document_resources_ready_for_capture()
	loader.results <- PreloadedResource{
		url:address
		source_url:app.document.url.serialize()
		request_type:'image'
		body:base64.decode(lazy_native_png.all_after(',')).bytestr()
	}
	app.poll_browser_image_requests()
	app.relayout(320,284)
	loop.update_font_face_sets_pending_on_the_environment([app.document])
	assert lazy_native_test_model(app,'image').complete()
	assert loader.pending.len == 0 && loader.deferred_lazy_images.len == 1
	assert app.document_resources_ready_for_capture()
}

fn test_capture_keeps_nearby_lazy_images_at_the_initial_viewport_after_a_cache_hit() {
	previous := os.getenv_opt('VOX_CAPTURE_INITIAL_VIEWPORT')
	os.setenv('VOX_CAPTURE_INITIAL_VIEWPORT', '1', true)
	defer {
		if value := previous { os.setenv('VOX_CAPTURE_INITIAL_VIEWPORT', value, true) }
		else { os.unsetenv('VOX_CAPTURE_INITIAL_VIEWPORT') }
	}
	mut app := lazy_native_test_app('<div style="display:flex;gap:10px">' +
		'<img id="first" loading="lazy" src="${lazy_native_png}">' +
		'<img id="second" loading="lazy" src="${lazy_native_wide_png}">' +
		'<img id="third" loading="lazy" src="${lazy_native_png}"></div>' +
		'<div style="height:5000px"></div><img id="far" loading="lazy" src="${lazy_native_wide_png}">', true)
	defer { if mut owner := app.image_request_loader { owner.cancel() }; app.document.finalize() }
	app.screenshot_path = 'capture.png'
	app.screenshot_scroll_y = 3200
	app.relayout(320, 284)
	assert app.resume_deferred_lazy_image_requests()
	// A synchronous response changes intrinsic geometry. The remaining images
	// stay deferred until that layout has completed, despite no network job.
	loader := app.image_request_loader?
	assert lazy_native_test_model(app, 'first').complete()
	assert !lazy_native_test_model(app, 'second').complete()
	assert loader.pending.len == 0
	app.relayout(320, 284)
	app.document.update_readiness(.complete)
	loop := html.main_thread_event_loop()
	loop.update_font_face_sets_pending_on_the_environment([app.document])
	assert app.font_resources_ready_for_capture()
	assert !app.document_resources_ready_for_capture()
	assert capture_retry_needs_frame(voidptr(app)) == 1
	assert capture_scroll_retry_needs_frame(voidptr(app)) == 1
	app.note_screenshot_initial_viewport(true)
	app.apply_screenshot_scroll_if_ready(284)
	assert app.scroll_y == 0 && !app.screenshot_initial_viewport_ready
	// Each ordinary frame can service another synchronous response and layout.
	for _ in 0 .. 3 {
		app.begin_frame_preparation()
		app.finish_frame_preparation()
		loop.update_font_face_sets_pending_on_the_environment([app.document])
	}
	assert lazy_native_test_model(app, 'second').complete()
	assert lazy_native_test_model(app, 'third').complete()
	assert !lazy_native_test_model(app, 'far').complete()
	assert loader.deferred_lazy_images.len == 1
	assert app.document_resources_ready_for_capture()
	app.note_screenshot_initial_viewport(true)
	app.apply_screenshot_scroll_if_ready(284)
	assert app.scroll_y == 3200 && app.screenshot_initial_viewport_ready
}

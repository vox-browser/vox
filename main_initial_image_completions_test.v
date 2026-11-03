module main

import html
import layout

@[heap]
struct InitialImageCompletionRecord {
mut:
	calls int
	available bool
}

fn initial_image_completion_fixture() (BrowserApp, &InitialImageCompletionRecord) {
	document := html.parse_document('<!doctype html><p>first geometry</p>')
	mut record := &InitialImageCompletionRecord{}
	address := 'https://initial-image.test/missing.png'
	mut loader := &BrowserImageRequestLoader{
		document: document
		results: chan PreloadedResource{cap: 1}
		active_fetches: 1
	}
	loader.pending['https://initial-image.test/\n' + address] = [fn [mut record] (image ?html.DecodedImageData) {
		record.calls++
		record.available = image != none
	}]
	loader.results <- PreloadedResource{
		url: address
		source_url: 'https://initial-image.test/'
		error: 'fixture failure'
	}
	return BrowserApp{document: document, image_request_loader: loader}, record
}

fn test_buffered_initial_image_completions_do_not_build_geometry_or_retry_failures() {
	mut app, record := initial_image_completion_fixture()
	defer { app.document.finalize() }
	app.finish_initial_ready_image_requests()
	assert record.calls == 1 && !record.available
	assert app.document.layout_root == unsafe { nil }
	loader := app.image_request_loader?
	assert loader.active_fetches == 0 && loader.results.len == 0 && loader.pending.len == 0
	app.finish_initial_ready_image_requests()
	assert record.calls == 1
}

fn test_initial_completion_step_leaves_existing_layout_on_the_regular_frame_path() {
	mut app, record := initial_image_completion_fixture()
	defer { app.document.finalize() }
	_ = layout.layout_document_typed_in_viewport(app.document, 320, 200)
	app.finish_initial_ready_image_requests()
	assert record.calls == 0
	assert app.image_request_loader?.results.len == 1
}

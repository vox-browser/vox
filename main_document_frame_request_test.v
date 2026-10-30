module main

import gg
import html
import page
import dom
import encoding.base64

$if macos {
	#include "native_document_frame_request_test_darwin.h"
	fn C.vox_test_document_preparation_begin() u64
	fn C.vox_test_document_redraw_generation() u64
	fn C.vox_test_document_preparation_pump() u64
	fn C.vox_test_document_preparation_end()
}

fn test_document_frame_hook_consumes_preparation_and_keeps_later_requests() {
	$if macos {
		owner := page.Page.create(1)!
		mut app := &BrowserApp{page_model:owner,ctx:&gg.Context{native_rendering:true}}
		app.install_document_frame_request_hook()
		mut client := owner.client()
		before := C.vox_test_document_preparation_begin()
		defer { C.vox_test_document_preparation_end() }
		app.begin_frame_preparation()
		client.request_frame()
		assert C.vox_test_document_redraw_generation() == before + 1
		app.finish_frame_preparation()
		C.vox_browser_frame_prepared()
		assert C.vox_test_document_preparation_pump() == before + 1
		client.request_frame()
		assert C.vox_test_document_redraw_generation() == before + 1
		assert C.vox_test_document_preparation_pump() == before + 2
	}
}

fn test_batch_capture_defers_pixels_for_background_resources_without_blocking_ordinary_frames() {
	$if macos {
		mut document := html.parse_document('<!doctype html><p>capture</p>')
		defer { document.finalize() }
		document.update_readiness(.complete)
		mut app := BrowserApp{
			document:document
			ctx:&gg.Context{native_rendering:true}
			screenshot_path:'capture.png'
			background_resource_pending:{'https://capture.test/background.png':true}
		}
		assert app.document_resources_ready_for_capture()
		assert !app.document_pixels_ready_for_frame()
		app.background_resource_pending.clear()
		assert app.document_pixels_ready_for_frame()
		app.background_resource_pending['https://capture.test/background.png'] = true
		app.screenshot_path = ''
		assert app.document_pixels_ready_for_frame()
	}
}

fn test_initial_lazy_image_deferral_wake_is_consumed_by_preparation() {
	$if macos {
		mut document := parse_loaded_browser_navigation_document(LoadedPage{
			url:'about:blank'
			markup:'<!doctype html><img loading="lazy" src="data:image/png;base64,unused">'
		}, dom.url_about_blank(), none, none, none, true)
		mut loader := new_browser_image_request_loader(document, {})
		defer { loader.cancel(); document.finalize() }
		before := C.vox_test_document_preparation_begin()
		defer { C.vox_test_document_preparation_end() }
		install_static_browser_image_fetch_hooks_with_loader(document, {}, loader)
		assert loader.deferred_lazy_images.len == 1
		assert C.vox_test_document_redraw_generation() == before + 1
		C.vox_browser_frame_prepared()
		assert C.vox_test_document_preparation_pump() == before + 1
	}
}

@[heap]
struct PreparedImageCompletion {
mut:
	decoded bool
}

fn test_polled_image_completion_does_not_queue_a_replay_after_its_prepared_frame() {
	$if macos {
		mut document := html.parse_document('<!doctype html><p>image completion</p>')
		defer { document.finalize() }
		mut loader := new_browser_image_request_loader(document, {})
		defer { loader.cancel() }
		mut app := &BrowserApp{document:document,image_request_loader:loader,
			ctx:&gg.Context{native_rendering:true}}
		completed := &PreparedImageCompletion{}
		address := 'https://prepared-image.test/pixel.png'
		key := document.url.serialize() + '\n' + address
		loader.pending[key] = [html.HTMLImageFetchCompletion(fn [completed] (data ?html.DecodedImageData) {
			mut observation := unsafe { &PreparedImageCompletion(completed) }
			observation.decoded = data != none
		})]
		loader.active_fetches = 1
		loader.results <- PreloadedResource{url:address,source_url:document.url.serialize(),
			body:base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=').bytestr()}
		before := C.vox_test_document_preparation_begin()
		defer { C.vox_test_document_preparation_end() }
		app.begin_frame_preparation()
		app.poll_browser_image_requests()
		assert completed.decoded && loader.pending.len == 0
		assert app.paint_commands_pending
		assert C.vox_test_document_redraw_generation() == before + 1
		app.finish_frame_preparation()
		C.vox_browser_frame_prepared()
		assert C.vox_test_document_preparation_pump() == before + 1
	}
}

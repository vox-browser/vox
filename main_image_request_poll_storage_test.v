module main

import dom
import platform

fn test_native_image_request_poll_does_not_allocate_while_waiting_or_idle() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut loader := &BrowserImageRequestLoader{
		document: document
		results:  chan PreloadedResource{cap: 8}
	}
	mut app := &BrowserApp{ document: document, image_request_loader: loader }
	// Outstanding work and a completely idle loader both use the same empty
	// buffered-channel fast path without suppressing readiness bookkeeping.
	for active in [0, 1] {
		loader.active_fetches = active
		app.poll_browser_image_requests()
		before := platform.thread_arena_usage().used
		for _ in 0 .. 1024 { app.poll_browser_image_requests() }
		$if prealloc {
			assert platform.thread_arena_usage().used - before < 1024
		}
	}
}

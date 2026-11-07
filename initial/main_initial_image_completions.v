module main

import os

const disable_initial_image_completions = os.getenv('VOX_DISABLE_INITIAL_IMAGE_COMPLETIONS') != ''
const initial_image_completion_diagnostics = os.getenv('VOX_INITIAL_IMAGE_COMPLETION_DIAGNOSTICS') != ''
const disable_initial_background_completions = os.getenv('VOX_DISABLE_INITIAL_BACKGROUND_COMPLETIONS') != ''
const initial_background_completion_diagnostics = os.getenv('VOX_INITIAL_BACKGROUND_COMPLETION_DIAGNOSTICS') != ''

// Image fetches overlap script/binding setup. Consume only responses already
// buffered on the owning thread, before constructing the first geometry. The
// ordinary completion path retains decoding, events, pending callback replay
// and failures; a slow image still completes on a later frame.
fn (mut app BrowserApp) finish_initial_ready_image_requests() {
	if disable_initial_image_completions || app.document == unsafe { nil }
		|| app.document.layout_root != unsafe { nil } { return }
	loader := app.image_request_loader or { return }
	if voidptr(loader.document) != voidptr(app.document) || loader.results.len == 0 { return }
	ready := loader.results.len
	app.poll_browser_image_requests()
	app.poll_javascript_tasks()
	if initial_image_completion_diagnostics {
		eprintln('VOX_INITIAL_IMAGE_COMPLETIONS ready=${ready}')
	}
}

// Background requests started during style preparation can finish while the
// first geometry is being built. Apply their ordinary completion path before
// recording that frame, rather than recording unavailable images and rebuilding
// its paint commands on the next frame. This never waits for network work.
fn (mut app BrowserApp) finish_initial_ready_background_requests() {
	if disable_initial_background_completions || app.document == unsafe { nil }
		|| app.document_presented || app.frame_preparation_depth == 0
		|| app.document.layout_root == unsafe { nil }
		|| app.background_resource_results.len == 0 { return }
	ready := app.background_resource_results.len
	app.poll_background_resources()
	if initial_background_completion_diagnostics {
		eprintln('VOX_INITIAL_BACKGROUND_COMPLETIONS ready=${ready}')
	}
}

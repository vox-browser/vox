module main

import html
import platform

$if macos {
	fn C.native_wake_browser_during_preparation()
}

// These requests describe inputs which preparation incorporates before replay.
// The native guard retains an ordinary wake outside that phase, including on
// worker threads. Input and resource-delivery notifications keep their own wakes.
fn request_browser_frame_during_preparation() {
	mut event_loop := html.main_thread_event_loop()
	event_loop.request_rendering_update()
	$if macos {
		C.native_wake_browser_during_preparation()
	} $else {
		C.native_wake_browser()
	}
}

fn (app &BrowserApp) request_document_frame() {
	if app.frame_preparation_depth > 0 && app.ctx != unsafe { nil }
		&& app.ctx.native_rendering {
		request_browser_frame_during_preparation()
	} else {
		request_browser_frame()
	}
}

fn (app &BrowserApp) install_document_frame_request_hook() {
	if app.page_model == unsafe { nil } { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut client := app.page_model.client()
	client.set_request_frame_hook(fn [app] () { app.request_document_frame() })
}

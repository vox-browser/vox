module main

import html
import platform

$if macos {
	fn C.native_wake_browser_during_preparation()
}

fn (app &BrowserApp) install_document_frame_request_hook() {
	if app.page_model == unsafe { nil } { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut client := app.page_model.client()
	client.set_request_frame_hook(fn [app] () {
		mut event_loop := html.main_thread_event_loop()
		event_loop.request_rendering_update()
		$if macos {
			if app.frame_preparation_depth > 0 && app.ctx != unsafe { nil }
				&& app.ctx.native_rendering {
				C.native_wake_browser_during_preparation()
				return
			}
		}
		C.native_wake_browser()
	})
}

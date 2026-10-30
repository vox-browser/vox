module main

import html

// Local embedding counterpart of WebContent::PageClient::grant/deliver. It
// receives the native display clock instead of compositor IPC. No author
// callback runs here: the source HTML event loop queues its rendering task.
fn (mut app BrowserApp) deliver_rendering_opportunity(frame_time_ns i64, interval_ms f64) {
	if app.document == unsafe { nil } || app.page_model == unsafe { nil } { return }
	if app.initial_layout_waits_for_fonts() { return }
	mut client := app.page_model.client()
	client.rendering_opportunity(frame_time_ns, interval_ms)
	mut event_loop := html.main_thread_event_loop()
	event_loop.rendering_opportunity(f64(frame_time_ns) / 1.0e6, false)
}

module main

import adblock
import css
import fetch
import http
import json2
import requestserver
import strconv
import platform

fn (app &BrowserApp) document_pixels_ready_for_frame() bool {
	if app.initial_layout_pending { return false }
	$if macos {
		// A batch capture needs the completed viewport. Keep servicing engine
		// tasks and layout while loading, then replay document pixels once ready.
		if app.ctx != unsafe { nil } && app.ctx.native_rendering
			&& app.screenshot_path != '' && !app.screenshot_scheduled
			&& app.document != unsafe { nil } {
			return app.background_resource_pending.len == 0
				&& app.document_resources_ready_for_capture()
		}
	}
	return true
}

// Readiness polling runs outside a frame. Keep waiting load/font promises
// inexpensive; DOM/script/layout changes still request a real rendering update.
fn capture_retry_needs_frame(target voidptr) int {
	mut heap_scope := platform.begin_browser_activity_heap_scope()
	defer { heap_scope.finish() }
	app := unsafe { &BrowserApp(target) }
	if app.screenshot_scheduled || app.screenshot_path == '' { return -1 }
	if app.document == unsafe { nil } || app.pending_navigation != none { return 1 }
	if app.initial_layout_waits_for_fonts() { return 0 }
	if app.paint_commands_pending || app.document.needs_style_update_after_layout()
		|| !app.document.layout_is_up_to_date() || app.javascript_tasks_have_unadopted_paint()
		|| (app.js_runtime != unsafe { nil } && app.js_runtime.has_pending_document_state()) {
		return 1
	}
	return if app.document_resources_ready_for_capture() { 1 } else { 0 }
}

fn install_browser_font_resource_cache() {
	requestserver.install_native_font_response_cache_provider(browser_cached_font_response)
}

fn browser_cached_font_response(request &fetch.Request) ?&fetch.Response {
	destination := request.destination or { return none }
	if request.method != 'GET' || destination != .font
		|| request.current_url().scheme() !in ['http', 'https'] { return none }
	address := request.current_url().serialize()
	path := browser_cache_entry_path(browser_cache_root(), 'resources', address)
	// Old entries lack status or redirect/header provenance. They remain cache
	// misses rather than manufacturing a successful font response.
	status := strconv.atoi(read_browser_cache_entry(path + '.status') or { return none }) or { return none }
	if status < 200 || status >= 300 { return none }
	if (read_browser_cache_entry(path + '.url') or { return none }) != address { return none }
	headers := json2.decode[[]adblock.ResponseHeader](
		read_browser_cache_entry(path + '.headers.json') or { return none }) or { return none }
	body := read_browser_cache_entry(path) or { return none }
	mut response := fetch.Response.create()
	response.status = u16(status)
	response.url_list = request.url_list.clone()
	for header in headers {
		response.header_list.append(http.Header{name:header.name,value:header.value})
	}
	response.set_body_bytes(body.bytes())
	return response
}

fn (app &BrowserApp) font_resources_ready_for_capture() bool {
	if app.document == unsafe { nil } { return false }
	owner := app.document.existing_font_face_set() or { return true }
	if owner.font_face_set_record() == unsafe { nil } { return true }
	fonts := unsafe { &css.FontFaceSet(owner.font_face_set_record()) }
	return fonts.status() == .loaded && fonts.ready_promise.state == .fulfilled
		&& !app.document.anything_is_delaying_the_load_event()
		&& app.document.layout_is_up_to_date() && !app.document.needs_style_update_after_layout()
}

fn (app &BrowserApp) document_resources_ready_for_capture() bool {
	if app.document == unsafe { nil } || app.document.readiness() != .complete { return false }
	// Lazy images do not delay the document's load event. Once proximity has
	// started their requests, the captured viewport still needs their pixels.
	if loader := app.image_request_loader {
		if voidptr(loader.document) == voidptr(app.document) && loader.pending.len > 0 {
			return false
		}
	}
	// Font and load-event delayers can settle before the queued load task
	// advances an interactive document to complete. Capture after that task.
	return app.font_resources_ready_for_capture()
}

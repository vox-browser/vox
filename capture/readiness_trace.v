module main

import css
import os

// Diagnostic: VOX_TRACE_CAPTURE_READINESS=1 reports which condition keeps a
// requested screenshot from being scheduled, each time the blocking reason
// changes. Live pages that never settle otherwise leave no evidence of why
// their capture did not happen.
const trace_capture_readiness = os.getenv('VOX_TRACE_CAPTURE_READINESS') != ''

fn (app &BrowserApp) capture_readiness_blocker(paint_document bool) string {
	if app.document == unsafe { nil } { return 'no document' }
	if app.load_status.starts_with('Loading ') { return 'load status: ${app.load_status}' }
	if app.background_resource_pending.len > 0 {
		mut urls := []string{}
		for url, _ in app.background_resource_pending {
			urls << url
			if urls.len == 4 { break }
		}
		return 'background resources pending: ${app.background_resource_pending.len} ${urls}'
	}
	// The pixel gate (`paint_document`) is the conjunction of the conditions
	// below, so report the specific one before the generic frame result.
	readiness := app.document.readiness()
	if readiness != .complete { return 'document readiness: ${readiness}' }
	if loader := app.image_request_loader {
		if voidptr(loader.document) == voidptr(app.document) && loader.pending.len > 0 {
			return 'image requests pending: ${loader.pending.len}'
		}
	}
	if app.has_resumable_lazy_image_requests() { return 'resumable lazy image requests' }
	if app.document.number_of_things_delaying_the_load_event > 0 {
		return 'load event delayed: ${app.document.number_of_things_delaying_the_load_event} delayers'
	}
	if app.document.anything_is_delaying_the_load_event() { return 'load event delayed by a child navigable' }
	if !app.document.layout_is_up_to_date() { return 'layout not up to date' }
	if app.document.needs_style_update_after_layout() { return 'style update after layout' }
	if !app.font_resources_ready_for_capture() { return 'font resources: ${app.font_capture_status()}' }
	if !paint_document { return 'document not painted this frame' }
	if app.screenshot_initial_viewport_pending() { return 'initial viewport pending' }
	return ''
}

fn (app &BrowserApp) font_capture_status() string {
	owner := app.document.existing_font_face_set() or { return 'no font set' }
	if owner.font_face_set_record() == unsafe { nil } { return 'no font set record' }
	fonts := unsafe { &css.FontFaceSet(owner.font_face_set_record()) }
	return 'status ${fonts.status()} ready ${fonts.ready_promise.state}'
}

fn (mut app BrowserApp) trace_capture_readiness(paint_document bool) {
	if !trace_capture_readiness { return }
	reason := app.capture_readiness_blocker(paint_document)
	if reason == app.capture_readiness_last_reason { return }
	app.capture_readiness_last_reason = reason
	eprintln('Vox capture readiness: ${if reason == '' { 'ready' } else { reason }}')
}

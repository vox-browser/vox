module main

import processmetrics

import html
import css
import dom
import os
import sync.stdatomic
import time

const retain_native_animation_tick = os.getenv('VOX_RETAIN_NATIVE_ANIMATION_TICK') != ''
const animation_clock_diagnostics = os.getenv('VOX_ANIMATION_CLOCK_DIAGNOSTICS') != ''

__global source_animation_clock_reported stdatomic.AtomicVal[bool]

// The local HTML rendering task owns animation timestamps, event delivery and
// their ordering before rAF and layout. A second sample from native drawing
// dirties the style/layout it just produced and advances a different timestamp.
// Check actual page/root identity; standalone documents retain their host clock.
fn (app &BrowserApp) source_rendering_owns_animation_clock() bool {
	if app.document == unsafe { nil } || app.page_model == unsafe { nil }
		|| !app.document.has_page() || !app.page_model.has_local_root_navigable()
		|| voidptr(app.document.page()) != voidptr(app.page_model) {
		return false
	}
	navigable := app.document.navigable() or { return false }
	return voidptr(navigable) == voidptr(app.page_model.local_root_navigable())
}

fn (mut app BrowserApp) advance_document_animations(window_width int, content_viewport_height int) {
	load_instruction_stage := processmetrics.begin_instruction_stage('animation_driver')
	defer { load_instruction_stage.finish() }
	_ = window_width
	_ = content_viewport_height
	if app.document == unsafe { nil } || app.animation_epoch_ns == 0
		|| !css.document_has_running_css_animations(app.document) {
		return
	}
	mut document := unsafe { &dom.Document(app.document) }
	if retain_native_animation_tick || !app.source_rendering_owns_animation_clock() {
		now := time.sys_mono_now()
		elapsed_ms := f64(now - app.animation_epoch_ns) / 1_000_000.0
		document.update_animations_and_send_events(elapsed_ms)
	} else if animation_clock_diagnostics && source_animation_clock_reported.compare_and_swap(false, true) {
		eprintln('Vox animation clock: HTML rendering owns native page tick')
	}
	// Keep the next display grant even when HTML owns sampling. Its rendering
	// task runs through the event loop, independently of native paint preparation.
	$if macos {
		if css.document_has_running_css_animations(document) {
			C.native_wake_browser_after(16)
		}
	}
}

// Local embedding counterpart of WebContent::PageClient::grant/deliver. It
// receives the native display clock instead of compositor IPC. No author
// callback runs here: the source HTML event loop queues its rendering task.
fn (mut app BrowserApp) deliver_rendering_opportunity(frame_time_ns i64, interval_ms f64) {
	load_instruction_stage := processmetrics.begin_instruction_stage('html_rendering_opportunity')
	defer { load_instruction_stage.finish() }
	if app.document == unsafe { nil } || app.page_model == unsafe { nil } { return }
	if app.initial_layout_waits_for_fonts() { return }
	mut client := app.page_model.client()
	client.rendering_opportunity(frame_time_ns, interval_ms)
	mut event_loop := html.main_thread_event_loop()
	event_loop.rendering_opportunity(f64(frame_time_ns) / 1.0e6, false)
}

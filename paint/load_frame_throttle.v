module main

import os
import platform
import time

const disable_load_frame_throttle = os.getenv('VOX_DISABLE_LOAD_RENDER_THROTTLE') != ''
const load_frame_throttle_diagnostics = os.getenv('VOX_LOAD_RENDER_THROTTLE_DIAGNOSTICS') != ''
// While a page hydrates, scripts change the DOM between nearly every frame and
// each frame relays out and repaints it. A frame below this cost is not
// throttled; one above it waits until the main thread has had several times
// its cost for scripts and network callbacks, as Chromium stops starting main
// frames faster than a busy main thread can service them.
const load_frame_throttle_min_cost_ns = 20 * time.millisecond
const load_frame_throttle_cost_ratio = 3
const load_frame_throttle_max_gap_ns = 500 * time.millisecond
// Only the loading phase after a document's first paint, without recent input:
// scrolling, typing and animation keep their normal frame cadence.
const load_frame_throttle_window_ns = 10 * time.second
const load_frame_throttle_input_quiet_ns = time.second

struct LoadFrameThrottle {
mut:
	generation      int = -1
	presented_ns    i64
	last_end_ns     i64
	last_cost_ns    i64
	last_input_ns   i64
	timer           &platform.Timer = unsafe { nil }
	deferred_frames int
}

// The deadline for this document's next frame, or 0 when it may render now.
fn (state &LoadFrameThrottle) deadline(now i64, generation int) i64 {
	if state.generation != generation || state.last_end_ns == 0 { return 0 }
	if now - state.presented_ns > load_frame_throttle_window_ns { return 0 }
	if state.last_input_ns != 0 && now - state.last_input_ns < load_frame_throttle_input_quiet_ns {
		return 0
	}
	if state.last_cost_ns < load_frame_throttle_min_cost_ns { return 0 }
	mut gap := state.last_cost_ns * load_frame_throttle_cost_ratio
	if gap > load_frame_throttle_max_gap_ns { gap = load_frame_throttle_max_gap_ns }
	due := state.last_end_ns + gap
	return if now >= due { 0 } else { due }
}

// Skips this frame when the loading document rendered too recently, and asks
// for a frame at the deadline. Scripts, timers and network callbacks keep
// running from the event loop in the meantime.
fn (mut app BrowserApp) defer_loading_frame(now i64) bool {
	if disable_load_frame_throttle || app.document == unsafe { nil } || !app.document_presented {
		return false
	}
	due := app.load_frames.deadline(now, app.navigation_generation)
	if due == 0 { return false }
	mut state := &app.load_frames
	if state.timer == unsafe { nil } {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		state.timer = platform.Timer.create_single_shot(0, fn () {
			request_browser_frame()
		})
	}
	interval := int((due - now + time.millisecond - 1) / time.millisecond)
	state.timer.restart_with_interval(if interval < 1 { 1 } else { interval })
	state.deferred_frames++
	return true
}

// Records a rendered frame's cost. The first presented frame of a navigation
// starts its loading window.
fn (mut app BrowserApp) finish_loading_frame(start i64) {
	if app.document == unsafe { nil } || !app.document_presented { return }
	now := time.sys_mono_now()
	mut state := &app.load_frames
	if state.generation != app.navigation_generation {
		state.generation = app.navigation_generation
		state.presented_ns = now
		state.deferred_frames = 0
	}
	// An unchanged frame costs almost nothing; keep measuring from the last
	// frame that actually relaid out or repainted.
	cost := now - start
	if cost < load_frame_throttle_min_cost_ns { return }
	state.last_end_ns = now
	state.last_cost_ns = cost
	if load_frame_throttle_diagnostics {
		eprintln('VOX_LOAD_RENDER_THROTTLE t_ms=${(now - state.presented_ns) / time.millisecond} cost_ms=${state.last_cost_ns / time.millisecond} deferred=${state.deferred_frames}')
	}
}

fn (mut app BrowserApp) note_page_input() {
	app.load_frames.last_input_ns = time.sys_mono_now()
}

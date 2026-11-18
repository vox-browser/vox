module main

import browsernet
import os
import platform
import requestserver
import time

const disable_load_frame_throttle = os.getenv('VOX_DISABLE_LOAD_RENDER_THROTTLE') != ''
const load_frame_throttle_diagnostics = os.getenv('VOX_LOAD_RENDER_THROTTLE_DIAGNOSTICS') != ''
// While a page hydrates, scripts change the DOM between nearly every frame and
// each frame relays out and repaints it. A frame below this cost is not
// throttled; one above it waits until the main thread has had several times
// its cost for scripts and network callbacks, as Chromium stops starting main
// frames faster than a busy main thread can service them.
const load_frame_throttle_min_cost_ns = 20 * time.millisecond
// VOX_LOAD_RENDER_THROTTLE_RATIO and VOX_LOAD_RENDER_THROTTLE_MAX_GAP_MS
// override the defaults for measurements.
const load_frame_throttle_cost_ratio = i64(os.getenv_opt('VOX_LOAD_RENDER_THROTTLE_RATIO') or { '3' }.int())
const load_frame_throttle_max_gap_ns = i64(os.getenv_opt('VOX_LOAD_RENDER_THROTTLE_MAX_GAP_MS') or {
	'500'
}.int()) * time.millisecond
// Only the loading phase after a document's first paint, without recent input:
// scrolling, typing and animation keep their normal frame cadence.
const load_frame_throttle_window_ns = 10 * time.second
const load_frame_throttle_input_quiet_ns = time.second
// The wait reserves main-thread time for scripts and network callbacks. Once
// no transfer is in flight and the main thread has stayed idle for this long,
// nothing is left to use the reservation and the deferred frame only shows
// what has already arrived. VOX_LOAD_RENDER_QUIET_MS overrides the window for
// measurements; VOX_DISABLE_LOAD_RENDER_QUIET_RELEASE=1 always waits out the
// whole gap.
const disable_load_frame_quiet_release = os.getenv('VOX_DISABLE_LOAD_RENDER_QUIET_RELEASE') != ''
const load_frame_quiet_window_ns = i64(os.getenv_opt('VOX_LOAD_RENDER_QUIET_MS') or { '50' }.int()) * time.millisecond
// Main-thread CPU time that still counts as idle within one quiet window:
// timer ticks and the deferred frame checks themselves, not a script task.
const load_frame_quiet_cpu_budget_ns = load_frame_quiet_window_ns / 5

struct LoadFrameThrottle {
mut:
	generation      int = -1
	presented_ns    i64
	last_end_ns     i64
	last_cost_ns    i64
	last_input_ns   i64
	timer           &platform.Timer = unsafe { nil }
	deferred_frames int
	// The start of the current quiet streak and the main thread's CPU time
	// then; a busy main thread or a transfer in flight starts it again.
	quiet_start_ns i64
	quiet_cpu_ns   i64
	quiet_releases int
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

// Whether a deferred frame may run before its deadline: no transfer has been
// in flight and the main thread has used almost no CPU time for a whole quiet
// window. `cpu_ns` is the main thread's CPU time, negative where the platform
// has no thread clock. A script that waits for the network keeps a transfer
// in flight, and one that runs from tasks or timers keeps the thread busy, so
// a hydrating page keeps the full gap.
fn (mut state LoadFrameThrottle) quiet(now i64, cpu_ns i64, transfers_in_flight bool) bool {
	if disable_load_frame_quiet_release || load_frame_quiet_window_ns <= 0 || cpu_ns < 0 {
		return false
	}
	used := cpu_ns - state.quiet_cpu_ns
	if state.quiet_start_ns == 0 || transfers_in_flight || now < state.quiet_start_ns
		|| used < 0 || used > load_frame_quiet_cpu_budget_ns {
		state.quiet_start_ns = now
		state.quiet_cpu_ns = cpu_ns
		return false
	}
	return now - state.quiet_start_ns >= load_frame_quiet_window_ns
}

// How long a deferred frame waits before its next check: until its deadline,
// or until the current quiet streak can complete.
fn (state &LoadFrameThrottle) wait(now i64, due i64) i64 {
	mut wait := due - now
	if !disable_load_frame_quiet_release && load_frame_quiet_window_ns > 0
		&& state.quiet_start_ns != 0 {
		streak := state.quiet_start_ns + load_frame_quiet_window_ns - now
		if streak < wait { wait = streak }
	}
	return if wait < time.millisecond { i64(time.millisecond) } else { wait }
}

// Fetch workers and Fetch transfers of every document. A finished transfer
// whose result waits for this frame no longer counts.
fn load_transfers_in_flight() bool {
	return browsernet.requests_in_flight() > 0 || requestserver.transfers_in_flight() > 0
}

// Skips this frame when the loading document rendered too recently, and asks
// for a frame at the deadline or when the page may have gone quiet. Scripts,
// timers and network callbacks keep running from the event loop in the
// meantime.
fn (mut app BrowserApp) defer_loading_frame(now i64) bool {
	if disable_load_frame_throttle || app.document == unsafe { nil } || !app.document_presented {
		return false
	}
	due := app.load_frames.deadline(now, app.navigation_generation)
	if due == 0 { return false }
	mut state := &app.load_frames
	if state.quiet(now, platform.thread_cpu_time_ns(), load_transfers_in_flight()) {
		state.quiet_releases++
		return false
	}
	if state.timer == unsafe { nil } {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		state.timer = platform.Timer.create_single_shot(0, fn () {
			request_browser_frame()
		})
	}
	interval := int((state.wait(now, due) + time.millisecond - 1) / time.millisecond)
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
		state.quiet_releases = 0
	}
	// An unchanged frame costs almost nothing; keep measuring from the last
	// frame that actually relaid out or repainted.
	cost := now - start
	if cost < load_frame_throttle_min_cost_ns { return }
	state.last_end_ns = now
	state.last_cost_ns = cost
	// The frame's own work is not script activity: a quiet streak starts here.
	state.quiet_start_ns = now
	state.quiet_cpu_ns = platform.thread_cpu_time_ns()
	if load_frame_throttle_diagnostics {
		eprintln('VOX_LOAD_RENDER_THROTTLE t_ms=${(now - state.presented_ns) / time.millisecond} cost_ms=${state.last_cost_ns / time.millisecond} deferred=${state.deferred_frames} quiet=${state.quiet_releases}')
	}
}

fn (mut app BrowserApp) note_page_input() {
	app.load_frames.last_input_ns = time.sys_mono_now()
}

module main

import os
import processmetrics
import time
import gg
import platform

$if gcboehm ? {
	#include "@DIR/platform/boehm_gc.h"

	fn C.GC_get_gc_no() usize
}

fn scroll_profile_collections() u64 {
	$if gcboehm ? {
		return u64(C.GC_get_gc_no())
	}
	return 0
}

// Opt-in, repeatable wheel delivery through the native shell. Timing starts
// after loading has settled and ends after native replay in the frame callback.
// Cocoa layer publication and display-clock waits are outside this scope.
// No page script is injected.
struct BrowserScrollProfile {
mut:
	enabled        bool
	settled_at     u64
	frame          int
	frames         int = 120
	settle_ns      u64 = 1_000_000_000
	active         bool
	started        u64
	wheel_finished u64
	prepared       u64
	instructions   processmetrics.InstructionSnapshot
	start_y        f64
	allocated      u64
	collections    u64
	idle           bool
	arena_start    i64
	phase_count    int
	phase_names    [24]string
	phase_used     [24]i64
	replay_kinds      bool
	replay_kind_bytes map[string]i64
}

// scroll_profile_allocated returns bytes allocated so far by this thread: the
// collector's running total, or the main thread's arena use under -prealloc.
fn scroll_profile_allocated() u64 {
	$if prealloc {
		return u64(platform.thread_arena_usage().used)
	}
	return u64(gc_heap_usage().total_bytes)
}

fn (mut app BrowserApp) scroll_profile_mark(name string) {
	mut profile := &app.scroll_profile
	if !profile.active || profile.phase_count >= profile.phase_names.len { return }
	profile.phase_names[profile.phase_count] = name
	profile.phase_used[profile.phase_count] = i64(scroll_profile_allocated())
	profile.phase_count++
}

fn (mut app BrowserApp) begin_scroll_profile_frame() {
	mut profile := &app.scroll_profile
	if !profile.enabled { return }
	if app.document == unsafe { nil } || !app.document_presented
		|| app.pending_navigation != none || app.background_resource_pending.len > 0 {
		profile.settled_at = 0
		return
	}
	now := time.sys_mono_now()
	if profile.settled_at == 0 {
		profile.settled_at = now
		return
	}
	if now - profile.settled_at < profile.settle_ns { return }
	if !profile.idle && app.maximum_scroll(app.viewport_height + app.chrome_height()) <= 0 {
		eprintln('Vox scroll profile: document has no scrollable overflow')
		exit(1)
	}
	profile.active = true
	profile.started = time.sys_mono_now()
	profile.instructions = processmetrics.instruction_snapshot()
	profile.start_y = app.scroll_y
	profile.allocated = scroll_profile_allocated()
	profile.collections = scroll_profile_collections()
	profile.phase_count = 0
	if profile.idle {
		profile.wheel_finished = time.sys_mono_now()
		return
	}
	// Traverse down then back up, including the scroll boundaries. Feed the
	// same GG event entry point used by physical wheel input.
	direction := if (profile.frame / 30) % 2 == 0 { f32(-1) } else { f32(1) }
	app.handle_event(&gg.Event{
		typ:           .mouse_scroll
		mouse_x:       f32(app.viewport_width) / 2
		mouse_y:       app.page_top() + f32(app.viewport_height) / 2
		scroll_y:      direction
		window_height: app.viewport_height + app.chrome_height()
	})
	profile.wheel_finished = time.sys_mono_now()
}

fn (mut app BrowserApp) scroll_profile_prepared() {
	if app.scroll_profile.active { app.scroll_profile.prepared = time.sys_mono_now() }
}

fn (mut app BrowserApp) finish_scroll_profile_frame() {
	mut profile := &app.scroll_profile
	if !profile.active { return }
	finished := time.sys_mono_now()
	reading := processmetrics.instruction_snapshot()
	count := reading.since(profile.instructions) or { u64(0) }
	heap := gc_heap_usage()
	allocated_kb := (scroll_profile_allocated() - profile.allocated) / 1024
	mut phases := []string{}
	mut previous_used := i64(profile.allocated)
	for index in 0 .. profile.phase_count {
		phases << '${profile.phase_names[index]}:${(profile.phase_used[index] - previous_used) / 1024}'
		previous_used = profile.phase_used[index]
	}
	arena := platform.thread_arena_usage()
	collections := scroll_profile_collections() - profile.collections
	eprintln('Vox scroll frame: ${profile.frame} wheel_us=${(profile.wheel_finished - profile.started) / 1000} prepare_us=${(profile.prepared - profile.wheel_finished) / 1000} replay_us=${(finished - profile.prepared) / 1000} total_us=${(finished - profile.started) / 1000} instructions=${count} before_y=${profile.start_y} after_y=${app.scroll_y} commands=${app.paint_commands.len} allocated_kb=${allocated_kb} collections=${collections} heap_mb=${heap.heap_size / (1024 * 1024)} arena_mb=${arena.used / (1024 * 1024)} arena_blocks=${arena.blocks} phases=${phases.join(',')}')
	C.fflush(C.stderr)
	profile.frame++
	profile.active = false
	if profile.frame >= profile.frames {
		if profile.replay_kinds {
			for kind, bytes in profile.replay_kind_bytes {
				eprintln('Vox replay kind: ${kind} kb_per_frame=${f64(bytes) / 1024.0 / f64(profile.frames)}')
			}
		}
		if app.screenshot_path != '' {
			app.screenshot_scheduled = true
			schedule_native_screenshot(app.screenshot_path)
			profile.enabled = false
		} else {
			exit(0)
		}
	}
}

fn scroll_profile_from_environment() BrowserScrollProfile {
	return BrowserScrollProfile{
		enabled: os.getenv('VOX_PROFILE_SCROLL') == '1'
		idle:    os.getenv('VOX_SCROLL_PROFILE_IDLE') == '1'
		replay_kinds: os.getenv('VOX_SCROLL_PROFILE_REPLAY_KINDS') == '1'
		frames:  if os.getenv('VOX_SCROLL_PROFILE_FRAMES').int() > 0 {
			os.getenv('VOX_SCROLL_PROFILE_FRAMES').int()
		} else {
			120
		}
		settle_ns: if os.getenv('VOX_SCROLL_PROFILE_SETTLE_MS').int() > 0 {
			u64(os.getenv('VOX_SCROLL_PROFILE_SETTLE_MS').int()) * 1_000_000
		} else {
			1_000_000_000
		}
	}
}

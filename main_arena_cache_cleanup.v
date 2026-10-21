module main

import platform
import time

fn (mut app BrowserApp) arm_arena_cache_cleanup() {
	$if prealloc {
		if app.memory_maintenance.cleanup_timer == unsafe { nil } {
			owner := voidptr(&app)
			app.memory_maintenance.cleanup_timer = platform.Timer.create_single_shot(500, fn [owner] () {
				mut browser := unsafe { &BrowserApp(owner) }
				browser.release_unused_arena_caches_if_idle(time.sys_mono_now())
				if browser.memory_maintenance.has_pending_cleanup(0) {
					browser.arm_arena_cache_cleanup()
				}
			})
		}
		app.memory_maintenance.cleanup_timer.restart_with_interval(500)
	}
}

fn (mut app BrowserApp) release_unused_arena_caches_if_idle(now_ns i64) {
	$if prealloc {
		if !app.uses_static_native_memory_policy() || app.pending_navigation != none
			|| app.has_navigation_fetch_in_flight() || app.pending_page_preload != none
			|| app.background_resource_pending.len > 0 || app.frame_preparation_depth > 0
			|| app.navigation_work_depth > 0 || app.document.readiness() != .complete {
			return
		}
		if app.memory_maintenance.cleanup_due(now_ns, 0) {
			// Only caches with their own recyclable storage can release memory
			// here. Dropping pointers into document arenas would just orphan it.
			platform.release_unused_text_shaping()
		}
	}
}

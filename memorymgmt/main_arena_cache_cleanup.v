module main

import os

$if prealloc {
	import platform
	import time
	import layout
}

const keep_scripted_layout_pages = os.getenv('VOX_KEEP_SCRIPTED_LAYOUT_PAGES') != ''

fn (mut app BrowserApp) arm_arena_cache_cleanup() {
	$if prealloc {
		if app.memory_maintenance.cleanup_timer == unsafe { nil } {
			// This app timer is reused across navigations, including when its
			// first registration happens inside the old document's frame.
			persistent := platform.enter_persistent()
			owner := voidptr(&app)
			app.memory_maintenance.cleanup_timer = platform.Timer.create_single_shot(500, fn [owner] () {
				mut browser := unsafe { &BrowserApp(owner) }
				browser.release_unused_arena_caches_if_idle(time.sys_mono_now())
				if browser.memory_maintenance.has_pending_cleanup(0) {
					browser.arm_arena_cache_cleanup()
				}
			})
			platform.leave_persistent(persistent)
		}
		app.memory_maintenance.cleanup_timer.restart_with_interval(500)
	}
}

fn (app &BrowserApp) uses_native_arena_memory_policy() bool {
	return app.ctx != unsafe { nil } && app.ctx.native_rendering
		&& app.document != unsafe { nil }
}

fn (mut app BrowserApp) release_unused_arena_caches_if_idle(now_ns i64) {
	$if prealloc {
		if !app.uses_native_arena_memory_policy() || app.pending_navigation != none
			|| app.has_navigation_fetch_in_flight() || app.pending_page_preload != none
			|| app.background_resource_pending.len > 0 || app.frame_preparation_depth > 0
			|| app.navigation_work_depth > 0 || app.document.readiness() != .complete {
			return
		}
		if app.memory_maintenance.cleanup_due(now_ns, 0) {
			// Only caches with their own recyclable storage can release memory
			// here. Dropping pointers into document arenas would just orphan it.
			// This trim preserves every live allocation and only decommits empty
			// spares or unused suffix pages, including on scripted documents.
			if !keep_scripted_layout_pages || app.uses_static_native_memory_policy() {
				layout.trim_unused_layout_pages(app.paint_display_list)
			}
			if app.uses_static_native_memory_policy() {
				platform.release_unused_text_shaping()
			}
			if app.native_replay_scratch != unsafe { nil } {
				app.native_replay_scratch.trim_empty_pages()
			}
			// Scripted documents also leave recycled transport/replay pages
			// behind. These pages contain no live allocations, independently
			// of the DOM, JavaScript runtime or retained shaping caches.
			platform.release_unused_browser_memory()
		}
	}
}

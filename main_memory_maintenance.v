module main

import platform
import time
import adblock
import css
import layout

__global browser_filter_cleanup_timer &platform.Timer

fn arm_filter_memory_cleanup() {
	if browser_filter_cleanup_timer != unsafe { nil } { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut timer := platform.Timer.create_repeating(1000, fn () {
		adblock.release_default_engine_if_idle(5000)
	})
	browser_filter_cleanup_timer = timer
	timer.start()
}

struct BrowserMemoryMaintenance {
mut:
	last_document_activity_ns i64
	next_check_ns            i64
	last_cleanup_allocated   uint
	pending_document_work    bool
	presentation_pending     bool
	cleanup_timer           &platform.Timer = unsafe { nil }
}

fn (mut maintenance BrowserMemoryMaintenance) document_changed(now_ns i64) {
	maintenance.last_document_activity_ns = now_ns
	maintenance.pending_document_work = true
	maintenance.presentation_pending = true
}

fn (mut maintenance BrowserMemoryMaintenance) frame_finished(now_ns i64, updated_document_paint bool) {
	// A slow recording or native replay is active document work throughout the
	// frame. Start its idle interval only after the completed frame is presented.
	if updated_document_paint || maintenance.presentation_pending {
		maintenance.document_changed(now_ns)
		maintenance.presentation_pending = false
	}
}

fn (mut maintenance BrowserMemoryMaintenance) cleanup_due(now_ns i64, allocated uint) bool {
	if now_ns < maintenance.next_check_ns {
		return false
	}
	maintenance.next_check_ns = now_ns + i64(time.second)
	if now_ns < maintenance.last_document_activity_ns
		|| now_ns - maintenance.last_document_activity_ns < 500_000_000 {
		return false
	}
	if !maintenance.has_pending_cleanup(allocated) {
		return false
	}
	maintenance.pending_document_work = false
	maintenance.last_cleanup_allocated = allocated
	return true
}

fn (maintenance &BrowserMemoryMaintenance) has_pending_cleanup(allocated uint) bool {
	return maintenance.pending_document_work
		|| (allocated >= maintenance.last_cleanup_allocated
			&& allocated - maintenance.last_cleanup_allocated >= uint(32) * 1024 * 1024)
}

fn (mut app BrowserApp) finish_frame_memory_activity(now_ns i64, previous_paint u64) {
	if app.document == unsafe { nil } { return }
	arm_filter_memory_cleanup()
	// Installation may build the display list before the native frame begins.
	// Its first replay is still document work even when its revision is stable.
	updated_document := app.memory_maintenance.presentation_pending || !app.document_presented
		|| previous_paint != app.paint_generation
	app.memory_maintenance.frame_finished(now_ns, updated_document)
	app.schedule_static_graphics_cleanup()
	$if prealloc {
		if app.uses_native_arena_memory_policy()
			&& app.memory_maintenance.has_pending_cleanup(0)
			&& (updated_document || app.memory_maintenance.cleanup_timer == unsafe { nil }
				|| !app.memory_maintenance.cleanup_timer.is_active()) {
			app.arm_arena_cache_cleanup()
		}
	}
	$if gcboehm ? {
		if app.ctx != unsafe { nil }
			&& app.memory_maintenance.has_pending_cleanup(gc_heap_usage().total_bytes)
			&& (updated_document || app.memory_maintenance.cleanup_timer == unsafe { nil }
				|| !app.memory_maintenance.cleanup_timer.is_active()) {
			// Chrome can replay an unchanged document every frame. Preserve the
			// existing idle deadline until new document input is presented.
			app.arm_idle_memory_cleanup()
		}
	}
}

fn (mut app BrowserApp) arm_idle_memory_cleanup() {
	$if gcboehm ? {
		if app.memory_maintenance.cleanup_timer == unsafe { nil } {
			owner := voidptr(&app)
			app.memory_maintenance.cleanup_timer = platform.Timer.create_single_shot(500, fn [owner] () {
				mut browser := unsafe { &BrowserApp(owner) }
				browser.release_unused_memory_if_idle(time.sys_mono_now())
				if browser.memory_maintenance.has_pending_cleanup(gc_heap_usage().total_bytes) {
					browser.arm_idle_memory_cleanup()
				}
			})
		}
		app.memory_maintenance.cleanup_timer.restart_with_interval(500)
	}
}

fn (mut app BrowserApp) release_unused_memory_if_idle(now_ns i64) {
	$if gcboehm ? {
		if app.document == unsafe { nil } || app.pending_navigation != none
			|| app.has_navigation_fetch_in_flight() || app.pending_page_preload != none
			|| app.background_resource_pending.len > 0 || app.frame_preparation_depth > 0
			|| app.navigation_work_depth > 0 || app.document.readiness() != .complete {
			return
		}
		usage := gc_heap_usage()
		if app.memory_maintenance.has_pending_cleanup(usage.total_bytes)
			&& app.defer_memory_cleanup_to_native_idle() { return }
		if app.memory_maintenance.cleanup_due(now_ns, usage.total_bytes) {
			// Static pages retain their installed cosmetic rules, but need no
			// filter VM between requests. A later request restores the full
			// default engine under its own lock.
			if !app.document.as_node().is_scripting_enabled()
				&& app.js_runtime == unsafe { nil } {
				layout.release_unused_display_list_caches(app.paint_display_list)
				css.release_unused_stylesheet_syntax()
				platform.release_unused_text_shaping()
				adblock.release_unused_engine()
			}
			platform.release_unused_browser_memory()
		}
	}
}

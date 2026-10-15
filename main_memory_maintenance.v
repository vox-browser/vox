module main

import platform
import time

struct BrowserMemoryMaintenance {
mut:
	last_document_activity_ns i64
	next_check_ns            i64
	last_cleanup_allocated   usize
	pending_document_work    bool
}

fn (mut maintenance BrowserMemoryMaintenance) document_changed(now_ns i64) {
	maintenance.last_document_activity_ns = now_ns
	maintenance.pending_document_work = true
}

fn (mut maintenance BrowserMemoryMaintenance) cleanup_due(now_ns i64, allocated usize) bool {
	if now_ns < maintenance.next_check_ns {
		return false
	}
	maintenance.next_check_ns = now_ns + i64(time.second)
	if now_ns - maintenance.last_document_activity_ns < 500_000_000 {
		return false
	}
	if !maintenance.pending_document_work
		&& allocated - maintenance.last_cleanup_allocated < usize(32) * 1024 * 1024 {
		return false
	}
	maintenance.pending_document_work = false
	maintenance.last_cleanup_allocated = allocated
	return true
}

fn (mut app BrowserApp) release_unused_memory_if_idle(now_ns i64) {
	$if gcboehm ? {
		if app.document == unsafe { nil } || app.pending_navigation != none
			|| app.background_resource_pending.len > 0 || app.frame_preparation_depth > 0 {
			return
		}
		usage := gc_heap_usage()
		if app.memory_maintenance.cleanup_due(now_ns, usage.total_bytes) {
			platform.release_unused_browser_memory()
		}
	}
}

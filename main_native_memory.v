module main

import time

$if macos {
	fn C.native_dispatch_browser_memory_cleanup(owner voidptr, callback fn (voidptr))
	fn C.native_schedule_static_graphics_cleanup()
	fn C.native_schedule_idle_graphics_cleanup()
}

// The host queue holds an opaque pointer. Keep its app alive until delivery;
// the callback removes this root after completing or rescheduling its work.
__global native_memory_cleanup_owners_ []&BrowserApp
__global native_memory_cleanup_current_owner_ voidptr

fn (app &BrowserApp) uses_static_native_memory_policy() bool {
	return app.ctx != unsafe { nil } && app.ctx.native_rendering
		&& app.document != unsafe { nil } && !app.document.as_node().is_scripting_enabled()
		&& app.js_runtime == unsafe { nil }
}

fn (app &BrowserApp) schedule_static_graphics_cleanup() {
	$if macos {
		if app.ctx != unsafe { nil } && app.ctx.native_rendering {
			C.native_schedule_idle_graphics_cleanup()
		}
		if app.uses_static_native_memory_policy() {
			C.native_schedule_static_graphics_cleanup()
		}
	}
}

fn (mut app BrowserApp) defer_memory_cleanup_to_native_idle() bool {
	$if macos {
		owner := voidptr(&app)
		if !app.uses_static_native_memory_policy() || native_memory_cleanup_current_owner_ == owner {
			return false
		}
		for pending in native_memory_cleanup_owners_ {
			if voidptr(pending) == owner { return true }
		}
		native_memory_cleanup_owners_ << &app
		C.native_dispatch_browser_memory_cleanup(owner, native_idle_memory_cleanup_callback)
		return true
	}
	return false
}

fn native_idle_memory_cleanup_callback(owner voidptr) {
	mut browser := unsafe { &BrowserApp(nil) }
	for app in native_memory_cleanup_owners_ {
		if voidptr(app) == owner { browser = app; break }
	}
	if browser == unsafe { nil } { return }
	previous_owner := native_memory_cleanup_current_owner_
	defer {
		native_memory_cleanup_current_owner_ = previous_owner
		remove_native_memory_cleanup_owner(owner)
	}
	native_memory_cleanup_current_owner_ = owner
	browser.release_unused_memory_if_idle(time.sys_mono_now())
	if browser.memory_maintenance.has_pending_cleanup(gc_heap_usage().total_bytes) {
		browser.arm_idle_memory_cleanup()
	}
}

fn remove_native_memory_cleanup_owner(owner voidptr) {
	for index, app in native_memory_cleanup_owners_ {
		if voidptr(app) == owner {
			native_memory_cleanup_owners_.delete(index)
			return
		}
	}
}

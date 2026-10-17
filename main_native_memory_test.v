module main

import browserjs
import dom
import gg
import platform
import time

#include "main_native_memory_test.h"

fn C.native_memory_test_reset()
fn C.native_memory_test_deliver(owner voidptr) int
fn C.native_memory_test_pending_count() int
fn C.native_memory_test_dispatch_count() int
fn C.native_memory_test_graphics_count() int
fn C.native_memory_test_unused_slot_is_clear(data voidptr, length int, capacity int) int

fn native_memory_test_begin() {
	assert native_memory_cleanup_owners_.len == 0
	assert native_memory_cleanup_current_owner_ == unsafe { nil }
	$if native_memory_cleanup_stub ? {
		C.native_memory_test_reset()
	}
}

fn native_memory_test_app(scripting_enabled bool) &BrowserApp {
	mut document := parse_browser_navigation_document_with_scripting('<!doctype html><p id="kept">retained app and document</p>',
		dom.url_about_blank(), none, none, none, 0, scripting_enabled)
	document.update_readiness(.complete)
	mut app := &BrowserApp{
		ctx:      &gg.Context{ native_rendering: true }
		document: document
	}
	app.memory_maintenance.document_changed(i64(time.sys_mono_now()) - 2_000_000_000)
	app.memory_maintenance.last_cleanup_allocated = gc_heap_usage().total_bytes
	return app
}

fn native_memory_test_deliver(mut app BrowserApp) {
	$if native_memory_cleanup_stub ? {
		assert C.native_memory_test_deliver(voidptr(&app)) == 1
	} $else {
		// No run-loop pumping is needed: later queued native deliveries see an
		// unknown owner and return without dereferencing a released app.
		native_idle_memory_cleanup_callback(voidptr(&app))
	}
}

fn native_memory_test_finish(mut app BrowserApp) {
	if app.js_runtime != unsafe { nil } { app.js_runtime.close() }
	remove_native_memory_cleanup_owner(voidptr(&app))
	if app.memory_maintenance.cleanup_timer != unsafe { nil } {
		app.memory_maintenance.cleanup_timer.stop()
	}
	mut document := app.document
	document.finalize()
}

fn native_memory_test_enqueue_without_a_caller_reference() {
	mut app := native_memory_test_app(false)
	assert app.defer_memory_cleanup_to_native_idle()
}

fn test_native_idle_cleanup_keeps_the_app_after_its_callers_frame_returns() {
	$if !macos {
		return
	}
	native_memory_test_begin()
	native_memory_test_enqueue_without_a_caller_reference()
	assert native_memory_cleanup_owners_.len == 1
	// The caller has no App reference. The host stub stores an encoded opaque
	// owner, while the typed pending-owner array retains the live app/document.
	platform.release_unused_browser_memory()
	mut app := native_memory_cleanup_owners_[0]
	defer { native_memory_test_finish(mut app) }
	assert app.document.get_element_by_id('kept')?.text_content() or { '' } == 'retained app and document'
	native_memory_test_deliver(mut app)
	assert native_memory_cleanup_owners_.len == 0
	assert C.native_memory_test_unused_slot_is_clear(native_memory_cleanup_owners_.data,
		native_memory_cleanup_owners_.len, native_memory_cleanup_owners_.cap) == 1
}

fn test_native_idle_cleanup_coalesces_and_roots_the_live_app_until_callback() {
	$if !macos {
		return
	}
	native_memory_test_begin()
	mut app := native_memory_test_app(false)
	defer { native_memory_test_finish(mut app) }
	assert app.defer_memory_cleanup_to_native_idle()
	assert app.defer_memory_cleanup_to_native_idle()
	assert native_memory_cleanup_owners_.len == 1
	assert native_memory_cleanup_owners_[0] == app
	$if native_memory_cleanup_stub ? {
		assert C.native_memory_test_dispatch_count() == 1
		assert C.native_memory_test_pending_count() == 1
	}
	// Registration holds the typed app/document root while the host queue owns
	// only an opaque pointer. A collection must preserve its live document.
	platform.release_unused_browser_memory()
	assert native_memory_cleanup_owners_[0].document.get_element_by_id('kept')?.text_content() or { '' } == 'retained app and document'
	native_memory_test_deliver(mut app)
	assert native_memory_cleanup_owners_.len == 0
	assert C.native_memory_test_unused_slot_is_clear(native_memory_cleanup_owners_.data,
		native_memory_cleanup_owners_.len, native_memory_cleanup_owners_.cap) == 1
	assert native_memory_cleanup_current_owner_ == unsafe { nil }
	$if gcboehm ? {
		assert !app.memory_maintenance.pending_document_work
	} $else {
		assert app.memory_maintenance.pending_document_work
	}
	$if native_memory_cleanup_stub ? {
		assert C.native_memory_test_dispatch_count() == 1
		assert C.native_memory_test_pending_count() == 0
	}
}

fn test_native_idle_cleanup_rechecks_busy_navigation_resources_and_document_readiness() {
	$if !macos {
		return
	}
	native_memory_test_begin()
	for busy in 0 .. 5 {
		mut app := native_memory_test_app(false)
		assert app.defer_memory_cleanup_to_native_idle()
		if busy == 0 { app.pending_navigation = PendingNavigation{ resolved: 'about:blank' } }
		if busy == 1 { app.background_resource_pending['https://example.com/pending.png'] = true }
		if busy == 2 { app.navigation_work_depth = 1 }
		if busy == 3 { app.frame_preparation_depth = 1 }
		if busy == 4 { app.document.update_readiness(.loading) }
		native_memory_test_deliver(mut app)
		assert native_memory_cleanup_owners_.len == 0
		assert native_memory_cleanup_current_owner_ == unsafe { nil }
		assert app.memory_maintenance.pending_document_work
		assert app.memory_maintenance.next_check_ns == 0
		$if gcboehm ? {
			assert app.memory_maintenance.cleanup_timer.is_active()
		}
		$if !gcboehm ? {
			assert app.memory_maintenance.cleanup_timer == unsafe { nil }
		}
		app.pending_navigation = none
		app.background_resource_pending.clear()
		app.navigation_work_depth = 0
		app.frame_preparation_depth = 0
		app.document.update_readiness(.complete)
		assert app.defer_memory_cleanup_to_native_idle()
		native_memory_test_deliver(mut app)
		$if gcboehm ? {
			assert !app.memory_maintenance.pending_document_work
		}
		$if !gcboehm ? {
			assert app.memory_maintenance.pending_document_work
		}
		assert native_memory_cleanup_owners_.len == 0
		native_memory_test_finish(mut app)
	}
	$if native_memory_cleanup_stub ? {
		assert C.native_memory_test_dispatch_count() == 10
		assert C.native_memory_test_pending_count() == 0
	}
}

fn test_native_idle_cleanup_preserves_another_owner_and_restores_reentrant_marker() {
	$if !macos {
		return
	}
	native_memory_test_begin()
	mut first := native_memory_test_app(false)
	mut second := native_memory_test_app(false)
	defer {
		native_memory_cleanup_current_owner_ = unsafe { nil }
		native_memory_test_finish(mut first)
		native_memory_test_finish(mut second)
	}
	assert first.defer_memory_cleanup_to_native_idle()
	assert second.defer_memory_cleanup_to_native_idle()
	assert native_memory_cleanup_owners_.len == 2
	previous_owner := voidptr(second)
	native_memory_cleanup_current_owner_ = previous_owner
	native_memory_test_deliver(mut first)
	assert native_memory_cleanup_current_owner_ == previous_owner
	assert native_memory_cleanup_owners_.len == 1
	assert native_memory_cleanup_owners_[0] == second
	assert C.native_memory_test_unused_slot_is_clear(native_memory_cleanup_owners_.data,
		native_memory_cleanup_owners_.len, native_memory_cleanup_owners_.cap) == 1
	// An unknown/stale callback does not alter another pending owner.
	native_idle_memory_cleanup_callback(voidptr(first))
	assert native_memory_cleanup_owners_.len == 1
	assert native_memory_cleanup_current_owner_ == previous_owner
	native_memory_test_deliver(mut second)
	assert native_memory_cleanup_owners_.len == 0
	assert native_memory_cleanup_current_owner_ == previous_owner
}

fn test_native_idle_cleanup_uses_async_delivery_only_for_pending_static_native_work() {
	$if !macos {
		return
	}
	native_memory_test_begin()
	mut app := native_memory_test_app(false)
	defer { native_memory_test_finish(mut app) }
	app.release_unused_memory_if_idle(time.sys_mono_now())
	$if gcboehm ? {
		assert native_memory_cleanup_owners_.len == 1
		assert app.memory_maintenance.pending_document_work
		assert app.memory_maintenance.next_check_ns == 0
		native_memory_test_deliver(mut app)
		assert !app.memory_maintenance.pending_document_work
		app.memory_maintenance.last_cleanup_allocated = gc_heap_usage().total_bytes
		app.release_unused_memory_if_idle(time.sys_mono_now())
		assert native_memory_cleanup_owners_.len == 0
		$if native_memory_cleanup_stub ? {
			assert C.native_memory_test_dispatch_count() == 1
		}
	} $else {
		assert native_memory_cleanup_owners_.len == 0
		assert app.memory_maintenance.pending_document_work
		$if native_memory_cleanup_stub ? {
			assert C.native_memory_test_dispatch_count() == 0
		}
	}
}

fn test_native_idle_cleanup_bypasses_scripted_and_non_native_documents() {
	$if !macos {
		return
	}
	native_memory_test_begin()
	mut scripted := native_memory_test_app(true)
	mut non_native := native_memory_test_app(false)
	mut with_runtime := native_memory_test_app(false)
	mut no_context := native_memory_test_app(false)
	defer {
		native_memory_test_finish(mut scripted)
		native_memory_test_finish(mut non_native)
		native_memory_test_finish(mut with_runtime)
		native_memory_test_finish(mut no_context)
	}
	non_native.ctx = &gg.Context{ native_rendering: false }
	with_runtime.js_runtime = browserjs.Runtime.create_with_engine(.libjs)
	no_context.ctx = unsafe { nil }
	for app in [scripted, non_native, with_runtime, no_context] {
		assert !app.uses_static_native_memory_policy()
		mut owner := app
		assert !owner.defer_memory_cleanup_to_native_idle()
		owner.schedule_static_graphics_cleanup()
	}
	assert native_memory_cleanup_owners_.len == 0
	$if native_memory_cleanup_stub ? {
		assert C.native_memory_test_dispatch_count() == 0
		assert C.native_memory_test_graphics_count() == 0
	}
	mut eligible := native_memory_test_app(false)
	defer { native_memory_test_finish(mut eligible) }
	assert eligible.uses_static_native_memory_policy()
	eligible.schedule_static_graphics_cleanup()
	$if native_memory_cleanup_stub ? {
		assert C.native_memory_test_graphics_count() == 1
	}
}

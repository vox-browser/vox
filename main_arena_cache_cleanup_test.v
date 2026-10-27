module main

import dom
import gg
import platform
import time

#include "@DIR/platform/arena_page_retirement_test.h"
fn C.vox_arena_test_resident_bytes(start voidptr, bytes uint) uint

fn test_arena_idle_callback_discards_reset_native_replay_pages() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_scripting_enabled_by_embedder(false)
	document.update_readiness(.complete)
	mut app := &BrowserApp{document:document, ctx:&gg.Context{native_rendering:true}}
	defer { app.release_native_replay_scratch(); document.finalize() }
	mut replay := app.begin_native_replay_scratch()
	bytes := []u8{len:128 * 1024, init:59}
	data := bytes.data
	assert bytes[0] == 59 && bytes[bytes.len - 1] == 59
	replay.finish()
	capacity := app.native_replay_scratch.usage().capacity
	app.memory_maintenance.document_changed(1_000_000_000)
	app.frame_preparation_depth = 1
	app.release_unused_arena_caches_if_idle(3_000_000_000)
	assert app.memory_maintenance.pending_document_work
	app.frame_preparation_depth = 0
	app.release_unused_arena_caches_if_idle(3_000_000_000)
	assert !app.memory_maintenance.pending_document_work
	assert app.native_replay_scratch.usage().capacity == capacity
	if !platform.arenas_poisoned() {
		assert C.vox_arena_test_resident_bytes(data, 128 * 1024) == 0
	}
}

fn test_arena_idle_cleanup_is_armed_by_a_finished_static_native_frame() {
	$if !prealloc {
		return
	}
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_scripting_enabled_by_embedder(false)
	document.update_readiness(.complete)
	mut app := &BrowserApp{ document: document, ctx: &gg.Context{ native_rendering: true }, document_presented: true }
	defer {
		if app.memory_maintenance.cleanup_timer != unsafe { nil } {
			app.memory_maintenance.cleanup_timer.stop()
		}
		document.finalize()
	}
	font := &platform.Font{ family: 'sans-serif', point_size: 16 }
	first := platform.shape_text(0, 0, 'Keep published glyphs', font, .ltr)
	glyphs := first.glyphs().clone()
	finished := i64(time.sys_mono_now()) - 2_000_000_000
	app.memory_maintenance.document_changed(finished - 1_000_000_000)
	app.finish_frame_memory_activity(finished, app.paint_generation)
	assert app.memory_maintenance.cleanup_timer.is_active()
	app.memory_maintenance.cleanup_timer.restart_with_interval(30_000)
	app.finish_frame_memory_activity(finished + 100_000_000, app.paint_generation)
	assert app.memory_maintenance.cleanup_timer.interval() == 30_000
	app.memory_maintenance.cleanup_timer.fire()
	assert !app.memory_maintenance.pending_document_work
	assert !app.memory_maintenance.cleanup_timer.is_active()
	assert first.glyphs() == glyphs
	assert platform.shape_text(0, 0, 'Keep published glyphs', font, .ltr).glyphs() == glyphs
}

fn test_arena_cache_cleanup_waits_for_rendering_and_document_readiness() {
	$if !prealloc {
		return
	}
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_scripting_enabled_by_embedder(false)
	document.update_readiness(.loading)
	mut app := &BrowserApp{ document: document, ctx: &gg.Context{ native_rendering: true } }
	defer { document.finalize() }
	app.memory_maintenance.document_changed(1_000_000_000)
	app.release_unused_arena_caches_if_idle(3_000_000_000)
	assert app.memory_maintenance.pending_document_work
	document.update_readiness(.complete)
	app.frame_preparation_depth = 1
	app.release_unused_arena_caches_if_idle(3_000_000_000)
	assert app.memory_maintenance.pending_document_work
	app.frame_preparation_depth = 0
	app.navigation_work_depth = 1
	app.release_unused_arena_caches_if_idle(3_000_000_000)
	assert app.memory_maintenance.pending_document_work
	app.navigation_work_depth = 0
	app.background_resource_pending['https://cache-work.test/image.png'] = true
	app.release_unused_arena_caches_if_idle(3_000_000_000)
	assert app.memory_maintenance.pending_document_work
	app.background_resource_pending.clear()
	app.release_unused_arena_caches_if_idle(3_000_000_000)
	assert !app.memory_maintenance.pending_document_work
}

fn test_arena_idle_timer_outlives_the_document_that_first_registers_it() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut app := &BrowserApp{document: document}
	mut payload := document.enter_native_storage()
	app.arm_arena_cache_cleanup()
	payload.finish()
	timer := app.memory_maintenance.cleanup_timer
	assert !document.native_storage().arena.contains(voidptr(timer))
	app.memory_maintenance.cleanup_timer.stop()
	document.finalize()
	document.release_native_storage()
	assert timer.interval() == 500
	assert !timer.is_active()
}

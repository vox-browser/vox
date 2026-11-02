module main

import dom
import browserjs
import gg
import html
import platform
import time

#include "@DIR/platform/arena_page_retirement_test.h"

fn C.vox_arena_test_resident_bytes(start voidptr, bytes uint) uint

fn test_arena_idle_callback_discards_reset_native_replay_pages() {
	$if !prealloc {
		return
	}
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_scripting_enabled_by_embedder(false)
	document.update_readiness(.complete)
	mut app := &BrowserApp{ document: document, ctx: &gg.Context{ native_rendering: true } }
	defer {
		app.release_native_replay_scratch()
		document.finalize()
	}
	mut replay := app.begin_native_replay_scratch()
	bytes := []u8{len: 128 * 1024, init: 59}
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
	$if !prealloc {
		return
	}
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut app := &BrowserApp{ document: document }
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

fn test_scripted_native_idle_cleanup_retires_reset_pages_and_preserves_live_javascript() {
	$if !prealloc {
		return
	}
	mut document := html.parse_document('<!doctype html><p id="kept">Original</p>')
	document.enable_native_storage()
	document.update_readiness(.complete)
	mut runtime := browserjs.Runtime.create()
	mut app := &BrowserApp{
		document:           document
		js_runtime:         runtime
		ctx:                &gg.Context{ native_rendering: true }
		document_presented: true
	}
	defer {
		if app.memory_maintenance.cleanup_timer != unsafe { nil } {
			app.memory_maintenance.cleanup_timer.stop()
		}
		app.release_native_replay_scratch()
		runtime.close()
		document.finalize()
		document.release_native_storage()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://scripted-idle.test/', [r'
window.savedNode=document.getElementById("kept");
window.savedClosure=(()=>{const text="retained λ";return()=>text})();
'], runtime, mut messages)
	assert messages == []string{}
	assert !app.uses_static_native_memory_policy()
	mut replay := app.begin_native_replay_scratch()
	bytes := []u8{len: 128 * 1024, init: 71}
	data := bytes.data
	assert bytes[0] == 71 && bytes[bytes.len - 1] == 71
	replay.finish()
	finished := i64(time.sys_mono_now()) - 2_000_000_000
	app.memory_maintenance.document_changed(finished - 1_000_000_000)
	app.finish_frame_memory_activity(finished, app.paint_generation)
	assert app.memory_maintenance.cleanup_timer.is_active()
	app.memory_maintenance.cleanup_timer.fire()
	assert !app.memory_maintenance.pending_document_work
	if !platform.arenas_poisoned() {
		assert C.vox_arena_test_resident_bytes(data, 128 * 1024) == 0
	}
	assert runtime.evaluate_host('savedNode===document.getElementById("kept")&&savedClosure()==="retained λ"')! == 'true'
	runtime.evaluate_host('savedNode.textContent=savedClosure();0')!
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_runtime_state(document, state, runtime, mut messages)
	assert messages == []string{}
	assert document.get_element_by_id('kept')?.as_node().text_content()? == 'retained λ'
}

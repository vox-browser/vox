module main

import browserjs
import dom
import gg
import layout
import time

#include "@DIR/idle_paint_cache_test.h"

fn C.vox_main_idle_paint_phase_capacity(result voidptr) int
$if native_memory_cleanup_stub ? {
	fn C.vox_main_idle_paint_deliver(owner voidptr) int
}

fn main_idle_paint_app(scripting_enabled bool, native_rendering bool) &BrowserApp {
	mut document := parse_browser_navigation_document_with_scripting('<!doctype html><style>html,body{margin:0}p{background:green}</style><p id="kept">published paint</p>', dom.url_about_blank(), none, none, none, 0, scripting_enabled)
	document.update_readiness(.complete)
	_ = layout.layout_document_typed_in_viewport(document, 320, 200)
	list := document.record_display_list() or { panic('missing display list') }
	mut app := &BrowserApp{
		ctx: &gg.Context{native_rendering: native_rendering}
		document: document
		paint_display_list: list
		paint_commands: layout.display_list_commands(list)
		document_presented: true
	}
	app.memory_maintenance.document_changed(i64(time.sys_mono_now()) - 2_000_000_000)
	app.memory_maintenance.presentation_pending = false
	app.memory_maintenance.last_cleanup_allocated = gc_heap_usage().total_bytes
	return app
}

fn main_idle_paint_finish(mut app BrowserApp) {
	if app.js_runtime != unsafe { nil } { app.js_runtime.close() }
	remove_native_memory_cleanup_owner(voidptr(&app))
	if app.memory_maintenance.cleanup_timer != unsafe { nil } {
		app.memory_maintenance.cleanup_timer.stop()
	}
	mut document := app.document
	document.finalize()
}

fn main_idle_paint_cleanup(mut app BrowserApp) {
	app.release_unused_memory_if_idle(time.sys_mono_now())
	$if macos {
		for pending in native_memory_cleanup_owners_ {
			if voidptr(pending) != voidptr(&app) { continue }
			$if native_memory_cleanup_stub ? {
				assert C.vox_main_idle_paint_deliver(voidptr(&app)) == 1
			} $else {
				native_idle_memory_cleanup_callback(voidptr(&app))
			}
			break
		}
	}
}

fn test_nojs_natural_idle_cleanup_releases_only_unpublished_paint_cache() {
	for native_rendering in [false, true] {
		mut app := main_idle_paint_app(false, native_rendering)
		assert C.vox_main_idle_paint_phase_capacity(app.document.layout_engine_handle()) > 0
		list := app.paint_display_list
		commands := app.paint_commands
		main_idle_paint_cleanup(mut app)
		$if gcboehm ? {
			assert C.vox_main_idle_paint_phase_capacity(app.document.layout_engine_handle()) == 0
			assert !app.memory_maintenance.pending_document_work
		} $else {
			assert C.vox_main_idle_paint_phase_capacity(app.document.layout_engine_handle()) > 0
		}
		assert app.paint_display_list == list
		assert app.paint_commands.data == commands.data
		assert app.paint_commands.any(it.text == 'published paint')
		assert app.document.get_element_by_id('kept')?.text_content() or { '' } == 'published paint'
		assert native_memory_cleanup_owners_.len == 0
		main_idle_paint_finish(mut app)
	}
}

fn test_idle_paint_cleanup_keeps_scripted_documents_and_existing_runtime_caches() {
	for with_runtime in [false, true] {
		mut app := main_idle_paint_app(!with_runtime, true)
		if with_runtime { app.js_runtime = browserjs.Runtime.create() }
		capacity := C.vox_main_idle_paint_phase_capacity(app.document.layout_engine_handle())
		main_idle_paint_cleanup(mut app)
		assert C.vox_main_idle_paint_phase_capacity(app.document.layout_engine_handle()) == capacity
		assert app.paint_commands.any(it.text == 'published paint')
		assert native_memory_cleanup_owners_.len == 0
		main_idle_paint_finish(mut app)
	}
}

fn test_idle_paint_cleanup_rechecks_navigation_resources_nested_work_and_readiness() {
	for busy in 0 .. 5 {
		mut app := main_idle_paint_app(false, true)
		capacity := C.vox_main_idle_paint_phase_capacity(app.document.layout_engine_handle())
		if busy == 0 { app.pending_navigation = PendingNavigation{resolved: 'about:blank'} }
		if busy == 1 { app.background_resource_pending['https://example.com/pending.png'] = true }
		if busy == 2 { app.navigation_work_depth = 1 }
		if busy == 3 { app.frame_preparation_depth = 1 }
		if busy == 4 { app.document.update_readiness(.loading) }
		main_idle_paint_cleanup(mut app)
		assert C.vox_main_idle_paint_phase_capacity(app.document.layout_engine_handle()) == capacity
		assert app.memory_maintenance.pending_document_work
		assert native_memory_cleanup_owners_.len == 0
		app.pending_navigation = none
		app.background_resource_pending = map[string]bool{}
		app.navigation_work_depth = 0
		app.frame_preparation_depth = 0
		app.document.update_readiness(.complete)
		main_idle_paint_cleanup(mut app)
		$if gcboehm ? {
			assert C.vox_main_idle_paint_phase_capacity(app.document.layout_engine_handle()) == 0
		}
		assert native_memory_cleanup_owners_.len == 0
		main_idle_paint_finish(mut app)
	}
}

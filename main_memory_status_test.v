module main

import browserjs
import dom
import gg

$if macos {
	#flag darwin -DVOX_STATIC_MEMORY_STATUS_TEST_STUB
	#include "main_memory_status_test.h"

	fn C.memory_status_test_reset(available int)
	fn C.memory_status_test_uses() int
	fn C.memory_status_test_disables() int
	fn C.memory_status_test_width() f32
	fn C.memory_status_test_y() f32
	fn C.memory_status_test_height() f32
}

fn memory_status_test_app(scripting_enabled bool) &BrowserApp {
	mut document := parse_browser_navigation_document_with_scripting('<!doctype html><p>retained static page</p>',
		dom.url_about_blank(), none, none, none, 0, scripting_enabled)
	document.update_readiness(.complete)
	return &BrowserApp{
		ctx:      &gg.Context{
			native_rendering: true
		}
		document: document
	}
}

fn test_memory_status_native_static_path_bypasses_v_sampling_and_painting() {
	$if macos {
		C.memory_status_test_reset(1)
		mut app := memory_status_test_app(false)
		defer {
			mut document := app.document
			document.finalize()
		}
		for _ in 0 .. 60 {
			app.draw_memory_status(1024, 856)
		}
		assert C.memory_status_test_uses() == 60
		assert C.memory_status_test_disables() == 0
		assert C.memory_status_test_width() == 1024
		assert C.memory_status_test_y() == 856
		assert C.memory_status_test_height() == status_bar_height
		assert !app.memory_status.sampled
		assert app.memory_status.label == ''
		assert app.memory_status.next_sample_ns == 0
	}
}

fn test_memory_status_native_failure_selects_the_existing_v_fallback() {
	$if macos {
		C.memory_status_test_reset(0)
		app := memory_status_test_app(false)
		defer {
			mut document := app.document
			document.finalize()
		}
		assert !app.use_native_memory_status(800, 576)
		assert C.memory_status_test_uses() == 1
		assert C.memory_status_test_disables() == 1
	}
}

fn test_memory_status_disables_native_label_for_scripted_and_non_native_pages() {
	$if macos {
		C.memory_status_test_reset(1)
		mut scripted := memory_status_test_app(true)
		mut non_native := memory_status_test_app(false)
		mut with_runtime := memory_status_test_app(false)
		mut no_context := memory_status_test_app(false)
		non_native.ctx = &gg.Context{
			native_rendering: false
		}
		with_runtime.js_runtime = browserjs.Runtime.create_with_engine(.libjs)
		no_context.ctx = unsafe { nil }
		for app in [scripted, non_native, with_runtime, no_context, &BrowserApp{}] {
			assert !app.use_native_memory_status(800, 576)
		}
		assert C.memory_status_test_uses() == 0
		assert C.memory_status_test_disables() == 5
		with_runtime.js_runtime.close()
		for app in [scripted, non_native, with_runtime, no_context] {
			mut document := app.document
			document.finalize()
		}
	}
}

fn test_memory_status_refreshes_once_per_second_across_idle_and_busy_frames() {
	mut status := BrowserMemoryStatus{}
	assert status.refresh_if_due(0)
	assert status.label.starts_with('RAM: ')
	assert status.next_sample_ns == 1_000_000_000
	first_label := status.label
	assert !status.refresh_if_due(16_000_000)
	assert !status.refresh_if_due(999_999_999)
	assert status.label == first_label
	assert status.refresh_if_due(1_000_000_000)
	assert status.next_sample_ns == 2_000_000_000
	// A delayed frame schedules from the current time without catching up.
	assert status.refresh_if_due(5_000_000_000)
	assert status.next_sample_ns == 6_000_000_000
}

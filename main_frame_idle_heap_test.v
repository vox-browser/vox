module main

import adblock
import dom
import gg
import os
import platform

fn C.GC_get_free_space_divisor() uint
fn C.GC_set_free_space_divisor(uint)
fn C.GC_call_with_alloc_lock(fn (voidptr) voidptr, voidptr) voidptr

$if gcboehm ? {
	struct FrameIdleHeapObservation { mut: divisor uint }
	fn frame_idle_heap_read_locked(context voidptr) voidptr {
		mut value := unsafe { &FrameIdleHeapObservation(context) }
		value.divisor = C.GC_get_free_space_divisor()
		return unsafe { nil }
	}
	fn frame_idle_heap_write_locked(context voidptr) voidptr {
		value := unsafe { &FrameIdleHeapObservation(context) }
		C.GC_set_free_space_divisor(value.divisor)
		return unsafe { nil }
	}
	fn frame_idle_heap_divisor() uint {
		mut value := FrameIdleHeapObservation{}
		C.GC_call_with_alloc_lock(frame_idle_heap_read_locked, &value)
		return value.divisor
	}
	fn frame_idle_heap_set_divisor(divisor uint) {
		value := FrameIdleHeapObservation{divisor: divisor}
		C.GC_call_with_alloc_lock(frame_idle_heap_write_locked, &value)
	}
}

fn test_final_document_frame_heap_policy_covers_replay_after_installation() {
	mut document := parse_browser_navigation_document_with_scripting('<!doctype html><p>retained</p>',
		dom.URL{value: 'https://frame-heap.example/'}, none, none, none, 0, false)
	defer { document.finalize() }
	mut app := &BrowserApp{ctx: &gg.Context{}}
	$if gcboehm ? {
		settings := ['GC_INITIAL_HEAP_SIZE', 'GC_MAXIMUM_HEAP_SIZE', 'GC_FREE_SPACE_DIVISOR']
		previous_settings := settings.map(os.getenv(it))
		previous_divisor := frame_idle_heap_divisor()
		defer {
			frame_idle_heap_set_divisor(previous_divisor)
			for index, setting in settings { os.setenv(setting, previous_settings[index], true) }
		}
		for setting in settings { os.setenv(setting, '', true) }
		frame_idle_heap_set_divisor(64)
		mut navigation := app.begin_navigation_work()
		assert frame_idle_heap_divisor() == 3
		mut frame := platform.begin_browser_activity_heap_scope_for_scripting(app.document_scripting_enabled_for_heap())
		assert frame_idle_heap_divisor() == 3
		// A frame can start with no document and install a no-JS document during
		// preparation. The actual draw helper retargets its existing scope.
		app.document = document
		app.retarget_document_frame_heap_scope(mut frame)
		assert frame_idle_heap_divisor() == 64
		assert gc_is_enabled()
		mut nested := app.begin_navigation_work()
		mut generic := platform.begin_browser_activity_heap_scope()
		assert frame_idle_heap_divisor() == 64
		generic.finish()
		nested.finish()
		assert frame_idle_heap_divisor() == 64
		document.set_scripting_enabled_by_embedder(true)
		assert app.document_scripting_enabled_for_heap()
		app.retarget_document_frame_heap_scope(mut frame)
		assert frame_idle_heap_divisor() == 3
		document.set_scripting_enabled_by_embedder(false)
		app.retarget_document_frame_heap_scope(mut frame)
		assert frame_idle_heap_divisor() == 64
		frame.finish()
		assert frame_idle_heap_divisor() == 3
		navigation.finish()
		assert frame_idle_heap_divisor() == 64
	} $else {
		mut frame := platform.begin_browser_activity_heap_scope()
		app.document = document
		app.retarget_document_frame_heap_scope(mut frame)
		assert !app.document_scripting_enabled_for_heap()
		frame.finish()
	}
}

fn test_document_frame_heap_retarget_preserves_explicit_collector_configuration() {
	$if gcboehm ? {
		settings := ['GC_INITIAL_HEAP_SIZE', 'GC_MAXIMUM_HEAP_SIZE', 'GC_FREE_SPACE_DIVISOR']
		previous_settings := settings.map(os.getenv(it))
		previous_divisor := frame_idle_heap_divisor()
		defer {
			frame_idle_heap_set_divisor(previous_divisor)
			for index, setting in settings { os.setenv(setting, previous_settings[index], true) }
		}
		for setting in settings { os.setenv(setting, '', true) }
		mut document := parse_browser_navigation_document_with_scripting('<!doctype html><p>override</p>',
			dom.URL{value: 'https://frame-override.example/'}, none, none, none, 0, false)
		defer { document.finalize() }
		app := BrowserApp{document: document}
		for setting in settings {
			frame_idle_heap_set_divisor(17)
			os.setenv(setting, '8', true)
			mut frame := platform.begin_browser_activity_heap_scope()
			app.retarget_document_frame_heap_scope(mut frame)
			assert frame_idle_heap_divisor() == 17
			frame.finish()
			assert frame_idle_heap_divisor() == 17
			os.setenv(setting, '', true)
		}
	} $else {
		assert !platform.initialize_browser_heap_policy()
	}
}

fn test_idle_filter_release_waits_for_the_whole_native_frame_and_later_succeeds() {
	previous_enabled := adblock.is_enabled()
	adblock.set_enabled(true)
	defer {
		adblock.release_unused_engine()
		adblock.set_enabled(previous_enabled)
	}
	mut document := parse_browser_navigation_document_with_scripting('<!doctype html><p id="kept">live</p>',
		dom.URL{value: 'https://www.theverge.com/'}, none, none, none, 0, false)
	defer { document.finalize() }
	document.update_readiness(.complete)
	mut app := &BrowserApp{document: document, ctx: &gg.Context{}}
	for iteration, during_preparation in [false, true] {
		// A retained decision need not restore the filter worker. Use distinct
		// cache misses when this fixture specifically needs a live worker.
		request := adblock.Request{url:'https://securepubads.g.doubleclick.net/tag/js/gpt.js?frame=${iteration}', source_url:'https://www.theverge.com/', request_type:'script'}
		restore_request := adblock.Request{url:request.url + '&restore=1', source_url:request.source_url, request_type:request.request_type}
		before := adblock.check(request)
		assert before.error == ''
		assert before.blocked
		app.memory_maintenance = BrowserMemoryMaintenance{}
		app.memory_maintenance.document_changed(1_000_000_000)
		mut frame := app.begin_navigation_work()
		assert app.navigation_work_depth == 1
		app.frame_preparation_depth = if during_preparation { 1 } else { 0 }
		app.release_unused_memory_if_idle(3_000_000_000)
		assert app.memory_maintenance.pending_document_work
		assert adblock.release_unused_engine()
		assert adblock.check(restore_request) == before
		app.frame_preparation_depth = 0
		frame.finish()
		app.release_unused_memory_if_idle(4_000_000_000)
		$if gcboehm ? {
			assert !app.memory_maintenance.pending_document_work
			assert !adblock.release_unused_engine()
		} $else {
			assert app.memory_maintenance.pending_document_work
			assert adblock.release_unused_engine()
		}
		assert document.get_element_by_id('kept')?.text_content() or { '' } == 'live'
	}
}

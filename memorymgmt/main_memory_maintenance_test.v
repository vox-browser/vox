module main

import page
import gg
import time
import dom
import adblock

fn test_first_native_replay_of_an_already_recorded_document_is_active_work() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut app := BrowserApp{document: document}
	app.memory_maintenance.document_changed(1_000_000_000)
	// The display list was adopted before draw(), so its identity is unchanged.
	app.finish_frame_memory_activity(3_000_000_000, app.paint_generation)
	assert !app.memory_maintenance.cleanup_due(3_000_000_000, 100)
	assert !app.memory_maintenance.cleanup_due(3_499_000_000, 100)
	app.document_presented = true
	app.finish_frame_memory_activity(4_000_000_000, app.paint_generation)
	assert app.memory_maintenance.cleanup_due(4_000_000_000, 100)
}

fn test_slow_document_frames_are_active_until_their_native_replay_finishes() {
	mut maintenance := BrowserMemoryMaintenance{}
	maintenance.document_changed(1_000_000_000)
	// Recording plus replay takes two seconds; its own completion is not idle.
	maintenance.frame_finished(3_000_000_000, true)
	assert !maintenance.cleanup_due(3_000_000_000, 100)
	assert !maintenance.cleanup_due(3_499_000_000, 100)
	assert maintenance.cleanup_due(4_000_000_000, 100)
	// Unchanged chrome-only frames must still allow genuine idle cleanup.
	maintenance.document_changed(5_000_000_000)
	maintenance.frame_finished(5_100_000_000, false)
	assert !maintenance.cleanup_due(5_100_000_000, 100)
	maintenance.frame_finished(6_100_000_000, false)
	assert maintenance.cleanup_due(6_100_000_000, 100)
}

fn test_successive_slow_animation_frames_defer_only_explicit_idle_cleanup() {
	mut maintenance := BrowserMemoryMaintenance{}
	maintenance.document_changed(1_000_000_000)
	for finished_ns in [i64(3_000_000_000), 4_000_000_000, 5_000_000_000] {
		maintenance.frame_finished(finished_ns, true)
		assert !maintenance.cleanup_due(finished_ns, uint(64) * 1024 * 1024)
	}
	maintenance.frame_finished(5_250_000_000, false)
	assert !maintenance.cleanup_due(5_499_000_000, uint(64) * 1024 * 1024)
	assert maintenance.cleanup_due(6_000_000_000, uint(64) * 1024 * 1024)
}

fn test_memory_cleanup_waits_for_idle_and_new_allocations() {
	mut maintenance := BrowserMemoryMaintenance{}
	maintenance.document_changed(1_000_000_000)
	assert !maintenance.cleanup_due(1_100_000_000, 100)
	assert !maintenance.cleanup_due(1_700_000_000, 100)
	assert maintenance.cleanup_due(2_100_000_000, 100)
	assert !maintenance.cleanup_due(3_100_000_000, 100)
	assert maintenance.cleanup_due(4_100_000_000, 100 + uint(32) * 1024 * 1024)
	maintenance.document_changed(5_000_000_000)
	assert !maintenance.cleanup_due(5_100_000_000, 100 + uint(32) * 1024 * 1024)
	assert maintenance.cleanup_due(6_100_000_000, 100 + uint(32) * 1024 * 1024)
}

fn test_idle_memory_release_preserves_live_dom_javascript_and_later_paint_updates() {
	$if !darwin { return }
	mut owner := page.Page.create(1)!
	mut app := BrowserApp{
		page_model: owner
		script_policy: .enabled
		viewport_width: 320
		viewport_height: 200
	}
	app.install_loaded_page(LoadedPage{
		url: 'https://idle-memory.example/'
		content_type: 'text/html'
		markup: '<!doctype html><div id="target">before</div><script>target.textContent="live JavaScript";</script>'
	}, false)
	defer {
		if app.js_runtime != unsafe { nil } { app.js_runtime.close() }
		mut document := app.document
		document.finalize()
	}
	assert app.js_runtime != unsafe { nil }
	app.document.update_readiness(.complete)
	app.release_unused_memory_if_idle(app.memory_maintenance.last_document_activity_ns + 2_000_000_000)
	assert app.js_runtime.evaluate_host('document.getElementById("target").textContent')! == 'live JavaScript'
	mut target := app.document.get_element_by_id('target') or { panic('missing retained target') }
	target.set_attribute_value('style', 'width:200px;height:20px;background:rgb(17,34,51)')
	app.relayout(320, 200 + app.chrome_height())
	assert app.paint_commands.any(it.color == 'rgb(17 34 51)')
	assert app.paint_commands.any(it.text.contains('live JavaScript'))
}

fn test_unchanged_document_replays_preserve_the_idle_timer_and_allow_cleanup() {
	$if !gcboehm ? { return }
	previous_enabled := adblock.is_enabled()
	adblock.set_enabled(true)
	defer {
		adblock.release_unused_engine()
		adblock.set_enabled(previous_enabled)
	}
	mut owner := page.Page.create(1)!
	mut app := &BrowserApp{page_model: owner, script_policy: .disabled, viewport_width: 320, viewport_height: 200}
	app.install_loaded_page(LoadedPage{url:'https://www.theverge.com/', content_type:'text/html', markup:'<!doctype html><p id="kept">retained</p>'}, false)
	mut document := app.document
	defer {
		if app.memory_maintenance.cleanup_timer != unsafe { nil } { app.memory_maintenance.cleanup_timer.stop() }
		document.finalize()
	}
	document.update_readiness(.complete)
	app.ctx = &gg.Context{}
	app.document_presented = true
	finished := i64(time.sys_mono_now()) - 2_000_000_000
	app.memory_maintenance.document_changed(finished - 1_000_000_000)
	paint := app.paint_generation
	app.finish_frame_memory_activity(finished, paint)
	assert app.memory_maintenance.last_document_activity_ns == finished
	assert !app.memory_maintenance.presentation_pending
	assert app.memory_maintenance.cleanup_timer.is_active()
	assert app.memory_maintenance.pending_document_work
	// Use a long native registration so this test needs no sleep or run-loop
	// pumping. An unchanged replay must preserve it rather than restart at500ms.
	app.memory_maintenance.cleanup_timer.restart_with_interval(30_000)
	for elapsed in [i64(100_000_000), 200_000_000, 400_000_000] {
		app.finish_frame_memory_activity(finished + elapsed, paint)
		assert app.memory_maintenance.last_document_activity_ns == finished
		assert app.memory_maintenance.cleanup_timer.interval() == 30_000
		assert app.memory_maintenance.pending_document_work
	}
	request := adblock.Request{url:'https://securepubads.g.doubleclick.net/tag/js/gpt.js', source_url:'https://www.theverge.com/', request_type:'script'}
	before := adblock.check(request)
	assert before.error == ''
	assert before.blocked
	app.memory_maintenance.cleanup_timer.fire()
	assert !app.memory_maintenance.pending_document_work
	assert !app.memory_maintenance.cleanup_timer.is_active()
	assert !adblock.release_unused_engine()
	assert adblock.check(request) == before
	assert app.paint_generation == paint
	assert document.get_element_by_id('kept')?.text_content() or { '' } == 'retained'
}

fn test_recording_with_a_stable_display_list_waits_for_its_completed_presentation() {
	mut maintenance := BrowserMemoryMaintenance{}
	maintenance.document_changed(1_000_000_000)
	maintenance.frame_finished(3_000_000_000, false)
	assert maintenance.last_document_activity_ns == 3_000_000_000
	assert !maintenance.presentation_pending
	assert !maintenance.cleanup_due(3_499_000_000, 100)
	assert maintenance.cleanup_due(4_499_000_000, 100)
	maintenance.document_changed(5_000_000_000)
	maintenance.frame_finished(7_000_000_000, false)
	assert maintenance.last_document_activity_ns == 7_000_000_000
	maintenance.frame_finished(7_100_000_000, false)
	assert maintenance.last_document_activity_ns == 7_000_000_000
}

fn test_changed_document_restarts_idle_timer_but_empty_frames_create_no_activity() {
	mut empty := BrowserApp{}
	empty.finish_frame_memory_activity(3_000_000_000, 0)
	assert empty.memory_maintenance.last_document_activity_ns == 0
	assert !empty.memory_maintenance.pending_document_work
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut app := BrowserApp{document: document, ctx: &gg.Context{}, document_presented: true}
	defer { if app.memory_maintenance.cleanup_timer != unsafe { nil } { app.memory_maintenance.cleanup_timer.stop() } }
	app.memory_maintenance.document_changed(1_000_000_000)
	app.finish_frame_memory_activity(2_000_000_000, app.paint_generation)
	$if gcboehm ? { app.memory_maintenance.cleanup_timer.restart_with_interval(30_000) }
	app.memory_maintenance.document_changed(3_000_000_000)
	app.finish_frame_memory_activity(5_000_000_000, app.paint_generation)
	assert app.memory_maintenance.last_document_activity_ns == 5_000_000_000
	$if gcboehm ? { assert app.memory_maintenance.cleanup_timer.interval() == 500 }
	assert !app.memory_maintenance.cleanup_due(5_499_000_000, 100)
	assert app.memory_maintenance.cleanup_due(6_499_000_000, 100)
}

fn test_idle_cleanup_handles_earlier_timestamps_and_allocation_counter_resets() {
	mut maintenance := BrowserMemoryMaintenance{last_document_activity_ns: 5_000_000_000, last_cleanup_allocated: uint(64) * 1024 * 1024}
	assert !maintenance.cleanup_due(4_000_000_000, uint(1))
	assert !maintenance.has_pending_cleanup(uint(1))
	assert !maintenance.cleanup_due(6_000_000_000, uint(1))
	assert maintenance.cleanup_due(7_000_000_000, uint(96) * 1024 * 1024)
}

module main

import page

fn test_first_native_replay_of_an_already_recorded_document_is_active_work() {
	mut app := BrowserApp{}
	app.memory_maintenance.document_changed(1_000_000_000)
	// The display list was adopted before draw(), so its identity is unchanged.
	app.finish_frame_memory_activity(3_000_000_000, voidptr(app.paint_display_list))
	assert !app.memory_maintenance.cleanup_due(3_000_000_000, 100)
	assert !app.memory_maintenance.cleanup_due(3_499_000_000, 100)
	app.document_presented = true
	app.finish_frame_memory_activity(4_000_000_000, voidptr(app.paint_display_list))
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
		assert !maintenance.cleanup_due(finished_ns, usize(64) * 1024 * 1024)
	}
	maintenance.frame_finished(5_250_000_000, false)
	assert !maintenance.cleanup_due(5_499_000_000, usize(64) * 1024 * 1024)
	assert maintenance.cleanup_due(6_000_000_000, usize(64) * 1024 * 1024)
}

fn test_memory_cleanup_waits_for_idle_and_new_allocations() {
	mut maintenance := BrowserMemoryMaintenance{}
	maintenance.document_changed(1_000_000_000)
	assert !maintenance.cleanup_due(1_100_000_000, 100)
	assert !maintenance.cleanup_due(1_700_000_000, 100)
	assert maintenance.cleanup_due(2_100_000_000, 100)
	assert !maintenance.cleanup_due(3_100_000_000, 100)
	assert maintenance.cleanup_due(4_100_000_000, 100 + usize(32) * 1024 * 1024)
	maintenance.document_changed(5_000_000_000)
	assert !maintenance.cleanup_due(5_100_000_000, 100 + usize(32) * 1024 * 1024)
	assert maintenance.cleanup_due(6_100_000_000, 100 + usize(32) * 1024 * 1024)
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
	app.release_unused_memory_if_idle(app.memory_maintenance.last_document_activity_ns + 2_000_000_000)
	assert app.js_runtime.evaluate_host('document.getElementById("target").textContent')! == 'live JavaScript'
	mut target := app.document.get_element_by_id('target') or { panic('missing retained target') }
	target.set_attribute_value('style', 'width:200px;height:20px;background:rgb(17,34,51)')
	app.relayout(320, 200 + app.chrome_height())
	assert app.paint_commands.any(it.color == 'rgb(17 34 51)')
	assert app.paint_commands.any(it.text.contains('live JavaScript'))
}

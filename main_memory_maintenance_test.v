module main

import page

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

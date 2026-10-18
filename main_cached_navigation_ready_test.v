module main

import page
import time

fn test_ready_cached_document_preload_commits_without_waiting_for_network_refresh_deadline() {
	owner := page.Page.create(1)!
	mut app := &BrowserApp{
		page_model: owner
		script_policy: .disabled
		viewport_width: 320
		viewport_height: 200
		navigation_results: chan NavigationResult{cap: 1}
	}
	app.install_loaded_page(LoadedPage{url: 'https://ready-cache.test/', markup: '<!doctype html><p>Previous page</p>'}, false)
	mut old := app.document
	app.document_presented = true
	app.refresh_not_before = time.sys_mono_now() + time.second
	app.pending_page_preload = PendingPagePreload{
		loaded: LoadedPage{url: 'https://ready-cache.test/search', markup: '<!doctype html><p id="results">Cached search results</p>'}
		generation: app.navigation_generation
		results: chan PreloadedResource{cap: 1}
		remaining: 0
	}
	app.poll_navigation_and_background_resources(false)
	defer { app.document.finalize(); old.finalize() }
	assert app.pending_page_preload == none
	assert app.document.get_element_by_id('results') != none
	assert app.paint_commands.any(it.text.contains('Cached search results'))
	assert !app.document_presented
	assert app.refresh_not_before > time.sys_mono_now()
}

fn test_live_refresh_stays_queued_until_the_ready_cached_document_has_painted() {
	owner := page.Page.create(1)!
	mut app := &BrowserApp{
		page_model: owner
		script_policy: .disabled
		viewport_width: 320
		viewport_height: 200
		navigation_results: chan NavigationResult{cap: 1}
	}
	app.install_loaded_page(LoadedPage{url: 'https://ready-cache.test/', markup: '<!doctype html><p>Previous page</p>'}, false)
	mut old := app.document
	app.document_presented = true
	app.pending_page_preload = PendingPagePreload{
		loaded: LoadedPage{url: 'https://ready-cache.test/search', markup: '<!doctype html><p id="cached">Cached results</p>'}
		generation: app.navigation_generation
		results: chan PreloadedResource{cap: 1}
		remaining: 0
	}
	app.navigation_results <- NavigationResult{
		generation: app.navigation_generation
		had_cached_page: true
		loaded: LoadedPage{url: 'https://ready-cache.test/search', markup: '<!doctype html><p id="fresh">Fresh results</p>'}
	}
	app.poll_navigation_and_background_resources(true)
	mut cached := app.document
	assert cached.get_element_by_id('cached') != none
	assert app.navigation_results.len == 1
	app.document_presented = true
	app.poll_navigation_and_background_resources(true)
	defer { app.document.finalize(); cached.finalize(); old.finalize() }
	assert app.document.get_element_by_id('fresh') != none
	assert app.navigation_results.len == 0
}

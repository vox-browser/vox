module main

import dom
import net
import os
import time

fn navigation_fetch_state_app() &BrowserApp {
	mut document := parse_browser_navigation_document('<!doctype html><p>Previous page</p>',
		dom.URL{value: 'https://navigation-fetch.test/'}, none)
	document.update_readiness(.complete)
	mut app := &BrowserApp{
		document: document
		navigation_generation: 1
		navigation_results: chan NavigationResult{cap: 4}
		background_resource_results: chan PreloadedResource{cap: 4}
	}
	app.memory_maintenance.document_changed(1_000_000_000)
	return app
}

fn gated_navigation_fetch(mut listener net.TcpListener, requested chan bool, release chan bool) {
	mut connection := listener.accept() or { panic(err) }
	defer { connection.close() or {} }
	connection.set_read_timeout(5 * time.second)
	mut bytes := []u8{len: 4096}
	connection.read(mut bytes) or { panic(err) }
	requested <- true
	_ := <-release
	body := '<!doctype html><p>Next page</p>'
	connection.write_string('HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}') or { panic(err) }
}

fn test_running_navigation_fetch_blocks_idle_collection_until_response_is_consumed() {
	cache := os.join_path(os.temp_dir(), 'vox-fetch-state-${os.getpid()}-${time.sys_mono_now()}')
	previous_cache := os.getenv_opt('LADYBIRD_CACHE_DIR')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if previous := previous_cache { os.setenv('LADYBIRD_CACHE_DIR', previous, true) }
		else { os.unsetenv('LADYBIRD_CACHE_DIR') }
		os.rmdir_all(cache) or {}
	}
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	mut app := navigation_fetch_state_app()
	mut old := app.document
	defer { app.document.finalize(); old.finalize() }
	requested := chan bool{cap: 1}
	release := chan bool{cap: 1}
	worker := spawn gated_navigation_fetch(mut listener, requested, release)
	app.address = 'http://${listener.addr()!}/next'
	app.start_navigation_fetch(PendingNavigation{
		resolved: app.address
		generation: app.navigation_generation
	})
	assert <-requested
	assert app.pending_navigation == none
	assert app.has_navigation_fetch_in_flight()
	app.release_unused_memory_if_idle(3_000_000_000)
	assert app.memory_maintenance.pending_document_work
	assert app.memory_maintenance.next_check_ns == 0
	release <- true
	worker.wait()
	deadline := time.sys_mono_now() + 5 * time.second
	for app.navigation_results.len == 0 && time.sys_mono_now() < deadline {
		time.sleep(time.millisecond)
	}
	assert app.navigation_results.len == 1
	// The response is still pending UI consumption, so cleanup remains deferred.
	app.release_unused_memory_if_idle(4_000_000_000)
	assert app.memory_maintenance.pending_document_work
	app.poll_navigation()
	assert !app.has_navigation_fetch_in_flight()
	assert voidptr(app.document) != voidptr(old)
	assert app.markup.contains('Next page')
}

fn test_stale_navigation_reply_cannot_clear_current_fetch_and_history_supersedes_it() {
	mut app := navigation_fetch_state_app()
	mut old := app.document
	defer { app.document.finalize(); old.finalize() }
	app.navigation_generation = 2
	app.navigation_fetch_generation = 2
	app.navigation_results <- NavigationResult{generation: 1}
	app.poll_navigation()
	assert app.has_navigation_fetch_in_flight()
	app.navigation_results <- NavigationResult{generation: 2, resolved: 'https://navigation-fetch.test/', error: 'offline'}
	app.poll_navigation()
	assert !app.has_navigation_fetch_in_flight()
	app.navigation_fetch_generation = 2
	app.navigation_generation++
	assert !app.has_navigation_fetch_in_flight()
}

fn test_page_dependency_wait_blocks_idle_collection_then_keeps_cleanup_available() {
	mut app := navigation_fetch_state_app()
	defer { app.document.finalize() }
	app.pending_page_preload = PendingPagePreload{
		generation: app.navigation_generation
		remaining: 1
		results: chan PreloadedResource{cap: 1}
	}
	app.release_unused_memory_if_idle(3_000_000_000)
	assert app.memory_maintenance.pending_document_work
	assert app.memory_maintenance.next_check_ns == 0
	app.pending_page_preload = none
	app.release_unused_memory_if_idle(4_000_000_000)
	$if gcboehm ? {
		assert !app.memory_maintenance.pending_document_work
	} $else {
		assert app.memory_maintenance.pending_document_work
	}
}

module main

import gg
import net
import os
import page
import time

struct NavigationCommitCache {
	path     string
	previous ?string
}

fn navigation_commit_cache() NavigationCommitCache {
	cache := NavigationCommitCache{
		path:     os.join_path(os.temp_dir(), 'vox-navigation-commit-${os.getpid()}-${time.sys_mono_now()}')
		previous: os.getenv_opt('LADYBIRD_CACHE_DIR')
	}
	os.setenv('LADYBIRD_CACHE_DIR', cache.path, true)
	return cache
}

fn (cache NavigationCommitCache) cleanup() {
	if previous := cache.previous {
		os.setenv('LADYBIRD_CACHE_DIR', previous, true)
	} else {
		os.unsetenv('LADYBIRD_CACHE_DIR')
	}
	os.rmdir_all(cache.path) or {}
}

fn navigation_commit_app() !&BrowserApp {
	owner := page.Page.create(1)!
	return &BrowserApp{
		page_model:                  owner
		script_policy:               .disabled
		viewport_width:              320
		viewport_height:             200
		navigation_results:          chan NavigationResult{cap: 4}
		background_resource_results: chan PreloadedResource{cap: 4}
	}
}

fn serve_navigation_commit(mut listener net.TcpListener, requested chan bool, release chan bool, response string) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	socket.set_read_timeout(5 * time.second)
	mut bytes := []u8{len: 4096}
	socket.read(mut bytes) or { panic(err) }
	requested <- true
	select {
		_ := <-release {
		}
		5 * time.second {
			panic('navigation response was never released')
		}
	}
	socket.write_string(response) or { panic(err) }
}

fn navigation_commit_response(body string) string {
	return 'HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}'
}

fn finish_navigation_commit(mut app BrowserApp) {
	deadline := time.sys_mono_now() + 5 * time.second
	for app.has_navigation_fetch_in_flight() && app.navigation_results.len == 0 && time.sys_mono_now() < deadline {
		time.sleep(time.millisecond)
	}
	assert app.navigation_results.len > 0
	app.poll_navigation_and_background_resources()
	assert !app.has_navigation_fetch_in_flight()
	preload_pending := app.pending_page_preload != none
	assert !preload_pending
}

fn test_cached_url_keeps_current_page_active_then_commits_network_response_once() {
	cache := navigation_commit_cache()
	defer { cache.cleanup() }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}/next'
	cache_loaded_page(LoadedPage{ url: address, markup: '<!doctype html><p id="stale">Stale page</p>', content_type: 'text/html' })
	requested := chan bool{cap: 1}
	release := chan bool{cap: 1}
	server := spawn serve_navigation_commit(mut listener, requested, release,
		navigation_commit_response('<!doctype html><p id="fresh">Fresh page</p>'))
	mut app := navigation_commit_app()!
	app.install_loaded_page(LoadedPage{ url: 'https://previous.test/', markup: '<!doctype html><p id="previous">Previous page</p>', content_type: 'text/html' }, true)
	mut previous := app.document
	defer {
		app.document.finalize()
		previous.finalize()
	}
	app.document_presented = true
	app.initial_window_frame_presented = true
	app.scroll_y = 42
	app.ctx = &gg.Context{}
	app.navigate(address, true)
	assert app.pending_navigation == none
	assert <-requested
	app.poll_navigation_and_background_resources()
	assert voidptr(app.document) == voidptr(previous)
	assert previous.is_fully_active()
	assert app.scroll_y == 42
	assert app.address == 'https://previous.test/'
	assert app.history.len == 1 && app.history_index == 0
	assert !app.snapshot_visible
	assert !app.paint_commands.any(it.text.contains('Stale page'))
	release <- true
	server.wait()
	finish_navigation_commit(mut app)
	fresh_present := app.document.get_element_by_id('fresh') != none
	assert fresh_present
	stale_present := app.document.get_element_by_id('stale') != none
	assert !stale_present
	assert app.history.len == 2 && app.history_index == 1
	assert app.history[1].url == address
	assert app.history[1].markup == app.markup
	committed := voidptr(app.document)
	app.poll_navigation_and_background_resources()
	assert voidptr(app.document) == committed
	assert app.history.len == 2
}

fn test_startup_with_cached_url_waits_for_network_without_installing_cached_document() {
	cache := navigation_commit_cache()
	defer { cache.cleanup() }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}/startup'
	cache_loaded_page(LoadedPage{ url: address, markup: '<!doctype html><p id="stale">Stale startup</p>', content_type: 'text/html' })
	requested := chan bool{cap: 1}
	release := chan bool{cap: 1}
	server := spawn serve_navigation_commit(mut listener, requested, release,
		navigation_commit_response('<!doctype html><p id="fresh">Fresh startup</p>'))
	mut app := navigation_commit_app()!
	defer { app.document.finalize() }
	app.ctx = &gg.Context{}
	app.navigate(address, true)
	assert voidptr(app.document) == unsafe { nil }
	assert app.pending_navigation?.resolved == address
	assert app.history.len == 0
	assert !app.has_navigation_fetch_in_flight()
	// The first chrome frame starts the fetch; it never installs a cache preview.
	app.initial_window_frame_presented = true
	app.start_pending_navigation()
	assert <-requested
	app.poll_navigation_and_background_resources()
	assert voidptr(app.document) == unsafe { nil }
	release <- true
	server.wait()
	finish_navigation_commit(mut app)
	fresh_present := app.document.get_element_by_id('fresh') != none
	assert fresh_present
	assert app.history.len == 1
	assert app.history[0].markup == app.markup
}

fn test_reload_commits_even_identical_response_and_preserves_history_entry() {
	cache := navigation_commit_cache()
	defer { cache.cleanup() }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}/reload'
	markup := '<!doctype html><p id="fresh">Original content</p>'
	cache_loaded_page(LoadedPage{ url: address, markup: markup, content_type: 'text/html' })
	requested := chan bool{cap: 1}
	release := chan bool{cap: 1}
	server := spawn serve_navigation_commit(mut listener, requested, release, navigation_commit_response(markup))
	mut app := navigation_commit_app()!
	app.install_loaded_page(LoadedPage{ url: address, markup: markup, content_type: 'text/html' }, true)
	mut previous := app.document
	defer {
		app.document.finalize()
		previous.finalize()
	}
	previous.get_element_by_id('fresh')?.as_node().set_text_content('Changed after load')!
	app.document_presented = true
	app.initial_window_frame_presented = true
	app.ctx = &gg.Context{}
	app.reload()
	assert app.pending_navigation == none
	assert <-requested
	assert voidptr(app.document) == voidptr(previous)
	assert app.document.get_element_by_id('fresh')?.as_node().text_content()? == 'Changed after load'
	release <- true
	server.wait()
	finish_navigation_commit(mut app)
	assert voidptr(app.document) != voidptr(previous)
	assert app.document.get_element_by_id('fresh')?.as_node().text_content()? == 'Original content'
	assert app.history.len == 1 && app.history_index == 0
	assert app.history[0].markup == markup
}

fn test_failed_navigation_to_cached_url_commits_error_instead_of_stale_page() {
	cache := navigation_commit_cache()
	defer { cache.cleanup() }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}/unavailable'
	cache_loaded_page(LoadedPage{ url: address, markup: '<!doctype html><p id="stale">Stale page</p>', content_type: 'text/html' })
	requested := chan bool{cap: 1}
	release := chan bool{cap: 1}
	server := spawn serve_navigation_commit(mut listener, requested, release,
		'HTTP/1.1 503 Service Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n')
	mut app := navigation_commit_app()!
	defer { app.document.finalize() }
	app.ctx = &gg.Context{}
	app.initial_window_frame_presented = true
	app.navigate(address, true)
	assert <-requested
	assert voidptr(app.document) == unsafe { nil }
	release <- true
	server.wait()
	finish_navigation_commit(mut app)
	assert app.load_status == 'Navigation error'
	assert app.markup.contains('HTTP 503 Service Unavailable')
	stale_present := app.document.get_element_by_id('stale') != none
	assert !stale_present
	assert app.history.len == 1 && app.history[0].url == address
}

fn check_ready_navigation_installs_before_outgoing_background_resources(background_tab bool) ! {
	mut app := navigation_commit_app()!
	app.navigation_generation = 4
	app.install_loaded_page(LoadedPage{ url: 'https://previous.test/', markup: '<!doctype html><p>Previous</p>', content_type: 'text/html' }, false)
	app.background_resource_pending['https://previous.test/image.jpg'] = true
	mut previous := app.document
	defer {
		app.document.finalize()
		previous.finalize()
	}
	// A ready response need not wait for the outgoing document to paint.
	assert !app.document_presented
	app.navigation_results <- NavigationResult{
		generation:  4
		add_history: true
		loaded:      LoadedPage{ url: 'https://next.test/', markup: '<!doctype html><p id="fresh">Fresh</p>', content_type: 'text/html' }
	}
	app.background_resource_results <- PreloadedResource{ url: 'https://previous.test/image.jpg', error: 'not fetched', request_type: 'image' }
	if background_tab {
		app.poll_background_browser_tab()
	} else {
		app.poll_navigation_and_background_resources()
	}
	fresh_present := app.document.get_element_by_id('fresh') != none
	assert fresh_present
	assert app.background_resource_results.len == 1
	app.poll_navigation_and_background_resources()
	assert app.background_resource_results.len == 0
}

fn test_ready_navigation_installs_before_outgoing_background_resources() {
	check_ready_navigation_installs_before_outgoing_background_resources(false)!
}

fn test_background_tab_installs_ready_navigation_before_outgoing_resources() {
	check_ready_navigation_installs_before_outgoing_background_resources(true)!
}

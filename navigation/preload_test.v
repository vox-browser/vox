module main

import encoding.base64
import net
import html
import os
import page
import time

fn serve_gated_navigation_resource(mut listener net.TcpListener, requested chan bool,
	release chan bool, finished chan bool, response string) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	socket.set_read_timeout(5 * time.second)
	mut input := []u8{len: 4096}
	_ := socket.read(mut input) or { panic(err) }
	requested <- true
	select {
		_ := <-release {
		}
		5 * time.second {
			panic('navigation resource was never released')
		}
	}
	socket.write_string(response) or { panic(err) }
	finished <- true
}

fn navigation_preload_test_app() &BrowserApp {
	mut owner := page.Page.create(1) or { panic(err) }
	mut app := &BrowserApp{ page_model: owner, script_policy: .disabled, viewport_width: 320, viewport_height: 200, background_resource_results: chan PreloadedResource{cap: 32} }
	app.install_loaded_page(LoadedPage{
		url:          'https://www.wikipedia.org/'
		markup:       '<!doctype html><p id="old">Current page</p>'
		content_type: 'text/html'
	}, false)
	return app
}

fn finish_navigation_preload(mut app BrowserApp) {
	deadline := time.sys_mono_now() + 5 * time.second
	for app.pending_page_preload != none && time.sys_mono_now() < deadline {
		app.poll_page_preload()
		time.sleep(time.millisecond)
	}
	assert app.pending_page_preload == none
}

fn test_navigation_keeps_current_document_active_while_stylesheet_is_blocked() {
	cache := os.join_path(os.temp_dir(), 'vox-navigation-preload-${os.getpid()}-${time.sys_mono_now()}')
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous {
			os.setenv('LADYBIRD_CACHE_DIR', value, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.rmdir_all(cache) or {}
	}
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}'
	requested := chan bool{cap: 1}
	release := chan bool{cap: 1}
	finished := chan bool{cap: 1}
	body := '#next{width:73px;color:rgb(17,34,51)}'
	spawn serve_gated_navigation_resource(mut listener, requested, release, finished,
		'HTTP/1.1 200 OK\r\nContent-Type: text/css\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}')
	mut app := navigation_preload_test_app()
	mut old := app.document
	app.start_page_preload(LoadedPage{
		url:          'https://it.wikipedia.org/wiki/Pagina_principale'
		markup:       '<!doctype html><base href="${address}/assets/"><link rel="stylesheet" href="screen.css"><p id="next">Italian page</p>'
		content_type: 'text/html'
	}, true)
	assert <-requested
	app.poll_page_preload()
	assert app.pending_page_preload != none
	assert voidptr(app.document) == voidptr(old)
	assert old.is_fully_active()
	assert app.address == 'https://www.wikipedia.org/'
	_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointermove', 0, 15, 15)
	assert app.document.get_element_by_id('old') != none
	// Completion remains gated until after the native input and poll returned.
	release <- true
	assert <-finished
	finish_navigation_preload(mut app)
	assert voidptr(app.document) != voidptr(old)
	assert app.address == 'https://it.wikipedia.org/wiki/Pagina_principale'
	assert app.document.get_element_by_id('next')?.get_bounding_client_rect().width == 73
	assert app.history.len == 1 && app.history[0].url == app.address
	assert app.navigation_preloaded_resources.len == 0
	assert app.resource_cache['${address}/assets/screen.css'].body == body
	mut document := app.document
	document.finalize()
	old.finalize()
}

fn test_failed_navigation_preload_is_consumed_without_synchronous_retry() {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}'
	requested := chan bool{cap: 1}
	release := chan bool{cap: 1}
	finished := chan bool{cap: 1}
	spawn serve_gated_navigation_resource(mut listener, requested, release, finished,
		'HTTP/1.1 503 Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n')
	mut app := navigation_preload_test_app()
	mut old := app.document
	app.start_page_preload(LoadedPage{
		url:          '${address}/failed'
		markup:       '<!doctype html><link rel="stylesheet" href="slow.css"><p id="next">Resource failed, page usable</p>'
		content_type: 'text/html'
	}, true)
	assert <-requested
	app.poll_page_preload()
	assert voidptr(app.document) == voidptr(old)
	release <- true
	assert <-finished
	finish_navigation_preload(mut app)
	assert app.document.get_element_by_id('next') != none
	assert app.js_messages.any(it.contains('HTTP 503'))
	assert app.paint_commands.any(it.text.contains('Resource failed'))
	// A retry would be queued on this same listener and leave install blocked.
	listener.set_accept_timeout(30 * time.millisecond)
	mut retried := false
	if mut socket := listener.accept() {
		retried = true
		socket.close() or {}
	}
	assert !retried
	mut document := app.document
	document.finalize()
	old.finalize()
}

fn test_superseded_navigation_preload_cannot_replace_current_page() {
	mut app := navigation_preload_test_app()
	mut old := app.document
	results := chan PreloadedResource{cap: 1}
	app.pending_page_preload = PendingPagePreload{
		loaded:     LoadedPage{ url: 'https://it.wikipedia.org/', markup: '<p id="stale">Stale</p>' }
		generation: app.navigation_generation
		results:    results
		remaining:  1
	}
	app.navigation_generation++
	results <- PreloadedResource{ url: 'https://it.wikipedia.org/old.css', body: 'p{color:red}' }
	app.poll_page_preload()
	assert app.pending_page_preload == none
	assert voidptr(app.document) == voidptr(old)
	assert app.resource_cache.len == 0
	assert app.history.len == 0
	mut document := app.document
	document.finalize()
}

fn test_preloaded_image_survives_a_full_reusable_cache_without_a_second_request() {
	mut app := navigation_preload_test_app()
	mut old := app.document
	for index in 0 .. max_cached_resources {
		app.resource_cache['https://cache.test/${index}'] = PreloadedResource{ url: 'https://cache.test/${index}', body: 'existing' }
	}
	image_url := 'http://127.0.0.1:9/ready.png'
	pixels := base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=').bytestr()
	results := chan PreloadedResource{cap: 1}
	app.pending_page_preload = PendingPagePreload{
		loaded:     LoadedPage{ url: 'https://it.wikipedia.org/', markup: '<!doctype html><p id="next">Ready</p><img width="1" height="1" src="${image_url}">' }
		generation: app.navigation_generation
		results:    results
		remaining:  1
	}
	results <- PreloadedResource{ url: image_url, body: pixels, source_url: 'https://it.wikipedia.org/', final_url: image_url, request_type: 'image' }
	app.poll_page_preload()
	assert app.pending_page_preload == none
	assert app.document.get_element_by_id('next') != none
	assert app.js_messages == []
	assert app.resource_cache.len == max_cached_resources
	assert app.background_image_bytes(image_url)!.bytestr() == pixels
	assert app.navigation_preloaded_resources.len == 0
	mut document := app.document
	document.finalize()
	old.finalize()
}

fn test_navigation_resource_discovery_is_inert_and_matches_noscript_policy() {
	windows_before := html.all_windows().len
	loaded := LoadedPage{
		url:    'https://it.wikipedia.org/dir/page'
		markup: '<!doctype html><base href="../assets/"><script type="importmap">{"imports":{"x":"./x.js"}}</script><script src="active.js"></script><noscript><link rel="stylesheet" href="fallback.css"><img src="fallback.png"></noscript>'
	}
	mut scripted := parse_page_preload_document(loaded, true)
	defer { scripted.finalize() }
	assert scripted.base_url().serialize() == 'https://it.wikipedia.org/assets/'
	assert document_preload_resource_urls(scripted, scripted.base_url().serialize()) == ['https://it.wikipedia.org/assets/active.js']
	assert scripted.get_window() == none
	mut nonscripted := parse_page_preload_document(loaded, false)
	defer { nonscripted.finalize() }
	assert document_preload_resource_urls(nonscripted, nonscripted.base_url().serialize()) == [
		'https://it.wikipedia.org/assets/fallback.css',
		'https://it.wikipedia.org/assets/fallback.png',
	]
	assert nonscripted.get_window() == none
	assert html.all_windows().len == windows_before
}

fn test_live_refresh_preserves_pending_cached_navigation_history() {
	mut app := navigation_preload_test_app()
	mut old := app.document
	app.history = [HistoryEntry{ url: app.address, markup: app.markup }]
	app.history_index = 0
	app.pending_page_preload = PendingPagePreload{
		loaded:      LoadedPage{ url: 'https://it.wikipedia.org/', markup: '<p>Cached</p>' }
		add_history: true
		generation:  app.navigation_generation
		results:     chan PreloadedResource{cap: 1}
		remaining:   1
	}
	app.prepare_loaded_page(LoadedPage{ url: 'https://it.wikipedia.org/', markup: '<p id="next">Fresh</p>' }, false)
	assert app.history.len == 2
	assert app.history_index == 1
	assert app.history[0].url == 'https://www.wikipedia.org/'
	assert app.history[1].url == 'https://it.wikipedia.org/'
	assert app.history[1].markup.contains('Fresh')
	assert app.document.get_element_by_id('next') != none
	mut document := app.document
	document.finalize()
	old.finalize()
}

fn test_async_navigation_does_not_wait_for_hidden_image_response() {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}'
	requested := chan bool{cap: 1}
	release := chan bool{cap: 1}
	finished := chan bool{cap: 1}
	pixels := base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=').bytestr()
	spawn serve_gated_navigation_resource(mut listener, requested, release, finished,
		'HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: ${pixels.len}\r\nConnection: close\r\n\r\n${pixels}')
	mut app := navigation_preload_test_app()
	mut old := app.document
	app.start_page_preload(LoadedPage{
		url:    'https://it.wikipedia.org/'
		markup: '<!doctype html><p id="next">Ready</p><dialog><img width="1" height="1" src="${address}/hidden.png"></dialog>'
	}, true)
	app.poll_page_preload()
	assert app.pending_page_preload == none
	assert app.document.get_element_by_id('next') != none
	assert app.paint_commands.any(it.text.contains('Ready'))
	assert <-requested
	release <- true
	assert <-finished
	deadline := time.sys_mono_now() + 5 * time.second
	for app.document.anything_is_delaying_the_load_event() && time.sys_mono_now() < deadline {
		app.poll_browser_image_requests()
		time.sleep(time.millisecond)
	}
	assert !app.document.anything_is_delaying_the_load_event()
	assert app.image_request_loader?.pending.len == 0
	mut document := app.document
	document.finalize()
	old.finalize()
}

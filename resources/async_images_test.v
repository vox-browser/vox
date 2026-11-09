module main

import adblock
import encoding.base64
import html
import net
import os
import page
import time

const async_browser_image_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='

fn serve_async_browser_image(mut listener net.TcpListener, requested chan bool, release chan bool, finished chan bool) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	socket.set_read_timeout(5 * time.second)
	mut input := []u8{len: 4096}
	_ := socket.read(mut input) or { panic(err) }
	requested <- true
	select {
		_ := <-release {}
		5 * time.second { panic('image response was never released') }
	}
	pixels := base64.decode(async_browser_image_png).bytestr()
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: ${pixels.len}\r\nConnection: close\r\n\r\n${pixels}') or { panic(err) }
	finished <- true
}

fn test_search_document_paints_and_runs_scripts_while_shared_thumbnail_response_is_blocked() {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}'
	requested := chan bool{cap: 1}
	release := chan bool{cap: 1}
	finished := chan bool{cap: 1}
	spawn serve_async_browser_image(mut listener, requested, release, finished)
	owner := page.Page.create(1)!
	mut app := &BrowserApp{page_model: owner, script_policy: .enabled, viewport_width: 320, viewport_height: 200}
	app.start_page_preload(LoadedPage{
		url: '${address}/search'
		markup: '<!doctype html><p>Search results are ready</p><input id="query"><img id="one" src="/shared.png" width="1" height="1"><img id="two" src="/shared.png" width="1" height="1"><script>globalThis.ran=true;globalThis.loaded=0;window.addEventListener("load",()=>loaded++);</script>'
		content_type: 'text/html'
	}, true)
	app.poll_page_preload()
	defer { app.js_runtime.close(); app.document.finalize() }
	assert app.pending_page_preload == none
	assert app.paint_commands.any(it.text.contains('Search results are ready'))
	assert app.js_runtime.evaluate_host('ran&&!one.complete&&!two.complete&&loaded===0')! == 'true'
	assert app.document.anything_is_delaying_the_load_event()
	assert <-requested
	loader := app.image_request_loader or { panic('missing native image loader') }
	assert loader.pending.len == 1
	for _, callbacks in loader.pending { assert callbacks.len == 2 }
	// Neither painting nor script bindings wait for this response. Loading
	// completes once for the shared URL and updates both native image models.
	release <- true
	assert <-finished
	deadline := time.sys_mono_now() + 5 * time.second
	for app.document.anything_is_delaying_the_load_event() && time.sys_mono_now() < deadline {
		app.poll_browser_image_requests()
		time.sleep(time.millisecond)
	}
	app.poll_browser_image_requests()
	app.poll_javascript_tasks()
	assert app.js_runtime.evaluate_host('JSON.stringify([one.complete,two.complete,one.naturalWidth,two.naturalWidth,loaded])')! == '[true,true,1,1,1]'
	assert loader.pending.len == 0 && !app.document.anything_is_delaying_the_load_event()
	listener.set_accept_timeout(30 * time.millisecond)
	if mut extra := listener.accept() {
		extra.close() or {}
		assert false, 'duplicate thumbnail request'
	}
}

fn test_cached_image_keeps_its_natural_dimensions_in_the_first_layout() {
	owner := page.Page.create(1)!
	resource_url := 'https://async-native-image.test/cached.png'
	mut app := &BrowserApp{
		page_model: owner
		script_policy: .enabled
		viewport_width: 320
		viewport_height: 200
		navigation_preloaded_resources: {
			resource_url: PreloadedResource{url: resource_url, body: base64.decode(async_browser_image_png).bytestr(), request_type: 'image'}
		}
	}
	app.install_loaded_page(LoadedPage{
		url: 'https://async-native-image.test/'
		markup: '<!doctype html><img id="thumbnail" src="/cached.png"><script>globalThis.initialWidth=thumbnail.naturalWidth</script>'
		content_type: 'text/html'
	}, false)
	defer { app.js_runtime.close(); app.document.finalize() }
	assert app.js_runtime.evaluate_host('initialWidth===1&&thumbnail.complete')! == 'true'
	assert app.document.get_element_by_id('thumbnail')?.get_bounding_client_rect().width == 1
	assert !app.document.anything_is_delaying_the_load_event()
}

// JPEG and WebP replay decodes the response bytes, not the image model. A
// synchronous disk-cache hit must leave them where replay looks, or the first
// frame requests the image again and repaints the document when it arrives.
fn test_static_disk_cached_image_response_reaches_the_replay_cache_before_paint() {
	previous_cache := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-disk-image-retention-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous_cache { os.setenv('LADYBIRD_CACHE_DIR', value, true) }
		else { os.unsetenv('LADYBIRD_CACHE_DIR') }
		os.rmdir_all(cache) or {}
	}
	resource_url := 'https://async-native-image.test/thumb.png?width=140&s=1'
	pixels := base64.decode(async_browser_image_png).bytestr()
	cache_resource_response_headers_with_status(resource_url, resource_url, pixels,
		[adblock.ResponseHeader{name: 'content-type', value: 'image/png'},
			adblock.ResponseHeader{name: 'cache-control', value: 'public, max-age=60'},
			adblock.ResponseHeader{name: 'date', value: time.utc().http_header_string()}], 200)
	owner := page.Page.create(1)!
	mut app := &BrowserApp{page_model: owner, script_policy: .disabled, viewport_width: 320, viewport_height: 200}
	app.install_loaded_page(LoadedPage{
		url: 'https://async-native-image.test/listing'
		markup: '<!doctype html><img id="thumb" src="/thumb.png?width=140&amp;s=1" width="1" height="1">'
		content_type: 'text/html'
	}, false)
	defer { app.document.finalize() }
	assert app.js_runtime == unsafe { nil }
	loader := app.image_request_loader or { panic('missing native image loader') }
	// The disk cache answered the request synchronously; nothing is in flight.
	assert loader.pending.len == 0 && loader.queued.len == 0
	assert app.document.get_element_by_id('thumb')?.get_bounding_client_rect().width == 1
	app.poll_browser_image_requests()
	retained := app.resource_cache[resource_url] or { panic('disk-cached image response was not retained') }
	assert retained.body == pixels && retained.error == '' && retained.request_type == 'image'
	assert loader.disk_cache_responses.len == 0
	assert app.background_resource_pending.len == 0
}

fn test_superseded_native_image_completion_cannot_mutate_replacement_document() {
	owner := page.Page.create(1)!
	mut app := &BrowserApp{page_model: owner, script_policy: .enabled, viewport_width: 320, viewport_height: 200}
	app.install_loaded_page(LoadedPage{
		url: 'https://async-native-image.test/'
		markup: '<!doctype html><p id="old">Old document</p><script>globalThis.ran=true</script>'
	}, false)
	mut old := app.document
	mut loader := app.image_request_loader or { panic('missing loader') }
	mut marker := &AsyncImageCompletionMarker{}
	key := old.url.serialize() + '\nhttps://async-native-image.test/stale.png'
	on_complete := fn [marker] (_ ?html.DecodedImageData) {
		mut mutable_marker := unsafe { &AsyncImageCompletionMarker(marker) }
		mutable_marker.called = true
	}
	loader.pending[key] = [html.HTMLImageFetchCompletion(on_complete)]
	app.install_loaded_page(LoadedPage{
		url: 'https://async-native-image.test/replacement'
		markup: '<!doctype html><p id="new">Replacement document</p>'
	}, false)
	defer { app.document.finalize(); old.finalize() }
	loader.results <- PreloadedResource{url: 'https://async-native-image.test/stale.png', source_url: old.url.serialize(), body: base64.decode(async_browser_image_png).bytestr()}
	app.poll_browser_image_requests()
	assert !marker.called
	assert app.document.get_element_by_id('new') != none
}

@[heap]
struct AsyncImageCompletionMarker {
mut:
	called bool
}

fn test_failed_script_preload_does_not_suppress_image_request_for_the_same_url() {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}'
	requested := chan bool{cap: 1}
	release := chan bool{cap: 1}
	finished := chan bool{cap: 1}
	spawn serve_async_browser_image(mut listener, requested, release, finished)
	owner := page.Page.create(1)!
	resource_url := '${address}/mixed'
	mut app := &BrowserApp{
		page_model: owner
		script_policy: .enabled
		viewport_width: 320
		viewport_height: 200
		navigation_preloaded_resources: {
			resource_url: PreloadedResource{url: resource_url, source_url: '${address}/search', error: 'Script response rejected', request_type: 'script'}
		}
	}
	app.install_loaded_page(LoadedPage{
		url: '${address}/search'
		markup: '<!doctype html><script src="/mixed"></script><img id="thumbnail" src="/mixed"><script>globalThis.ran=true</script>'
		content_type: 'text/html'
	}, false)
	defer { app.js_runtime.close(); app.document.finalize() }
	assert app.js_runtime.evaluate_host('ran&&!thumbnail.complete')! == 'true'
	assert <-requested
	release <- true
	assert <-finished
	deadline := time.sys_mono_now() + 5 * time.second
	for app.document.anything_is_delaying_the_load_event() && time.sys_mono_now() < deadline {
		app.poll_browser_image_requests()
		time.sleep(time.millisecond)
	}
	assert app.js_runtime.evaluate_host('thumbnail.complete&&thumbnail.naturalWidth===1')! == 'true'
}

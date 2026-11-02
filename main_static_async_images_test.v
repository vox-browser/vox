module main

import dom
import encoding.base64
import html
import net
import page
import time

const static_async_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='

fn serve_static_async_image(mut listener net.TcpListener, requested chan bool,
	release chan bool, finished chan bool, fail bool) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	socket.set_read_timeout(5 * time.second)
	mut input := []u8{len: 4096}
	_ := socket.read(mut input) or { panic(err) }
	requested <- true
	select {
		_ := <-release {}
		5 * time.second { panic('static image response was never released') }
	}
	response := if fail {
		'HTTP/1.1 503 Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'
	} else {
		body := base64.decode(static_async_png).bytestr()
		'HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}'
	}
	socket.write_string(response) or { panic(err) }
	finished <- true
}

fn static_async_model(document &dom.Document, id string) &html.HTMLImageElementModel {
	image := document.get_element_by_id(id) or { panic('missing image ${id}') }
	return html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(image) })
}

fn test_static_article_paints_before_shared_image_success_or_failure() {
	for fail in [false, true] {
		mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
		listener.set_accept_timeout(5 * time.second)
		defer { listener.close() or {} }
		address := 'http://${listener.addr()!}'
		requested := chan bool{cap: 1}
		release := chan bool{cap: 1}
		finished := chan bool{cap: 1}
		spawn serve_static_async_image(mut listener, requested, release, finished, fail)
		owner := page.Page.create(1)!
		mut app := &BrowserApp{page_model: owner, script_policy: .disabled, viewport_width: 320, viewport_height: 200}
		app.start_page_preload(LoadedPage{
			url: '${address}/article'
			markup: '<!doctype html><title>Article</title><p>Article text is ready</p><img id="one" src="/shared.png"><img id="two" loading="lazy" src="/shared.png">'
			content_type: 'text/html'
		}, true)
		app.poll_page_preload()
		defer { if mut loader := app.image_request_loader { loader.cancel() }; app.document.finalize() }
		assert app.pending_page_preload == none
		assert app.js_runtime == unsafe { nil }
		assert app.paint_commands.any(it.text.contains('Article text is ready'))
		assert app.document.anything_is_delaying_the_load_event()
		assert !app.document_resources_ready_for_capture()
		one := static_async_model(app.document, 'one')
		two := static_async_model(app.document, 'two')
		assert !one.complete() && !two.complete()
		assert <-requested
		loader := app.image_request_loader or { panic('missing static image loader') }
		assert loader.pending.len == 1 && loader.active_fetches == 1
		assert loader.deferred_lazy_images.len == 0
		for _, callbacks in loader.pending { assert callbacks.len == 2 }
		// Releasing only after paint proves the first frame cannot wait for the
		// response or its timeout. Scripting-disabled lazy images remain eager.
		release <- true
		assert <-finished
		deadline := time.sys_mono_now() + 5 * time.second
		for loader.pending.len > 0 && time.sys_mono_now() < deadline {
			app.poll_browser_image_requests()
			time.sleep(time.millisecond)
		}
		assert loader.pending.len == 0 && loader.active_fetches == 0
		assert !app.document.anything_is_delaying_the_load_event()
		assert one.complete() && two.complete()
		assert one.natural_width() == if fail { 0 } else { 1 }
		assert two.natural_width() == one.natural_width()
		assert one.event_count(if fail { 'error' } else { 'load' }) == 1
		assert two.event_count(if fail { 'error' } else { 'load' }) == 1
		app.relayout(320, 200 + app.chrome_height())
		if !fail {
			assert app.document.get_element_by_id('one')?.get_bounding_client_rect().width == 1
			images := app.paint_commands.filter(it.kind == 'draw_replaced_image')
			assert images.len == 2
			for command in images {
				bitmap := command.replaced_image_bitmap or { panic('missing completed image pixels') }
				assert bitmap.width == 1 && bitmap.height == 1
			}
		}
		listener.set_accept_timeout(30 * time.millisecond)
		if mut duplicate := listener.accept() {
			duplicate.close() or {}
			assert false, 'shared static image was requested more than once'
		}
	}
}

fn test_static_cached_image_keeps_intrinsic_size_in_the_first_layout() {
	owner := page.Page.create(1)!
	address := 'https://static-async-image.test/cached.png'
	mut app := &BrowserApp{
		page_model: owner
		script_policy: .disabled
		viewport_width: 320
		viewport_height: 200
		navigation_preloaded_resources: {
			address: PreloadedResource{url: address, body: base64.decode(static_async_png).bytestr(), request_type: 'image'}
		}
	}
	app.install_loaded_page(LoadedPage{
		url: 'https://static-async-image.test/article'
		markup: '<!doctype html><p>Cached article</p><img id="image" src="/cached.png">'
	}, false)
	defer { if mut loader := app.image_request_loader { loader.cancel() }; app.document.finalize() }
	assert app.js_runtime == unsafe { nil }
	model := static_async_model(app.document, 'image')
	assert model.complete() && model.natural_width() == 1
	assert model.event_count('load') == 1
	assert app.document.get_element_by_id('image')?.get_bounding_client_rect().width == 1
	assert app.image_request_loader?.pending.len == 0
	assert !app.document.anything_is_delaying_the_load_event()
}

fn test_static_image_completion_is_discarded_after_navigation() {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}'
	requested := chan bool{cap: 1}
	release := chan bool{cap: 1}
	finished := chan bool{cap: 1}
	spawn serve_static_async_image(mut listener, requested, release, finished, false)
	owner := page.Page.create(1)!
	mut app := &BrowserApp{page_model: owner, script_policy: .disabled, viewport_width: 320, viewport_height: 200}
	app.install_loaded_page(LoadedPage{
		url: '${address}/article'
		markup: '<!doctype html><p>Old article</p><img id="image" src="/stale.png">'
	}, false)
	mut old := app.document
	model := static_async_model(old, 'image')
	loader := app.image_request_loader or { panic('missing old image loader') }
	assert <-requested
	app.install_loaded_page(LoadedPage{
		url: '${address}/replacement'
		markup: '<!doctype html><p id="replacement">Replacement article</p>'
	}, false)
	defer { app.document.finalize(); old.finalize() }
	assert loader.cancelled && loader.pending.len == 0
	release <- true
	assert <-finished
	deadline := time.sys_mono_now() + 5 * time.second
	for loader.results.len == 0 && time.sys_mono_now() < deadline { time.sleep(time.millisecond) }
	assert loader.results.len == 1
	app.poll_browser_image_requests()
	assert model.event_count('load') == 0 && model.event_count('error') == 0
	assert app.document.get_element_by_id('replacement') != none
	assert app.paint_commands.any(it.text.contains('Replacement article'))
	assert app.image_request_loader?.pending.len == 0
}

fn test_static_svg_image_resource_shared_with_html_image_retains_preload_barrier() {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}'
	requested := chan bool{cap: 1}
	release := chan bool{cap: 1}
	finished := chan bool{cap: 1}
	spawn serve_static_async_image(mut listener, requested, release, finished, false)
	owner := page.Page.create(1)!
	mut app := &BrowserApp{page_model: owner, script_policy: .disabled, viewport_width: 320, viewport_height: 200}
	app.install_loaded_page(LoadedPage{url: '${address}/old', markup: '<!doctype html><p>Old page</p>'}, false)
	mut old := app.document
	app.start_page_preload(LoadedPage{
		url: '${address}/svg'
		markup: '<!doctype html><p>SVG paint resource</p><svg xmlns="http://www.w3.org/2000/svg"><image href="/shared.png" width="1" height="1"/></svg><img id="shared" src="/shared.png">'
	}, true)
	app.poll_page_preload()
	assert <-requested
	assert app.pending_page_preload != none
	assert voidptr(app.document) == voidptr(old)
	release <- true
	assert <-finished
	deadline := time.sys_mono_now() + 5 * time.second
	for app.pending_page_preload != none && time.sys_mono_now() < deadline {
		app.poll_page_preload()
		time.sleep(time.millisecond)
	}
	defer { if mut loader := app.image_request_loader { loader.cancel() }; app.document.finalize(); old.finalize() }
	assert app.pending_page_preload == none
	assert app.address == '${address}/svg'
	assert static_async_model(app.document, 'shared').natural_width() == 1
	assert app.image_request_loader?.pending.len == 0
}

fn test_static_svg_preloads_resolve_base_and_prefer_href_over_xlink() {
	mut document := parse_page_preload_document(LoadedPage{
		url: 'https://en.wikipedia.org/wiki/Article'
		markup: '<!doctype html><base href="/assets/"><img src="ordinary.png"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"><image href="primary.png" xlink:href="ignored.png"/><filter><feImage xlink:href="filter.png"/></filter><image href="" xlink:href="also-ignored.png"/></svg>'
	}, false)
	defer { document.finalize() }
	urls := document_svg_image_preload_urls(document, document.base_url().serialize())
	assert urls.len == 2
	assert 'https://en.wikipedia.org/assets/primary.png' in urls
	assert 'https://en.wikipedia.org/assets/filter.png' in urls
}

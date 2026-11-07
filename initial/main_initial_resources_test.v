module main

import css
import dom
import encoding.base64
import html
import net
import os
import time

fn initial_resource_test_document(markup string) &dom.Document {
	address := dom.URL{value: 'https://preload-plan.test/dir/index.html'}
	mut document := html.parse_navigation_document(markup, address, address.origin(), none) or { panic(err) }
	document.set_scripting_enabled_by_embedder(false)
	document.set_viewport_rect(dom.Rect{width: 1024, height: 768})
	return document
}

fn serve_gated_preload_image(mut listener net.TcpListener, requested chan bool, release chan bool, finished chan bool) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	socket.set_read_timeout(5 * time.second)
	mut input := []u8{len: 4096}
	_ := socket.read(mut input) or { panic(err) }
	requested <- true
	mut released := false
	select {
		_ := <-release { released = true }
		5 * time.second {}
	}
	body := base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=').bytestr()
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}') or { panic(err) }
	finished <- released
}

fn test_hidden_initial_image_fetch_starts_without_waiting_and_is_available_after_reveal() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-hidden-preload-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous { os.setenv('LADYBIRD_CACHE_DIR', value, true) } else { os.unsetenv('LADYBIRD_CACHE_DIR') }
		os.rmdir_all(cache) or {}
	}
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}'
	requested := chan bool{cap: 1}
	release := chan bool{cap: 1}
	finished := chan bool{cap: 1}
	spawn serve_gated_preload_image(mut listener, requested, release, finished)
	// Match Wikipedia's explicit badge dimensions. Remote raster intrinsic
	// sizing without an ImageHost is a separate existing shell limitation.
	mut document := initial_resource_test_document('<!doctype html><dialog id="donation"><img id="badge" loading="lazy" width="1" height="1" src="${address}/badge.png"></dialog>')
	defer { document.finalize() }
	mut app := BrowserApp{
		document: document
		viewport_width: 1024
		viewport_height: 768
		background_resource_results: chan PreloadedResource{cap: 1}
	}
	loaded := app.preload_initial_document_resources(document.base_url().serialize())
	assert loaded.len == 0
	assert '${address}/badge.png' in app.background_resource_pending
	select {
		_ := <-requested {}
		5 * time.second { assert false, 'hidden image request was not started' }
	}
	// The response remains blocked until after the initial preload call returns.
	mut dialog := document.get_element_by_id('donation') or { panic('missing dialog') }
	dialog.set_attribute_value('open', '')
	app.relayout(1024, 768 + app.chrome_height())
	before := document.layout_root
	release <- true
	resource := <-app.background_resource_results
	assert resource.error == ''
	assert resource.source_url == document.url.serialize()
	assert resource.request_type == 'image'
	assert <-finished
	app.background_resource_results <- resource
	app.poll_background_resources()
	assert app.background_resource_pending.len == 0
	assert app.nonrendered_image_preloads.len == 0
	assert voidptr(document.layout_root) != voidptr(before)
	// Paint commands use device coordinates; the badge is one CSS pixel on
	// both ordinary and Retina displays.
	scale := document.layout_coordinate_scale()
	assert app.paint_commands.any(it.kind == 'draw_replaced_image' && it.image().image_url == resource.url
		&& it.width == scale && it.height == scale)
	assert app.resource_cache[resource.url].body == resource.body
	image := document.get_element_by_id('badge') or { panic('missing image') }
	assert !css.up_to_date_computed_properties_for_element(dialog).display().is_none()
	decoded := browser_fetch_image_request(unsafe { &dom.HTMLImageElement(image) },
		html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(image) }), dom.URL{value: resource.url})!
	assert decoded.intrinsic_width() or { 0 } == 1
	assert decoded.intrinsic_height() or { 0 } == 1
}

fn test_hidden_image_completion_preserves_existing_geometry() {
	mut document := initial_resource_test_document('<!doctype html><p>visible content</p><dialog><img src="badge.png"></dialog>')
	defer { document.finalize() }
	resource_url := resolve_document_reference('badge.png', document.base_url().serialize())
	mut app := BrowserApp{
		document: document
		background_resource_results: chan PreloadedResource{cap: 1}
		background_resource_pending: {resource_url: true}
		nonrendered_image_preloads: {resource_url: true}
	}
	app.relayout(1024, 768 + app.chrome_height())
	before := document.layout_root
	app.background_resource_results <- PreloadedResource{url: resource_url, body: 'completed hidden image'}
	app.poll_background_resources()
	assert voidptr(document.layout_root) == voidptr(before)
	assert app.resource_cache[resource_url].body == 'completed hidden image'
	assert app.background_resource_pending.len == 0
	assert app.nonrendered_image_preloads.len == 0
}

fn test_initial_image_plan_uses_installed_external_styles_and_document_viewport() {
	mut document := initial_resource_test_document('<!doctype html><link rel="stylesheet" href="site.css"><img id="hidden" class="wide-hidden" src="hidden.png"><img src="visible.png">')
	defer { document.finalize() }
	base := document.base_url().serialize()
	sheet := resolve_document_reference('site.css', base)
	hidden := resolve_document_reference('hidden.png', base)
	visible := resolve_document_reference('visible.png', base)
	mut app := BrowserApp{
		document: document
		viewport_width: 1024
		viewport_height: 768
		resource_cache: {
			sheet: PreloadedResource{url: sheet, body: '@media (min-width:900px){.wide-hidden{display:none}}'}
			hidden: PreloadedResource{url: hidden, body: 'cached hidden image'}
			visible: PreloadedResource{url: visible, body: 'cached visible image'}
		}
		background_resource_results: chan PreloadedResource{cap: 1}
	}
	loaded := app.preload_initial_document_resources(base)
	assert loaded[sheet].body.contains('@media')
	assert loaded[visible].body == 'cached visible image'
	assert hidden !in loaded
	element := document.get_element_by_id('hidden') or { panic('missing image') }
	assert css.up_to_date_computed_properties_for_element(element).display().is_none()
}

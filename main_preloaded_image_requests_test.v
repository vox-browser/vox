module main

import browserjs
import dom
import encoding.base64
import html
import net
import os
import page
import time

const preloaded_image_small_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='
const preloaded_image_large_png = 'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAD0lEQVR4nGNgaGBAIOI4ANA0CAF5jtVRAAAAAElFTkSuQmCC'

fn preloaded_image_document(address string, markup string) &dom.Document {
	owner := page.Page.create(1) or { panic(err) }
	return parse_browser_navigation_document_for_page_with_response_time(markup,
		dom.URL{ value: address }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
}

fn count_preloaded_image_retries(mut listener net.TcpListener, stop chan bool, count chan int) {
	mut requests := 0
	for {
		select {
			_ := <-stop {
				break
			}
			else {
			}
		}
		mut socket := listener.accept() or { continue }
		socket.set_read_timeout(time.second)
		mut bytes := []u8{len: 4096}
		_ := socket.read(mut bytes) or { 0 }
		requests++
		socket.write_string('HTTP/1.1 503 Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n') or {}
		socket.close() or {}
	}
	count <- requests
}

fn test_script_image_binding_consumes_failed_preloads_without_network_retries() {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(10 * time.millisecond)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}'
	stop := chan bool{cap: 1}
	count := chan int{cap: 1}
	spawn count_preloaded_image_retries(mut listener, stop, count)
	owner := page.Page.create(1)!
	mut app := &BrowserApp{
		page_model:                     owner
		script_policy:                  .enabled
		viewport_width:                 320
		viewport_height:                200
		navigation_preloaded_resources: {
			'${address}/failed.png': PreloadedResource{
				url:          '${address}/failed.png'
				error:        'HTTP 503'
				source_url:   '${address}/search'
				request_type: 'image'
			}
		}
	}
	app.install_loaded_page(LoadedPage{
		url:          '${address}/search'
		content_type: 'text/html'
		markup:       '<!doctype html><img id="failed" src="/failed.png" alt="failed thumbnail"><script>globalThis.boundImage=failed;globalThis.scriptRan=true;</script>'
	}, false)
	defer {
		app.js_runtime.close()
		app.document.finalize()
	}
	assert app.js_runtime.evaluate_host('scriptRan&&boundImage.complete&&boundImage.naturalWidth===0')! == 'true'
	model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(app.document.get_element_by_id('failed')?) })
	assert model.current_request().state() == .broken
	assert !app.document.anything_is_delaying_the_load_event()
	// The initial failure is scoped to installation. An author can retry the
	// same URL later, after selecting a different source in between.
	app.js_runtime.evaluate_host('failed.src="data:image/png;base64,${preloaded_image_small_png}";failed.src="/failed.png"')!
	stop <- true
	assert <-count == 1
}

fn test_preloaded_redirect_image_bytes_are_decoded_and_source_changes_keep_working() {
	mut document := preloaded_image_document('https://preloaded-image.test/search', '<!doctype html><img id="thumbnail" src="/redirect.png">')
	defer { document.finalize() }
	address := dom.URL{ value: 'https://preloaded-image.test/redirect.png' }
	resources := {
		address.serialize(): PreloadedResource{
			url:          address.serialize()
			final_url:    'https://cdn.preloaded-image.test/thumbnail.png'
			body:         base64.decode(preloaded_image_small_png).bytestr()
			request_type: 'image'
		}
	}
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	_ = run_document_script_sources_with_image_fetch(document, document.url.serialize(),
		[browserjs.ScriptSource{ code: 'globalThis.widthBefore=thumbnail.naturalWidth' }],
		runtime, browser_preloaded_image_fetch(document, resources), mut messages)
	assert messages == []
	assert runtime.evaluate_host('widthBefore===1&&thumbnail.complete&&thumbnail.currentSrc==="${address.serialize()}"')! == 'true'
	assert runtime.evaluate_host('thumbnail.src="data:image/png;base64,${preloaded_image_large_png}";thumbnail.naturalWidth')! == '4'
}

fn test_preloaded_image_bytes_do_not_approve_cross_origin_cors_requests() {
	mut document := preloaded_image_document('https://preloaded-image.test/', '<!doctype html><img id="thumbnail" crossorigin="anonymous" src="https://other.test/private.png">')
	defer { document.finalize() }
	address := dom.URL{ value: 'https://other.test/private.png' }
	image := unsafe { &dom.HTMLImageElement(document.get_element_by_id('thumbnail')?) }
	model := html.html_image_element_model_for_dom_element(image)
	fetch_image := browser_preloaded_image_fetch(document, {
		address.serialize(): PreloadedResource{
			url:  address.serialize()
			body: base64.decode(preloaded_image_small_png).bytestr()
		}
	})
	if decoded := fetch_image(image, model, address) {
		assert false, 'Cross-origin CORS request accepted cached pixels: ${decoded.intrinsic_width()}'
	} else {
		assert err.msg().contains('CORS')
	}
}

fn test_adopted_image_does_not_reuse_the_previous_documents_preload() {
	path := os.join_path(os.temp_dir(), 'vox-adopted-preloaded-image-${os.getpid()}.png')
	os.write_file(path, base64.decode(preloaded_image_large_png).bytestr())!
	defer { os.rm(path) or {} }
	address := dom.URL{ value: 'file://${path}' }
	mut document := preloaded_image_document('https://preloaded-image.test/', '<!doctype html><img id="thumbnail">')
	mut replacement := preloaded_image_document('https://replacement-image.test/', '<!doctype html>')
	defer {
		document.finalize()
		replacement.finalize()
	}
	image := unsafe { &dom.HTMLImageElement(document.get_element_by_id('thumbnail')?) }
	model := html.html_image_element_model_for_dom_element(image)
	fetch_image := browser_preloaded_image_fetch(document, {
		address.serialize(): PreloadedResource{
			url:  address.serialize()
			body: base64.decode(preloaded_image_small_png).bytestr()
		}
	})
	assert fetch_image(image, model, address)!.intrinsic_width()? == 1
	replacement.adopt_node(unsafe { &dom.Node(image) })
	assert fetch_image(image, model, address)!.intrinsic_width()? == 4
}

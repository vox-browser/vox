module main

import browserjs
import dom
import encoding.base64
import html

// A 2x1 PNG.
const script_image_test_png = 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8AAQv8BD/kD/YURmXYAAAAASUVORK5CYII='

// 4chan's catalog writes its thumbnails through innerHTML once its scripts
// run. Those images are fetched in the background and decoded when the bytes
// arrive, without blocking the UI on the network.
fn test_script_inserted_images_decode_once_their_bytes_arrive() {
	$if !darwin {
		return
	}
	address := dom.URL{value: 'https://script-images.test/pol/catalog'}
	mut document := html.parse_navigation_document('<!doctype html><html><body><div id="threads"></div></body></html>',
		address, address.origin(), none) or { panic(err) }
	document.set_scripting_enabled_by_embedder(false)
	document.set_viewport_rect(dom.Rect{width: 1024, height: 768})
	defer { document.finalize() }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	thumbnail_url := 'https://i.script-images.test/pol/1s.png'
	mut app := BrowserApp{
		document:                    document
		js_runtime:                  runtime
		background_resource_results: chan PreloadedResource{cap: 2}
		// The test supplies the response instead of the network.
		background_resource_pending: {
			thumbnail_url: true
		}
	}
	app.relayout(1024, 768 + app.chrome_height())
	mut threads := document.get_element_by_id('threads') or { panic('missing threads') }
	threads.set_inner_html('<a href="thread/1"><img loading="lazy" alt="" id="thumb-1" class="thumb" src="//i.script-images.test/pol/1s.png"></a>')!
	thumbnail := document.get_element_by_id('thumb-1') or { panic('missing thumbnail') }
	model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(thumbnail) })
	assert !model.has_fetch_hook()
	app.poll_background_resources()
	assert thumbnail_url in app.script_image_requests
	assert app.script_image_scan_version == document.dom_tree_version()
	assert !model.has_fetch_hook()
	app.background_resource_results <- PreloadedResource{
		url:          thumbnail_url
		body:         base64.decode_str(script_image_test_png)
		source_url:   document.url.serialize()
		final_url:    thumbnail_url
		request_type: 'image'
	}
	app.poll_background_resources()
	assert thumbnail_url !in app.script_image_requests
	assert model.has_fetch_hook()
	assert model.natural_width() == 2
	assert model.natural_height() == 1
	assert model.complete()
}

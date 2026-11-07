module main

import encoding.base64
import gg
import html
import layout

const background_cache_photo_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='

fn fill_background_response_cache(mut app BrowserApp) {
	for index in 0 .. max_cached_resources {
		address := 'https://photo-feed.example.test/old-${index}.jpg'
		app.resource_cache[address] = PreloadedResource{ url: address, body: 'old response' }
	}
}

fn test_completed_photo_replaces_a_full_response_cache_without_changing_scroll_or_layout() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;height:3000px}#photo{width:200px;height:100px;background-image:url(https://photo-feed.example.test/new.png)}</style><div id="photo"></div>')
	defer { document.finalize() }
	mut app := BrowserApp{
		document:                    document
		background_resource_results: chan PreloadedResource{cap: 1}
	}
	app.relayout(320, 200 + app.chrome_height())
	app.set_scroll_y(600, 200 + app.chrome_height())
	fill_background_response_cache(mut app)
	before := layout.document_layout_result(document) or { panic('missing layout') }
	root := voidptr(before.root)
	state := voidptr(before.state)
	revision := document.paint_content_revision()
	address := 'https://photo-feed.example.test/new.png'
	app.background_resource_pending[address] = true
	app.background_resource_results <- PreloadedResource{
		url:          address
		body:         base64.decode(background_cache_photo_png).bytestr()
		source_url:   document.url.serialize()
		request_type: 'image'
	}
	app.poll_background_resources()
	assert address in app.resource_cache, 'a full cache discarded the completed photo'
	assert app.resource_cache.len == max_cached_resources
	assert address !in app.background_resource_pending
	assert app.background_image_bytes(address)!.len > 0
	assert document.paint_content_revision() > revision
	assert document.layout_is_up_to_date()
	after := layout.document_layout_result(document) or { panic('missing retained layout') }
	assert voidptr(after.root) == root && voidptr(after.state) == state
	assert app.scroll_y == 600 && document.viewport_rect().y == 600
	// The next paint must not start the same completed download again.
	app.request_background_resource(address)
	assert app.background_resource_pending.len == 0
	repainted_revision := document.paint_content_revision()
	app.poll_background_resources()
	assert document.paint_content_revision() == repainted_revision
}

fn test_failed_background_response_is_retained_at_capacity_instead_of_retried_each_frame() {
	mut app := BrowserApp{ background_resource_results: chan PreloadedResource{cap: 1} }
	fill_background_response_cache(mut app)
	address := 'https://photo-feed.example.test/unavailable.jpg'
	app.background_resource_pending[address] = true
	app.background_resource_results <- PreloadedResource{
		url:          address
		error:        '404'
		request_type: 'image'
	}
	app.poll_background_resources()
	assert address in app.resource_cache, 'a full cache lost the failure and allowed a retry loop'
	assert app.resource_cache[address].error == '404'
	assert app.resource_cache.len == max_cached_resources
	app.request_background_resource(address)
	assert app.background_resource_pending.len == 0
}

fn test_response_cache_eviction_keeps_decoded_photo_pixels_and_the_response_bound() {
	$if !macos {
		return
	}
	mut app := BrowserApp{
		ctx:                         gg.new_context(native_rendering: true)
		address:                     'https://photo-feed.example.test/'
		background_resource_results: chan PreloadedResource{cap: max_cached_resources + 1}
	}
	address := 'https://photo-feed.example.test/decoded.png'
	app.resource_cache[address] = PreloadedResource{
		url:  address
		body: base64.decode(background_cache_photo_png).bytestr()
	}
	image := app.background_image(address) or { panic('missing initial photo') }
	image_id := image.id
	assert image.ok && image.width == 1 && image.height == 1
	for index in 0 .. max_cached_resources + 1 {
		app.background_resource_results <- PreloadedResource{
			url:          'https://photo-feed.example.test/later-${index}.jpg'
			error:        '404'
			request_type: 'image'
		}
	}
	app.poll_background_resources()
	assert app.resource_cache.len == max_cached_resources
	assert 'https://photo-feed.example.test/later-${max_cached_resources}.jpg' in app.resource_cache
	assert address !in app.resource_cache
	retained := app.background_image(address) or { panic('decoded photo was lost during response eviction') }
	assert retained.id == image_id && retained.ok
	assert app.background_resource_pending.len == 0
}

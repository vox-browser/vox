module main

import browserjs
import dom
import encoding.base64
import html
import os
import time

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

// The catalog's thumbnails carry width and height attributes, so their bytes
// cannot change the page's layout. Each completed batch keeps the layout tree
// and records the thumbnails' paint again.
fn test_sized_script_inserted_images_repaint_without_rebuilding_layout() {
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
	thumbnail_url := 'https://i.script-images.test/pol/2s.png'
	mut app := BrowserApp{
		document:                    document
		js_runtime:                  runtime
		background_resource_results: chan PreloadedResource{cap: 2}
		background_resource_pending: {
			thumbnail_url: true
		}
	}
	app.relayout(1024, 768 + app.chrome_height())
	mut threads := document.get_element_by_id('threads') or { panic('missing threads') }
	threads.set_inner_html('<a href="thread/2"><img loading="lazy" alt="" id="thumb-2" class="thumb" width="20" height="10" src="//i.script-images.test/pol/2s.png"></a>')!
	app.relayout(1024, 768 + app.chrome_height())
	thumbnail := document.get_element_by_id('thumb-2') or { panic('missing thumbnail') }
	layout_node := thumbnail.as_node().unsafe_layout_node() or { panic('missing thumbnail box') }
	app.poll_background_resources()
	assert thumbnail_url in app.script_image_requests
	app.background_resource_results <- PreloadedResource{
		url:          thumbnail_url
		body:         base64.decode_str(script_image_test_png)
		source_url:   document.url.serialize()
		final_url:    thumbnail_url
		request_type: 'image'
	}
	app.poll_background_resources()
	model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(thumbnail) })
	assert model.complete()
	assert document.layout_is_up_to_date()
	assert !app.paint_commands_pending
	retained := thumbnail.as_node().unsafe_layout_node() or { panic('missing retained thumbnail box') }
	assert voidptr(retained) == voidptr(layout_node)
	images := app.paint_commands.filter(it.kind == 'draw_replaced_image')
	assert images.len == 1
	assert images[0].image().image_url == thumbnail_url
}

// Bytes the disk cache already holds complete a thumbnail laid out near the
// viewport before the next paint, instead of after a background request. A
// thumbnail far below the viewport keeps its background request.
fn test_disk_cached_script_inserted_images_near_the_viewport_are_ready_without_a_request() {
	$if !darwin {
		return
	}
	previous_cache := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-script-images-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if previous := previous_cache {
			os.setenv('LADYBIRD_CACHE_DIR', previous, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.rmdir_all(cache) or {}
	}
	near_url := 'https://i.script-images.test/pol/3s.png'
	far_url := 'https://i.script-images.test/pol/4s.png'
	cache_resource(near_url, base64.decode_str(script_image_test_png))
	cache_resource(far_url, base64.decode_str(script_image_test_png))
	address := dom.URL{value: 'https://script-images.test/pol/catalog'}
	mut document := html.parse_navigation_document('<!doctype html><html><body style="margin:0"><div id="threads"></div></body></html>',
		address, address.origin(), none) or { panic(err) }
	document.set_scripting_enabled_by_embedder(false)
	document.set_viewport_rect(dom.Rect{width: 1024, height: 768})
	defer { document.finalize() }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut app := BrowserApp{
		document:                    document
		js_runtime:                  runtime
		background_resource_results: chan PreloadedResource{cap: 2}
		// The test supplies no response for the far thumbnail's request.
		background_resource_pending: {
			far_url: true
		}
	}
	mut threads := document.get_element_by_id('threads') or { panic('missing threads') }
	threads.set_inner_html('<img alt="" id="thumb-3" width="20" height="10" src="//i.script-images.test/pol/3s.png"><div style="height:4000px"></div><img alt="" id="thumb-4" width="20" height="10" src="//i.script-images.test/pol/4s.png">')!
	app.relayout(1024, 768 + app.chrome_height())
	ready := app.request_script_inserted_images()
	assert near_url in ready
	assert near_url !in app.background_resource_pending
	assert near_url !in app.script_image_requests
	assert far_url !in ready
	assert far_url in app.script_image_requests
	assert app.complete_script_inserted_images(url_set(ready))
	near := document.get_element_by_id('thumb-3') or { panic('missing near thumbnail') }
	model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(near) })
	assert model.complete()
	assert model.natural_width() == 2
	assert model.natural_height() == 1
	assert document.layout_is_up_to_date()
	far := document.get_element_by_id('thumb-4') or { panic('missing far thumbnail') }
	far_model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(far) })
	assert !far_model.has_fetch_hook()
}

// 4chan's script writes its banner without width or height attributes, so
// the banner's natural size takes part in layout. Before the first layout,
// the disk cache completes it and that layout includes its size. An uncached
// banner starts its request at once, while sized and lazy images wait for the
// laid-out positions that select their reads.
fn test_unsized_script_inserted_images_complete_before_the_first_layout() {
	$if !darwin {
		return
	}
	previous_cache := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-unsized-script-images-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if previous := previous_cache {
			os.setenv('LADYBIRD_CACHE_DIR', previous, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.rmdir_all(cache) or {}
	}
	banner_url := 'https://s.script-images.test/title/5.png'
	uncached_url := 'https://s.script-images.test/title/6.png'
	sized_url := 'https://i.script-images.test/pol/7s.png'
	lazy_url := 'https://i.script-images.test/pol/8s.png'
	for cached_url in [banner_url, sized_url, lazy_url] {
		cache_resource(cached_url, base64.decode_str(script_image_test_png))
	}
	address := dom.URL{value: 'https://script-images.test/pol/catalog'}
	mut document := html.parse_navigation_document('<!doctype html><html><body style="margin:0"><div id="threads"></div></body></html>',
		address, address.origin(), none) or { panic(err) }
	document.set_scripting_enabled_by_embedder(false)
	document.set_viewport_rect(dom.Rect{width: 1024, height: 768})
	defer { document.finalize() }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut app := BrowserApp{
		document:                    document
		js_runtime:                  runtime
		background_resource_results: chan PreloadedResource{cap: 2}
		// The test supplies no response for the uncached banner's request.
		background_resource_pending: {
			uncached_url: true
		}
	}
	mut threads := document.get_element_by_id('threads') or { panic('missing threads') }
	threads.set_inner_html('<img alt="4chan" id="banner" src="//s.script-images.test/title/5.png"><img alt="" id="uncached" src="//s.script-images.test/title/6.png" width="30"><img alt="" id="sized" width="20" height="10" src="//i.script-images.test/pol/7s.png"><img alt="" id="lazy" loading="lazy" src="//i.script-images.test/pol/8s.png">')!
	ready := app.request_unsized_script_inserted_images()
	assert banner_url in ready
	assert uncached_url !in ready
	assert uncached_url in app.script_image_requests
	for waiting_url in [sized_url, lazy_url] {
		assert waiting_url !in ready
		assert waiting_url !in app.script_image_requests
		assert waiting_url !in app.resource_cache
	}
	assert app.complete_script_inserted_images(ready)
	banner := document.get_element_by_id('banner') or { panic('missing banner') }
	model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(banner) })
	assert model.complete()
	app.relayout(1024, 768 + app.chrome_height())
	document.update_paint_and_hit_testing_properties_if_needed()
	rects := banner.client_rects_assuming_layout_clean()
	assert rects.len == 1
	assert rects[0].width_ == 2
	assert rects[0].height_ == 1
	sized := document.get_element_by_id('sized') or { panic('missing sized thumbnail') }
	sized_model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(sized) })
	assert !sized_model.has_fetch_hook()
}

module main

import browserjs
import css
import dom
import encoding.base64
import html
import os
import time

fn test_remote_native_image_requests_reuse_preloaded_bytes_and_keep_origin_state() {
	$if !darwin { return }
	previous_cache := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-remote-image-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if previous := previous_cache {
			os.setenv('LADYBIRD_CACHE_DIR', previous, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.rmdir_all(cache) or {}
	}
	resource_url := 'https://images.example.test/portal.png'
	bytes :=
		base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
	cache_resource(resource_url, bytes.bytestr())
	url := dom.dom_url_parse(resource_url, dom.url_about_blank(), 'UTF-8') or {
		panic('invalid image URL')
	}
	assert browser_image_resource_bytes(url)! == bytes
	mut document := html.parse_document('<!doctype html><img id="target" src="${resource_url}">')
	document.set_url(dom.dom_url_parse('https://page.example.test/', dom.url_about_blank(), 'UTF-8') or {
		panic('invalid document URL')
	})
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		'globalThis.remoteImageLoaded = target.complete && target.naturalWidth === 1;',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('remoteImageLoaded')! == 'true'
	element := document.get_element_by_id('target') or { panic('missing image') }
	image := unsafe { &dom.HTMLImageElement(element) }
	assert html.html_image_element_is_image_available(image)
	decoded := html.html_image_element_decoded_image_data(image) or {
		panic('missing decoded remote image')
	}
	assert decoded.intrinsic_width() or { 0 } == 1
	assert decoded.intrinsic_height() or { 0 } == 1
	assert decoded.is_cors_cross_origin()
}

fn test_native_remote_cors_mode_rejects_unverified_cross_origin_parsed_and_created_images() {
	$if !darwin { return }
	previous_cache := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-image-cors-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if previous := previous_cache {
			os.setenv('LADYBIRD_CACHE_DIR', previous, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.rmdir_all(cache) or {}
	}
	remote := 'https://remote-image.test/pixel.png'
	local := 'https://image-owner.test/pixel.png'
	bytes :=
		base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
	cache_resource(remote, bytes.bytestr())
	cache_resource(local, bytes.bytestr())
	address := dom.URL{
		value: 'https://image-owner.test/page'
	}
	mut document := html.parse_navigation_document('<!doctype html><body><img id="anonymous" crossorigin="anonymous" src="${remote}"><img id="credentials" crossorigin="use-credentials" src="${remote}"><img crossorigin="anonymous" src="${remote}"><img id="same" crossorigin="anonymous" src="${local}"></body>',
		address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, address.serialize(), [
		'globalThis.created = new Image(); created.id="created"; created.crossOrigin="use-credentials"; created.src="${remote}"; document.body.appendChild(created); globalThis.corsModes = [anonymous.crossOrigin, credentials.crossOrigin, created.crossOrigin];',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('JSON.stringify(corsModes)')! == '["anonymous","use-credentials","use-credentials"]'
	root := unsafe { &dom.Node(document) }
	images := css.query_selector_all(root, 'img')
	assert images.len == 5
	for element in images {
		if element.get_attribute_value('id') == 'same' { continue
		 }
		image := unsafe { &dom.HTMLImageElement(element) }
		assert !html.html_image_element_is_image_available(image)
		assert html.html_image_element_decoded_image_data(image) == none
	}
	// The same-origin cache entry has no final-response provenance either; it
	// may display, but cannot make pixels from an unverified redirect readable.
	same := document.get_element_by_id('same') or { panic('missing same-origin image') }
	decoded := html.html_image_element_decoded_image_data(unsafe { &dom.HTMLImageElement(same) }) or {
		panic('missing same-origin decoded image')
	}
	assert decoded.is_cors_cross_origin()
}

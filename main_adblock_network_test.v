module main

import adblock
import browsernet
import dom
import encoding.base64
import gg
import html
import net
import os
import time

fn assert_cached_resource_is_blocked(resource_url string, request_type string) {
	mut blocked := false
	_ := fetch_text_resource_for_request(resource_url, '', 'https://www.theverge.com/article',
		request_type) or {
		blocked = err.msg().starts_with('Blocked by adblock:')
		''
	}
	assert blocked, 'cached resource bypassed adblock: ${resource_url}'
}

fn test_native_cached_resources_and_cached_redirect_targets_are_still_filtered() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-adblock-cache-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous {
			os.setenv('LADYBIRD_CACHE_DIR', value, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.rmdir_all(cache) or {}
	}
	tracker := 'https://www.google-analytics.com/g/collect?v=2'
	cache_resource(tracker, 'cached tracking response')
	assert_cached_resource_is_blocked(tracker, 'xmlhttprequest')
	redirect := 'https://www.theverge.com/vox-adblock-fixture'
	cache_resource_response(redirect, tracker, 'cached redirected tracker')
	assert_cached_resource_is_blocked(redirect, 'xmlhttprequest')
}

fn test_native_preloaded_tracking_script_is_excluded_before_javascript_execution() {
	address := dom.URL{
		value: 'https://www.theverge.com/article'
	}
	tracker := 'https://www.google-analytics.com/g/collect?v=2'
	mut document := html.parse_navigation_document('<!doctype html><script src="${tracker}"></script><script>globalThis.allowed = true;</script>',
		address, address.origin(), none)!
	defer { document.finalize() }
	mut messages := []string{}
	sources := script_sources(document, address.serialize(), {
		tracker: PreloadedResource{
			url:  tracker
			body: 'globalThis.trackerExecuted = true;'
		}
	}, mut messages)
	assert sources.len == 1
	assert sources[0].code == 'globalThis.allowed = true;'
	assert messages.len == 1
	assert messages[0].contains('Blocked by adblock:')
}

fn test_native_redirect_replacement_overrides_disk_and_preloaded_network_bodies() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(),
		'vox-adblock-replacement-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous {
			os.setenv('LADYBIRD_CACHE_DIR', value, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.rmdir_all(cache) or {}
	}
	address := dom.URL{
		value: 'https://www.theverge.com/article'
	}
	tracker := 'https://www.google-analytics.com/analytics.js'
	filtered := browsernet.filter(adblock.Request{
		url:          tracker
		source_url:   address.serialize()
		request_type: 'script'
	})!
	replacement := filtered.replacement or { panic('missing upstream analytics replacement') }
	cache_resource(tracker, 'globalThis.cachedTrackerExecuted = true;')
	assert fetch_text_resource_for_request(tracker, '', address.serialize(), 'script')! == replacement.body
	mut document := html.parse_navigation_document('<!doctype html><script src="${tracker}"></script>',
		address, address.origin(), none)!
	defer { document.finalize() }
	cached := {
		tracker: PreloadedResource{
			url:  tracker
			body: 'globalThis.cachedTrackerExecuted = true;'
		}
	}
	preloaded := preload_document_resources(document, address.serialize(), cached)
	assert preloaded[tracker].body == replacement.body
	assert preloaded[tracker].adblock_replacement
	mut messages := []string{}
	sources := script_sources(document, address.serialize(), cached, mut messages)
	assert messages == []
	assert sources.len == 1
	assert sources[0].code == replacement.body
	redirected := filter_preloaded_resource(PreloadedResource{
		url:       'https://www.theverge.com/vox-adblock-redirect'
		body:      'globalThis.redirectedTrackerExecuted = true;'
		final_url: tracker
	}, address.serialize(), 'script')!
	assert redirected.body == replacement.body
	assert redirected.adblock_replacement
}

fn test_native_image_request_checks_document_context_before_decoding_cached_pixels() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-adblock-image-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous {
			os.setenv('LADYBIRD_CACHE_DIR', value, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.rmdir_all(cache) or {}
	}
	tracker := 'https://www.google-analytics.com/g/collect?v=2'
	cache_resource(tracker,
		base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=').bytestr())
	address := dom.URL{
		value: 'https://www.theverge.com/article'
	}
	mut document := html.parse_navigation_document('<!doctype html><img id="tracker">', address,
		address.origin(), none)!
	defer { document.finalize() }
	element := document.get_element_by_id('tracker') or { panic('missing image') }
	image := unsafe { &dom.HTMLImageElement(element) }
	model := html.html_image_element_model_for_dom_element(image)
	_ := browser_fetch_image_request(image, model, dom.URL{ value: tracker }) or {
		assert err.msg().starts_with('Blocked by adblock:'), err.msg()
		return
	}
	assert false, 'tracking image decoded from disk cache'
}

fn serve_adblock_toggle_script(mut listener net.TcpListener) []string {
	mut requests := []string{}
	for hop in 0 .. 2 {
		mut socket := listener.accept() or { panic(err) }
		socket.set_read_timeout(2 * time.second)
		mut input := []u8{len: 4096}
		count := socket.read(mut input) or { panic(err) }
		requests << input[..count].bytestr().all_before('\r\n')
		response := if hop == 0 {
			'HTTP/1.1 302 Found\r\nLocation: https://www.google-analytics.com/analytics.js\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'
		} else {
			body := 'globalThis.liveScript = true;'
			'HTTP/1.1 200 OK\r\nContent-Type: text/javascript\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}'
		}
		socket.write_string(response) or { panic(err) }
		socket.close() or {}
	}
	return requests
}

fn test_disabling_adblock_refetches_a_cached_synthetic_redirect_in_the_same_context() {
	was_enabled := adblock.is_enabled()
	adblock.set_enabled(true)
	defer { adblock.set_enabled(was_enabled) }
	_ := browsernet.filter(adblock.Request{ url: 'http://127.0.0.1/', request_type: 'script' })!
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-adblock-toggle-${os.getpid()}-${time.sys_mono_now()}')
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
	server := spawn serve_adblock_toggle_script(mut listener)
	resource_url := 'http://${listener.addr()!}/script'
	source_url := 'https://www.theverge.com/article'
	synthetic := fetch_browser_resource(resource_url, '', source_url, 'script')!
	assert synthetic.adblock_replacement
	assert synthetic.final_url == 'https://www.google-analytics.com/analytics.js'
	adblock.set_enabled(false)
	actual := filter_preloaded_resource(synthetic, source_url, 'script')!
	assert !actual.adblock_replacement
	assert actual.body == 'globalThis.liveScript = true;'
	assert actual.final_url == resource_url
	assert server.wait() == ['GET /script HTTP/1.1', 'GET /script HTTP/1.1']
}

fn test_enabling_adblock_does_not_reuse_an_unfiltered_gpu_image() {
	$if !macos { return }
	was_enabled := adblock.is_enabled()
	defer { adblock.set_enabled(was_enabled) }
	tracker := 'https://www.google-analytics.com/g/collect?v=2'
	source_url := 'https://www.theverge.com/article'
	mut app := BrowserApp{
		ctx:            gg.new_context(native_rendering: true)
		address:        source_url
		resource_cache: {
			tracker: PreloadedResource{
				url:          tracker
				body:         base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=').bytestr()
				source_url:   source_url
				final_url:    tracker
				request_type: 'image'
			}
		}
	}
	adblock.set_enabled(false)
	image := app.background_image(tracker) or { panic('unfiltered image did not load') }
	assert image.width == 1 && image.height == 1
	original_id := image.id
	adblock.set_enabled(true)
	assert app.background_image(tracker) == none
	adblock.set_enabled(false)
	assert (app.background_image(tracker) or { panic('unfiltered image cache was lost') }).id == original_id
}

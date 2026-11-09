module main

import adblock
import browserjs
import dom
import html
import os
import page
import platform
import requestserver
import time



// A fresh native worker/filter process uses this executable's normal role.
fn test_upstream_native_process_role() {
	if code := browserjs.run_worker_process_role(os.args) { exit(code) }
	if code := adblock.run_default_worker_role(os.args) { exit(code) }
}

// Optional HTTP integration check. The server supplies the original pinned
// HTML/support files and the stock harness with a collecting report script.
fn test_upstream_testharness_in_native_document() {
	address := os.getenv('VOX_UPSTREAM_WPT_URL')
	if address == '' { return }
	output := os.getenv('VOX_UPSTREAM_WPT_RESULT')
	assert output != ''
	requestserver.install_native_font_fetch_host()!
	defer { requestserver.close_native_font_fetch_host() }
	loaded := fetch_page(address, '')!
	url := dom.URL{value: loaded.url}
	mut owner := page.Page.create(1)!
	mut document := parse_loaded_browser_navigation_document(loaded, url, none, none, unsafe { &dom.Page(owner) }, true)
	owner.set_local_root_navigable(document.navigable() or { panic('missing root navigable') })!
	assert document.is_fully_active()
	mut service := &BrowserHostedDocument{document: document}
	mut manager := browser_child_document_host(document, .javascriptcore)
	defer { manager.close(); service.close(); document.finalize() }
	mut messages := []string{}
	service.start_resources()
	deadline := time.now().add(70 * time.second)
	// Match the browser's initial resource preload boundary: parser completion
	// tasks must not dispatch load before the scripts install their listeners.
	for !service.initialized {
		service.initialize(.javascriptcore, mut messages)
		assert time.now() < deadline, 'initial resources did not finish'
		time.sleep(time.millisecond)
	}
	for {
		service.poll(mut messages)
		manager.poll(mut messages)
		html.main_thread_event_loop().process()
		platform.pump_native_events(0.001)
		if service.runtime != unsafe { nil } {
			if service.runtime.evaluate_host('typeof nativeWptResult!=="undefined"&&nativeWptResult!==null')! == 'true' { break }
		}
		if time.now() > deadline {
			os.write_file(output+'.messages', messages.join('\n'))!
			assert false, 'upstream document harness did not report: '+messages.join('\n')
		}
	}
	runtime := service.runtime
	result := runtime.evaluate_host('JSON.stringify(nativeWptResult)')!
	os.write_file(output, result)!
	os.write_file(output+'.state', runtime.evaluate_host('JSON.stringify({readyState:document.readyState,location:location.href})')!+' loadDelayed=${document.anything_is_delaying_the_load_event()}')!
	os.write_file(output+'.messages', messages.join('\n'))!
	println(result)
	assert runtime.evaluate_host('nativeWptResult.harness===0&&nativeWptResult.tests.length>0&&nativeWptResult.tests.every(t=>t.status===0)')! == 'true', result
}


fn test_cached_page_eviction_keeps_process_blob_stores_after_frame_retirement() {
	if os.getenv('VOX_UPSTREAM_WPT_URL') != '' { return }
	mut app := &BrowserApp{page_model: page.Page.create(1)!, viewport_width: 800, viewport_height: 600}
	defer { app.dispose_browser_tab() }
	mut documents := []&dom.Document{}
	for index in 0 .. 12 {
		loaded := LoadedPage{url: 'https://cache-blob-lifetime.test/${index}', markup: '<!doctype html><p>page ${index}</p>', content_type: 'text/html'}
		mut frame := platform.begin_thread_scratch('Blob URL cache eviction frame')
		app.install_loaded_page(loaded, true)
		frame.finish()
		documents << app.document
		assert app.back_forward_cache.pages.len <= back_forward_cache_capacity
		if index > back_forward_cache_capacity {
			retired := documents[index-back_forward_cache_capacity-1]
			assert retired.has_been_destroyed()
			storage := retired.native_storage()
			assert storage != unsafe { nil }
			assert storage.arena.usage().used == 0
		}
	}
	assert app.history.len == 12
}
module main

import html
import net
import page
import time

fn test_tokenized_navigation_preloads_match_full_discovery_with_raw_text_and_url_entities() {
	for markup in [
		'<html><head><title>&lt;img src="fake.png"></title><link rel="stylesheet" href="/x.css?a&amp;b"><script src="/x.js"></script></head><body><table><tr><td><img src="/p.png"><script src="/late.js">let s="<img src=\'hidden.png\'>";</script></td></tr></table></body></html>',
		'<html><head><style>i:before{content:"<script src=bad.js>"}</style><link rel="preload" as="style" type="text/css; charset=utf-8" href="/x.css"><link rel="stylesheet" href="/x.css"></head><body><textarea><img src="fake.png"></textarea><img src="/x.css"><script src="/x.css"></script><script src="/right.js" type="APPLICATION/JAVASCRIPT"></script><script src="/data.json" type="application/json"></script></body></html>',
	] {
		loaded := LoadedPage{url:'https://preload.test/root/page', markup:markup, content_type:'text/html;charset=utf-8'}
		found := tokenized_navigation_preloads(loaded) or { panic('eligible preload input rejected') }
		document := parse_page_preload_document(loaded, true)
		base := document.base_url().serialize()
		assert found.urls == document_preload_resource_urls(document, base)
		full_types := document_preload_resource_types(document, base)
		for address in found.urls { assert (found.types[address] or { 'image' }) == (full_types[address] or { 'image' }) }
		retire_native_preload_document(document)
	}
}

fn test_tokenized_navigation_preloads_keep_sensitive_contexts_on_the_full_parser() {
	for content in [
		'<base href="/other/">', '<template><img src="hidden.png"></template>',
		'<noscript><link rel="stylesheet" href="hidden.css"></noscript>',
		'<svg><image href="graphic.svg"/></svg>', '<math></math>',
		'<select><img src="ignored.png"></select>', '<meta http-equiv="default-style" content="Other">',
		'<link rel="stylesheet" title="Set" href="set.css">',
		'<link rel="alternate stylesheet" href="unused.css">', '<link rel="stylesheet" disabled href="unused.css">',
		'<style title="Set">b{color:red}</style>',
	] {
		assert collect_tokenized_navigation_preloads('<html><head></head><body>${content}</body></html>', 'https://preload.test/') == none
	}
	assert collect_tokenized_navigation_preloads('<link rel="stylesheet" href="fragment.css">', 'https://preload.test/') == none
}

fn test_tokenized_navigation_preloads_preserve_group_priority_and_image_limit() {
	mut content := '<html><head></head><body><img src="shared"><img src="late.png"><script src="shared"></script><link rel="stylesheet" href="shared">'
	for index in 0 .. max_preloaded_resources + 8 { content += '<script src="${index}.js"></script>' }
	content += '</body></html>'
	found := collect_tokenized_navigation_preloads(content, 'https://preload.test/') or { panic('eligible') }
	// Discovery retains scripts independently of the commit barrier; images
	// only fit the remaining discovery budget.
	assert found.urls.len == max_preloaded_resources + 9
	assert found.urls[0] == 'https://preload.test/shared'
	assert found.types[found.urls[0]] == 'stylesheet'
	assert found.types[found.urls[1]] == 'script'
	assert found.urls.last() == 'https://preload.test/${max_preloaded_resources + 7}.js'
	assert 'https://preload.test/late.png' !in found.urls
	mut images := '<html><head></head><body><script src="a.js"></script>'
	for index in 0 .. max_preloaded_resources + 8 { images += '<img src="${index}.png">' }
	images += '</body></html>'
	bounded := collect_tokenized_navigation_preloads(images, 'https://preload.test/') or { panic('eligible') }
	assert bounded.urls.len == max_preloaded_resources
	assert bounded.urls.last() == 'https://preload.test/${max_preloaded_resources - 2}.png'
}

fn serve_delayed_initial_script(mut listener net.TcpListener, requested chan bool,
	release chan bool, finished chan bool) {
	mut socket := listener.accept() or { finished <- false; return }
	defer { socket.close() or {} }
	socket.set_read_timeout(5 * time.second)
	mut input := []u8{len: 4096}
	_ := socket.read(mut input) or { finished <- false; return }
	requested <- true
	mut released := false
	select {
		_ := <-release { released = true }
		5 * time.second {}
	}
	source := 'globalThis.asyncRuns=(globalThis.asyncRuns||0)+1;document.getElementById("next").textContent="async finished";'
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: text/javascript\r\nCache-Control: no-store\r\nContent-Length: ${source.len}\r\nConnection: close\r\n\r\n${source}') or {
		finished <- false
		return
	}
	finished <- released
}

fn test_delayed_initial_async_script_does_not_block_tokenized_or_full_navigation_commit() {
	for use_full_discovery in [false, true] {
		mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
		listener.set_accept_timeout(5 * time.second)
		defer { listener.close() or {} }
		address := 'http://${listener.addr()!}'
		requested := chan bool{cap: 1}
		release := chan bool{cap: 1}
		finished := chan bool{cap: 1}
		defer { release <- true }
		spawn serve_delayed_initial_script(mut listener, requested, release, finished)
		owner := page.Page.create(1)!
		mut app := BrowserApp{
			page_model: owner
			script_policy: .disabled
			layout_tree_only: true
			viewport_width: 320
			viewport_height: 200
			background_resource_results: chan PreloadedResource{cap: 32}
		}
		app.install_loaded_page(LoadedPage{
			url: '${address}/old'
			content_type: 'text/html'
			markup: '<!doctype html><p id="old">Old page</p>'
		}, false)
		app.script_policy = .enabled
		base := if use_full_discovery { '<base href="${address}/assets/">' } else { '' }
		loaded := LoadedPage{
			url: '${address}/next'
			content_type: 'text/html'
			markup: '<!doctype html><html><head>${base}<script async src="delayed.js"></script></head><body><p id="next">Ready before script</p></body></html>'
		}
		if use_full_discovery {
			assert tokenized_navigation_preloads(loaded) == none
		} else {
			assert tokenized_navigation_preloads(loaded) != none
		}
		app.start_page_preload(loaded, true)
		app.poll_page_preload()
		// The server cannot send script bytes until after installation returns.
		assert app.pending_page_preload == none
		assert app.address == '${address}/next'
		assert app.document.get_element_by_id('old') == none
		assert app.document.get_element_by_id('next')?.as_node().text_content()? == 'Ready before script'
		assert app.document.anything_is_delaying_the_load_event()
		select {
			_ := <-requested {}
			5 * time.second { assert false, 'parser did not request the async script' }
		}
		release <- true
		assert <-finished, 'the commit waited for the script response'
		deadline := time.sys_mono_now() + 5 * time.second
		mut loop := html.main_thread_event_loop()
		for time.sys_mono_now() < deadline {
			app.poll_browser_script_requests()
			if loop.task_queue().has_runnable_tasks() { loop.process() }
			if app.js_runtime != unsafe { nil } { app.poll_javascript_tasks() }
			if app.document.get_element_by_id('next')?.as_node().text_content()? == 'async finished'
				&& app.document.readiness() == .complete { break }
			time.sleep(time.millisecond)
		}
		assert app.document.get_element_by_id('next')?.as_node().text_content()? == 'async finished'
		assert app.document.readiness() == .complete
		assert !app.document.anything_is_delaying_the_load_event()
		assert app.js_runtime.evaluate_host('asyncRuns')! == '1'
		assert app.js_messages == []
		if mut loader := app.script_request_loader { loader.cancel() }
		if mut loader := app.image_request_loader { loader.cancel() }
		app.js_runtime.close()
		mut document := app.document
		document.finalize()
	}
}

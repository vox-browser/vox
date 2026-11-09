module main

import adblock
import browsernet
import browsersettings
import dom
import encoding.base64
import html
import net
import page
import time

fn testsuite_begin() {
	// Keep parser lifecycle fixtures independent of installed filter scriptlets.
	adblock.set_enabled(false)
}

fn parser_lifecycle_fixture() &BrowserParserScriptHost {
	return parser_lifecycle_fixture_at('https://parser-lifecycle.example/page')
}

fn parser_lifecycle_fixture_at(url string) &BrowserParserScriptHost {
	address := dom.URL{value: url}
	document := create_browser_navigation_document_input_with_source('UTF-8', address,
		none, none, none, 1_000_000, true, none)
	images := new_browser_image_request_loader(document, {})
	mut scripts := new_browser_script_request_loader(document, {})
	// Tests deliver completions on the owner thread, independently of wall time.
	scripts.fetch = fn (_ string, _ string, _ chan PreloadedResource, _ &browsernet.RequestScope) {}
	return install_browser_parser_script_host(document, .javascriptcore, images, scripts, {}, none, none)
}

fn serve_parser_svg_sprite(mut listener net.TcpListener, requests chan string, stop chan bool) {
	for {
		select {
			_ := <-stop { return }
			else {}
		}
		mut socket := listener.accept() or { continue }
		socket.set_read_timeout(5 * time.second)
		mut input := []u8{len: 4096}
		length := socket.read(mut input) or { 0 }
		requests <- input[..length].bytestr().all_before('\r\n')
		body := '<svg xmlns="http://www.w3.org/2000/svg"><symbol id="logo" data-owner="sprite"><path d="M0 0H10V10Z"/></symbol></svg>'
		socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: image/svg+xml\r\nCache-Control: no-store\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}') or {}
		socket.close() or {}
	}
}

fn test_resumed_parser_loads_svg_use_resources_even_when_its_script_fails() {
	$if !darwin && !linux { return }
	for failed in [false, true] {
		mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
		listener.set_accept_timeout(10 * time.millisecond)
		requests := chan string{cap: 8}
		stop := chan bool{cap: 1}
		spawn serve_parser_svg_sprite(mut listener, requests, stop)
		defer { stop <- true; listener.close() or {} }
		address := 'http://${listener.addr()!}'
		mut host := parser_lifecycle_fixture_at('${address}/page')
		defer { parser_lifecycle_close(host) }
		prefix := '${address}/prefix.svg'
		host.initial_resources[prefix] = PreloadedResource{
			url: prefix
			body: '<svg xmlns="http://www.w3.org/2000/svg"><symbol id="logo" data-owner="prefix"/></svg>'
		}
		parser_lifecycle_parse(host, '<!doctype html><svg><use id=prefix href="${prefix}#logo"/></svg><script src=blocking.js></script><base href="/assets/"><svg><use id=one href="sprite.svg#logo"/><use id=two xlink:href="sprite.svg#logo"/><use href="#local"/><use href="https://other.test/sprite.svg#logo"/></svg>')
		assert host.document.get_element_by_id('one') == none
		assert requests.len == 0
		// The shell installs its first, incomplete resource map while paused.
		install_browser_svg_use_resources(host.document, host.initial_resources.clone())
		host.scripts.results <- PreloadedResource{
			url: '${address}/blocking.js'
			source_url: host.document.url.serialize()
			request_type: 'script'
			body: 'globalThis.scriptRan=true;'
			error: if failed { 'failed script' } else { '' }
		}
		host.scripts.poll(host.runtime, mut host.messages)
		parser_lifecycle_run_tasks()
		assert host.document.ready_state() == 'complete'
		assert (host.runtime == unsafe { nil }) == failed
		assert requests.len == 1
		assert <-requests == 'GET /assets/sprite.svg HTTP/1.1'
		assert host.svg_resources.len == 2
		prefix_shadow := host.document.get_element_by_id('prefix')?.shadow_root()?
		assert unsafe { &dom.Node(prefix_shadow) }.first_child()?.as_element()?.get_attribute_value('data-owner') == 'prefix'
		for id in ['one', 'two'] {
			element := host.document.get_element_by_id(id)?
			shadow := element.shadow_root()?
			instance := unsafe { &dom.Node(shadow) }.first_child()?.as_element()?
			assert instance.get_attribute_value('data-owner') == 'sprite'
		}
		// Reusing the same installation cannot refetch a no-store response.
		host.install_svg_use_resources()
		assert requests.len == 0
	}
}

fn test_synchronous_parser_shares_no_store_svg_responses_with_the_shell() {
	$if !darwin && !linux { return }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(10 * time.millisecond)
	requests := chan string{cap: 8}
	stop := chan bool{cap: 1}
	spawn serve_parser_svg_sprite(mut listener, requests, stop)
	defer { stop <- true; listener.close() or {} }
	address := 'http://${listener.addr()!}'
	mut app := BrowserApp{
		page_model: page.Page.create(1)!
		script_policy: .enabled
		layout_tree_only: true
		viewport_width: 320
		viewport_height: 200
	}
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(LoadedPage{
		url: '${address}/page'
		markup: '<!doctype html><svg><use id=target href="sprite.svg#logo"/></svg>'
		content_type: 'text/html'
	}, false)
	assert requests.len == 1
	assert <-requests == 'GET /sprite.svg HTTP/1.1'
	shadow := app.document.get_element_by_id('target')?.shadow_root()?
	instance := unsafe { &dom.Node(shadow) }.first_child()?.as_element()?
	assert instance.get_attribute_value('data-owner') == 'sprite'
	assert app.js_messages == []
}

fn parser_lifecycle_close(host &BrowserParserScriptHost) {
	mut scripts := host.scripts
	scripts.cancel()
	mut images := host.images
	images.cancel()
	if host.runtime != unsafe { nil } { host.runtime.close() }
	mut document := unsafe { &dom.Document(host.document) }
	document.finalize()
}

fn parser_lifecycle_parse(host &BrowserParserScriptHost, markup string) {
	parse_prepared_browser_navigation_document(PreparedBrowserNavigationDocument{
		document: host.document
		markup: markup
	})
}

fn parser_lifecycle_run_tasks() {
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 128 {
		if !loop.task_queue().has_runnable_tasks() { return }
		loop.process()
	}
	assert !loop.task_queue().has_runnable_tasks(), 'parser lifecycle tasks did not settle'
}

fn parser_lifecycle_respond(mut host BrowserParserScriptHost, name string, code string, failure string) {
	host.scripts.results <- PreloadedResource{
		url: 'https://parser-lifecycle.example/${name}'
		source_url: host.document.url.serialize()
		request_type: 'script'
		body: code
		error: failure
	}
	host.scripts.poll(host.runtime, mut host.messages)
	parser_lifecycle_run_tasks()
}

fn test_initial_classic_scripts_observe_the_live_parser_and_roots() {
	$if !darwin && !linux { return }
	mut host := parser_lifecycle_fixture()
	defer { parser_lifecycle_close(host) }
	parser_lifecycle_parse(host, r'<!doctype html><html><head><script id=head-script>
globalThis.observed=[document.body===null,document.head!==null,document.getElementById("later")===null,document.currentScript.id,document.readyState];
document.addEventListener("DOMContentLoaded",()=>observed.push("ready:"+document.readyState));
window.addEventListener("load",()=>observed.push("load:"+document.readyState));
</script></head><body><div id=later>later</div><script id=body-script>
observed.push(document.body!==null,later.textContent,document.currentScript.id,document.readyState);
</script></body></html>')
	assert host.initialized
	assert host.runtime.evaluate_host('observed.join("|")')! == 'true|true|true|head-script|loading|true|later|body-script|loading'
	assert host.document.ready_state() == 'interactive'
	parser_lifecycle_run_tasks()
	assert host.runtime.evaluate_host('observed.join("|")')! == 'true|true|true|head-script|loading|true|later|body-script|loading|ready:interactive|load:complete'
	assert host.runtime.evaluate_host('document.currentScript===null')! == 'true'
	mut messages := []string{}
	host.flush(mut messages)
	assert messages == []
}

fn test_repeated_parser_writes_preserve_nodes_mutations_and_listeners() {
	$if !darwin && !linux { return }
	mut host := parser_lifecycle_fixture()
	defer { parser_lifecycle_close(host) }
	parser_lifecycle_parse(host, r'<!doctype html><body><script id=writer>
globalThis.checks=[document.open()===document,document.getElementById("after")===null];
document.write("<div id=written>first");
globalThis.saved=document.getElementById("written");
globalThis.clicks=0;saved.addEventListener("click",()=>clicks++);
saved.setAttribute("data-kept","yes");
document.write("<span id=child>second</span></div>");
checks.push(saved===document.getElementById("written"),saved.getAttribute("data-kept")==="yes",saved.textContent==="firstsecond",document.getElementById("after")===null);
saved.dispatchEvent(new Event("click"));checks.push(clicks===1);
document.write("<script id=nested>checks.push(document.currentScript.id===\"nested\");<\/script>");
checks.push(document.currentScript.id==="writer");
</script><p id=after>after</p></body>')
	parser_lifecycle_run_tasks()
	assert host.runtime.evaluate_host('checks.length===9&&checks.every(Boolean)')! == 'true'
	assert host.runtime.evaluate_host('saved===document.getElementById("written")&&saved.nextElementSibling.id==="nested"')! == 'true'
	assert host.document.get_element_by_id('after') != none
	mut messages := []string{}
	host.flush(mut messages)
	assert messages == []
}

fn test_external_classic_script_resumes_before_later_markup_and_runs_once() {
	$if !darwin && !linux { return }
	mut host := parser_lifecycle_fixture()
	defer { parser_lifecycle_close(host) }
	parser_lifecycle_parse(host, '<!doctype html><body><p id=before>before</p><script id=blocking src=blocking.js></script><p id=after>after</p>')
	assert host.document.get_element_by_id('after') == none
	assert host.document.has_pending_parsing_blocking_script()
	assert host.runtime == unsafe { nil }
	parser_lifecycle_respond(mut host, 'blocking.js', r'globalThis.runs=(globalThis.runs||0)+1;globalThis.stage=[document.getElementById("before")!==null,document.getElementById("after")===null,document.currentScript.id,document.readyState];document.write("<b id=inserted>written</b>");', '')
	assert host.runtime.evaluate_host('stage.join("|")')! == 'true|true|blocking|loading'
	assert host.runtime.evaluate_host('runs')! == '1'
	assert host.document.get_element_by_id('inserted') != none
	assert host.document.get_element_by_id('after') != none
	assert host.document.ready_state() == 'complete'
	mut messages := []string{}
	host.flush(mut messages)
	assert messages == []
}

fn test_defer_delays_dom_content_loaded_while_async_only_delays_load() {
	$if !darwin && !linux { return }
	mut host := parser_lifecycle_fixture()
	defer { parser_lifecycle_close(host) }
	parser_lifecycle_parse(host, r'<!doctype html><head><script>
globalThis.order=[];document.addEventListener("DOMContentLoaded",()=>order.push("ready"));window.addEventListener("load",()=>order.push("load"));
</script><script defer src=deferred.js></script><script async src=async.js></script></head><body><p id=after>after</p></body>')
	parser_lifecycle_run_tasks()
	assert host.document.get_element_by_id('after') != none
	assert host.runtime.evaluate_host('order.join()')! == ''
	parser_lifecycle_respond(mut host, 'deferred.js', 'order.push(document.getElementById("after")?"deferred":"wrong");', '')
	assert host.runtime.evaluate_host('order.join()')! == 'deferred,ready'
	assert host.document.ready_state() == 'interactive'
	// The old image/compact completion entry must not jump past parser state.
	host.runtime.dispatch_document_readiness_event('load')!
	parser_lifecycle_run_tasks()
	assert host.runtime.evaluate_host('order.join()')! == 'deferred,ready'
	parser_lifecycle_respond(mut host, 'async.js', 'order.push("async");', '')
	assert host.runtime.evaluate_host('order.join()')! == 'deferred,ready,async,load'
	assert host.document.ready_state() == 'complete'
	parser_lifecycle_run_tasks()
	assert host.runtime.evaluate_host('order.join()')! == 'deferred,ready,async,load'
}

fn test_document_open_inherits_parser_script_bindings() {
	$if !darwin && !linux { return }
	mut host := parser_lifecycle_fixture()
	defer { parser_lifecycle_close(host) }
	parser_lifecycle_parse(host, '<!doctype html><body><script>globalThis.openedRuns=0;</script><p id=old>old</p>')
	parser_lifecycle_run_tasks()
	host.runtime.evaluate_host(r'document.open();document.write("<script id=reopened>openedRuns++;globalThis.reopenedStage=document.getElementById(\"new\")===null&&document.currentScript.id===\"reopened\";<\/script><p id=new>new</p>");document.close();')!
	parser_lifecycle_run_tasks()
	assert host.runtime.evaluate_host('openedRuns===1&&reopenedStage&&document.getElementById("old")===null')! == 'true'
	assert host.document.get_element_by_id('new') != none
}

fn test_svg_script_uses_the_parser_execution_hook() {
	$if !darwin && !linux { return }
	mut host := parser_lifecycle_fixture()
	defer { parser_lifecycle_close(host) }
	parser_lifecycle_parse(host, r'<!doctype html><body><svg><script>globalThis.svgStage=document.getElementById("after-svg")===null;</script></svg><p id=after-svg>after</p>')
	parser_lifecycle_run_tasks()
	assert host.initialized
	assert host.runtime.evaluate_host('svgStage')! == 'true'
	assert host.document.get_element_by_id('after-svg') != none
}

@[heap]
struct ParserResourceImageHookProbe {
mut:
	requests int
}

fn test_failed_initial_script_still_loads_suffix_images_without_a_runtime() {
	$if !darwin && !linux { return }
	mut host := parser_lifecycle_fixture()
	defer { parser_lifecycle_close(host) }
	image_url := 'https://parser-lifecycle.example/suffix.png'
	mut images := host.images
	images.resources[image_url] = PreloadedResource{
		url: image_url
		source_url: host.document.url.serialize()
		request_type: 'image'
		body: base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=').bytestr()
	}
	parser_lifecycle_parse(host, '<!doctype html><body><img id=existing src=existing.png><script src=failed.js></script><img id=suffix src=suffix.png></body>')
	assert host.document.get_element_by_id('suffix') == none
	assert host.runtime == unsafe { nil }
	existing_element := host.document.get_element_by_id('existing') or { panic('missing earlier image') }
	mut existing := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(existing_element) })
	probe := &ParserResourceImageHookProbe{}
	existing.set_model_fetch_hook(fn [probe] (_ &html.HTMLImageElementModel, _ dom.URL) !html.DecodedImageData {
		mut observed := unsafe { &ParserResourceImageHookProbe(probe) }
		observed.requests++
		return error('preserved existing image hook')
	})
	parser_lifecycle_respond(mut host, 'failed.js', '', 'failed before runtime creation')
	assert host.runtime == unsafe { nil }
	suffix_element := host.document.get_element_by_id('suffix') or { panic('missing resumed image') }
	suffix := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(suffix_element) })
	assert suffix.has_fetch_hook() && suffix.complete() && suffix.natural_width() == 1
	assert suffix.event_count('load') == 1
	assert host.document.readiness() == .complete
	assert !host.document.anything_is_delaying_the_load_event()
	// Repeated parser/shell scans neither replace an existing client nor
	// restart the image that the resumed parser has already loaded.
	install_parser_document_resources(host.document, images, none)
	install_static_browser_image_fetch_hooks_with_loader(host.document, {}, images)
	assert suffix.event_count('load') == 1 && probe.requests == 0
	existing.update_the_image_data(false, false)
	assert probe.requests == 1
}

fn test_parser_time_scripts_observe_the_actual_viewport_and_restored_zoom() {
	$if !darwin && !linux {
		return
	}
	for zoom in [f64(1), 2] {
		mut app := BrowserApp{
			page_model:       page.Page.create(1)!
			script_policy:    .enabled
			layout_tree_only: true
			viewport_width:   1200
			viewport_height:  800
			zoom_levels:      browsersettings.open_zoom_levels('')!
		}
		defer { app.dispose_browser_tab() }
		app.zoom_levels.set_for_url('https://parser-viewport.test/', zoom)!
		app.install_loaded_page(LoadedPage{
			url:          'https://parser-viewport.test/page'
			content_type: 'text/html'
			markup:       r'<!doctype html><head><script>globalThis.parserViewport=[innerWidth,innerHeight,document.readyState,document.getElementById("later")===null];</script></head><body><p id=later>later</p>'
		}, false)
		assert app.js_runtime != unsafe { nil }
		expected := '${int(1200 / zoom)}|${int(800 / zoom)}|loading|true'
		assert app.js_runtime.evaluate_host('parserViewport.join("|")')! == expected
		assert app.page_zoom == zoom
		assert app.js_messages == []
	}
}

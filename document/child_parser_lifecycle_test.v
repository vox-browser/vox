module main

import adblock
import dom
import html
import page
import platform
import time

@[heap]
struct ChildParserContainerLoads {
mut:
	count int
}

fn child_parser_lifecycle_fixture() (&BrowserChildDocumentHost, &dom.Document) {
	owner := page.Page.create(1) or { panic(err) }
	document := parse_browser_navigation_document_for_page_with_response_time(
		'<!doctype html><iframe id="frame" style="width:240px;height:90px;padding:7px;border:5px solid black;visibility:hidden"></iframe>',
		dom.URL{value: 'https://child-parser.example/'}, none, none, unsafe { &dom.Page(owner) },
		time.sys_mono_now())
	return browser_child_document_host(document, .javascriptcore), document
}

fn child_parser_lifecycle_close(mut host BrowserChildDocumentHost, mut document dom.Document) {
	host.close()
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	document.release_native_storage()
}

// All fetch completions in these fixtures are explicit. Drain only runnable
// owner-thread work; a still-blocked parser must not make this loop wait.
fn child_parser_lifecycle_pump(mut host BrowserChildDocumentHost, mut messages []string) {
	for _ in 0 .. 128 {
		host.poll(mut messages)
		if !child_parser_lifecycle_run_one_task() { return }
	}
	assert false, 'child parser tasks did not settle'
}

fn child_parser_lifecycle_run_one_task() bool {
	mut plugin := platform.EventLoopPlugin.the()
	if plugin.run_one_deferred() { return true }
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	if task := loop.task_queue().take_first_runnable() {
		task.execute()
		return true
	}
	return false
}

fn child_parser_lifecycle_drain_native_tasks() {
	for _ in 0 .. 128 {
		if !child_parser_lifecycle_run_one_task() { return }
	}
	assert false, 'native child parser tasks did not settle'
}

fn child_parser_lifecycle_control_fetch(mut host BrowserChildDocumentHost, mut messages []string) {
	host.discover(host.root, mut messages)
	assert host.children.len == 1
	child := host.children[0]
	mut navigable := unsafe { &html.NavigableModel(child.navigable) }
	// Keep the production preparation callback, injecting only the transport so
	// parser and runtime ownership are exercised before the first response.
	navigable.set_document_created_hook(fn [host, child] (document &dom.Document) {
		host.prepare_document(child, document)
		mut service := child.prepared_service or { panic('missing prepared child service') }
		mut loader := service.scripts or { panic('missing child script loader') }
		loader.fetch = fn (_ string, _ string, _ chan PreloadedResource) {}
	})
}

fn child_parser_lifecycle_respond(service &BrowserHostedDocument, name string, source string) {
	loader := service.scripts or { panic('missing child script loader') }
	loader.results <- PreloadedResource{
		url: 'https://child-parser.example/${name}'
		source_url: service.document.url.serialize()
		request_type: 'script'
		body: source
	}
}

fn test_child_srcdoc_scripts_use_the_live_parser_and_keep_written_node_identity() {
	$if !darwin && !linux { return }
	mut host, mut parent := child_parser_lifecycle_fixture()
	defer { child_parser_lifecycle_close(mut host, mut parent) }
	// The child's viewport remains CSS pixels even when its parent uses device
	// coordinates for layout, before the child's first author script runs.
	parent.set_layout_coordinate_scale(2)
	mut frame := parent.get_element_by_id('frame') or { panic('missing frame') }
	frame.set_attribute_value('srcdoc', r'<!doctype html><body><p id=before>before</p><script id=writer>
globalThis.checks=[document.getElementById("before")!==null,document.getElementById("later")===null,document.currentScript.id==="writer",document.readyState==="loading",innerWidth===240,innerHeight===90];
document.write("<div id=written>first");
globalThis.saved=document.getElementById("written");
globalThis.clicks=0;saved.addEventListener("click",()=>clicks++);
saved.setAttribute("data-kept","yes");
document.write("<span>second</span></div>");
checks.push(saved===document.getElementById("written"),saved.getAttribute("data-kept")==="yes",saved.textContent==="firstsecond",document.getElementById("later")===null);
saved.dispatchEvent(new Event("click"));checks.push(clicks===1);
</script><p id=later>later</p><script>checks.push(document.getElementById("later")!==null);</script>')
	mut messages := []string{}
	child_parser_lifecycle_pump(mut host, mut messages)
	service := host.children[0].service or { panic('missing child service') }
	assert service.initialized && service.load_fired, messages.join('\n')
	assert service.runtime != unsafe { nil }, messages.join('\n')
	assert service.runtime.evaluate_host('checks.length===12&&checks.every(Boolean)')! == 'true'
	assert service.runtime.evaluate_host('saved===document.getElementById("written")&&document.currentScript===null')! == 'true'
	assert service.document.get_element_by_id('later') != none
	assert parent.get_element_by_id('written') == none
	assert !parent.anything_is_delaying_the_load_event()
}

fn test_child_parser_request_progresses_without_a_runtime_and_async_delays_only_load() {
	$if !darwin && !linux { return }
	mut host, mut parent := child_parser_lifecycle_fixture()
	defer { child_parser_lifecycle_close(mut host, mut parent) }
	mut messages := []string{}
	child_parser_lifecycle_control_fetch(mut host, mut messages)
	mut frame := parent.get_element_by_id('frame') or { panic('missing frame') }
	frame.set_attribute_value('srcdoc', '<!doctype html><body><p id=before>before</p><script id=block src=blocking.js></script><p id=later>later</p><script id=async async src=async.js></script>')
	child_parser_lifecycle_pump(mut host, mut messages)
	service := host.children[0].service or { panic('missing child service') }
	assert service.runtime == unsafe { nil }
	assert !service.initialized
	assert service.document.has_pending_parsing_blocking_script()
	assert service.document.get_element_by_id('later') == none
	assert service.resource_delay != none
	assert parent.anything_is_delaying_the_load_event()

	child_parser_lifecycle_respond(service, 'blocking.js', r'globalThis.events=["block"];globalThis.stage=document.getElementById("later")===null&&document.currentScript.id==="block";document.addEventListener("DOMContentLoaded",()=>events.push("ready"));window.addEventListener("load",()=>events.push("load"));')
	child_parser_lifecycle_pump(mut host, mut messages)
	assert service.runtime != unsafe { nil }, messages.join('\n')
	assert service.initialized && !service.load_fired
	assert service.document.get_element_by_id('later') != none
	assert service.document.ready_state() == 'interactive'
	assert service.resource_delay == none
	assert service.runtime.evaluate_host('stage&&events.join("|")==="block|ready"')! == 'true'
	assert parent.anything_is_delaying_the_load_event()

	child_parser_lifecycle_respond(service, 'async.js', r'events.push("async");globalThis.asyncCurrent=document.currentScript.id==="async";')
	child_parser_lifecycle_pump(mut host, mut messages)
	assert service.runtime.evaluate_host('asyncCurrent&&events.join("|")==="block|ready|async|load"')! == 'true'
	assert service.document.ready_state() == 'complete'
	assert service.load_fired
	assert !service.document.anything_is_delaying_the_load_event()
	assert !parent.anything_is_delaying_the_load_event()
}

fn test_removing_a_child_with_a_blocked_parser_retires_its_lazy_host_and_delays() {
	$if !darwin && !linux { return }
	mut host, mut parent := child_parser_lifecycle_fixture()
	defer { child_parser_lifecycle_close(mut host, mut parent) }
	mut messages := []string{}
	child_parser_lifecycle_control_fetch(mut host, mut messages)
	mut frame := parent.get_element_by_id('frame') or { panic('missing frame') }
	frame.set_attribute_value('srcdoc', '<!doctype html><script src=blocked.js></script><p id=later>later</p>')
	child_parser_lifecycle_pump(mut host, mut messages)
	child := host.children[0]
	mut service := child.service or { panic('missing child service') }
	assert service.runtime == unsafe { nil }
	assert service.document.anything_is_delaying_the_load_event()
	frame.as_node().remove(false)
	child_parser_lifecycle_pump(mut host, mut messages)
	assert child.closed && service.closed
	assert service.parser_host?.closed
	assert service.resource_delay == none
	assert !service.document.anything_is_delaying_the_load_event()
	assert !parent.anything_is_delaying_the_load_event()
	child_parser_lifecycle_respond(service, 'blocked.js', 'globalThis.obsolete=true')
	assert !service.poll(mut messages)
	assert service.runtime == unsafe { nil }
}

fn test_child_replacement_keeps_the_previous_realm_until_navigation_commits() {
	$if !darwin && !linux { return }
	mut host, mut parent := child_parser_lifecycle_fixture()
	defer { child_parser_lifecycle_close(mut host, mut parent) }
	mut frame := parent.get_element_by_id('frame') or { panic('missing frame') }
	frame.set_attribute_value('srcdoc', '<!doctype html><script>globalThis.marker="previous";</script>')
	mut messages := []string{}
	child_parser_lifecycle_pump(mut host, mut messages)
	child := host.children[0]
	previous := child.service or { panic('missing previous child service') }
	assert previous.runtime != unsafe { nil }, messages.join('\n')
	mut navigable := unsafe { &html.NavigableModel(child.navigable) }
	navigable.set_document_created_hook(fn [host, child, previous] (document &dom.Document) {
		host.prepare_document(child, document)
		assert !previous.closed
		current := child.service or { panic('previous service was detached before commit') }
		prepared := child.prepared_service or { panic('new service was not prepared before parsing') }
		assert voidptr(current.document) == voidptr(previous.document)
		assert voidptr(prepared.document) == voidptr(document)
	})
	frame.set_attribute_value('srcdoc', '<!doctype html><script>globalThis.marker="replacement";</script>')
	child_parser_lifecycle_pump(mut host, mut messages)
	assert previous.closed
	assert child.prepared_service == none
	current := child.service or { panic('missing replacement child service') }
	assert voidptr(current.document) != voidptr(previous.document)
	assert current.runtime.evaluate_host('marker')! == 'replacement'
}

fn test_reopened_child_stream_waits_for_async_and_rejects_stale_container_completion() {
	$if !darwin && !linux { return }
	mut host, mut parent := child_parser_lifecycle_fixture()
	defer { child_parser_lifecycle_close(mut host, mut parent) }
	mut messages := []string{}
	child_parser_lifecycle_control_fetch(mut host, mut messages)
	mut frame := parent.get_element_by_id('frame') or { panic('missing frame') }
	loads := &ChildParserContainerLoads{}
	frame.as_node().add_event_listener_without_options('load', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [loads] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &ChildParserContainerLoads(loads) }
			observed.count++
			return dom.js_undefined()
		}
	}))
	frame.set_attribute_value('srcdoc', '<!doctype html><script>globalThis.first=true;</script>')
	child_parser_lifecycle_pump(mut host, mut messages)
	service := host.children[0].service or { panic('missing child service') }
	assert loads.count == 1
	assert service.load_fired
	service.runtime.evaluate_host(r'document.open();globalThis.reopened=[];document.addEventListener("DOMContentLoaded",()=>reopened.push("ready"));window.addEventListener("load",()=>reopened.push("load"));document.write("<script async src=reopened.js><\/script><p id=tail>tail</p>");document.close();')!
	child_parser_lifecycle_pump(mut host, mut messages)
	assert loads.count == 1
	assert !service.load_fired
	assert service.document.ready_state() == 'interactive'
	assert service.runtime.evaluate_host('reopened.join("|")')! == 'ready'
	assert parent.anything_is_delaying_the_load_event()
	child_parser_lifecycle_respond(service, 'reopened.js', 'reopened.push("async");')
	child_parser_lifecycle_pump(mut host, mut messages)
	assert loads.count == 2
	assert service.runtime.evaluate_host('reopened.join("|")')! == 'ready|async|load'
	assert !parent.anything_is_delaying_the_load_event()
	child_parser_lifecycle_pump(mut host, mut messages)
	assert loads.count == 2

	// Queue a container completion for one stream, then replace that stream
	// before the queued task runs. It cannot fire or release the new delay.
	service.runtime.evaluate_host('document.open();document.write("<p>superseded</p>");document.close();')!
	child_parser_lifecycle_drain_native_tasks()
	assert service.document.ready_state() == 'complete'
	host.poll(mut messages)
	service.runtime.evaluate_host(r'document.open();document.write("<script async src=latest.js><\/script><p>latest</p>");document.close();')!
	child_parser_lifecycle_pump(mut host, mut messages)
	assert loads.count == 2
	assert parent.anything_is_delaying_the_load_event()
	child_parser_lifecycle_respond(service, 'latest.js', 'globalThis.latest=true;')
	child_parser_lifecycle_pump(mut host, mut messages)
	assert loads.count == 3
	assert service.runtime.evaluate_host('latest')! == 'true'
	assert !parent.anything_is_delaying_the_load_event()
}

fn child_parser_no_store_stylesheet(document &dom.Document, address string) PreloadedResource {
	return PreloadedResource{
		url: address
		final_url: address
		source_url: document.url.serialize()
		request_type: 'stylesheet'
		body: 'body { color: rgb(1, 2, 3) }'
		response_headers: [
			adblock.ResponseHeader{ name: 'Content-Type', value: 'text/css' },
			adblock.ResponseHeader{ name: 'Cache-Control', value: 'no-store' },
		]
	}
}

fn test_child_installed_no_store_stylesheet_does_not_delay_resource_initialization() {
	address := dom.URL{ value: 'https://child-styles.test/frame' }
	mut document := html.parse_navigation_document(
		'<!doctype html><link id="sheet" rel="stylesheet" href="installed.css"><p>child</p>',
		address, address.origin(), none)!
	defer {
		document.destroy_a_document_and_its_descendants()
		document.finalize()
	}
	link := document.get_element_by_id('sheet') or { panic('missing stylesheet owner') }
	response := child_parser_no_store_stylesheet(document, 'https://child-styles.test/installed.css')
	assert browser_response_forbids_storage(response.response_headers)
	assert complete_browser_link_stylesheet(link, response)
	native_link := unsafe { &dom.HTMLLinkElement(link) }
	sheet := native_link.linked_style_sheet_
	assert sheet != unsafe { nil }
	model := html.html_link_element_model_for_dom_element(native_link)
	loads := model.event_count('load')
	assert loads == 1

	// The completed response is deliberately absent from the resource cache.
	// The link's installed sheet already satisfies the child initialization.
	mut service := new_browser_hosted_document(document, .javascriptcore)
	defer { service.close() }
	assert service.resources.len == 0
	assert service.resource_delay != none
	assert document.anything_is_delaying_the_load_event()
	assert browser_hosted_stylesheet_resource_jobs(document).len == 0
	mut messages := []string{}
	service.initialize(mut messages)
	assert service.resources_started && service.initialized, messages.join('\n')
	assert service.remaining == 0
	assert service.results.len == 0
	assert service.resource_delay == none
	assert !document.anything_is_delaying_the_load_event()
	assert native_link.linked_style_sheet_ == sheet
	assert model.event_count('load') == loads
}

fn test_child_stylesheet_jobs_keep_unloaded_owners_and_deduplicate_their_urls() {
	address := dom.URL{ value: 'https://child-styles.test/frame' }
	mut document := html.parse_navigation_document(
		'<!doctype html><base href="/assets/">' +
		'<link id="installed" rel="stylesheet" href="shared.css">' +
		'<link id="pending" rel="stylesheet" href="shared.css">' +
		'<link id="other" rel="stylesheet" href="other.css">' +
		'<link id="duplicate" rel="stylesheet" href="other.css">' +
		'<link rel="preload" as="style" href="preload.css">' +
		'<link rel="preload" as="script" href="ignored.js">' +
		'<link rel="stylesheet" disabled href="ignored.css">' +
		'<link rel="alternate stylesheet" title="Other" href="ignored.css">' +
		'<script async type="application/json" src="ignored.css"></script>',
		address, address.origin(), none)!
	defer {
		document.destroy_a_document_and_its_descendants()
		document.finalize()
	}
	shared_url := 'https://child-styles.test/assets/shared.css'
	other_url := 'https://child-styles.test/assets/other.css'
	preload_url := 'https://child-styles.test/assets/preload.css'
	installed := document.get_element_by_id('installed') or { panic('missing installed link') }
	assert complete_browser_link_stylesheet(installed, child_parser_no_store_stylesheet(document, shared_url))
	jobs := browser_hosted_stylesheet_resource_jobs(document)
	assert jobs.len == 3
	assert jobs.any(it.url == shared_url)
	assert jobs.any(it.url == other_url)
	assert jobs.any(it.url == preload_url)
	for job in jobs { assert job.request_type == 'stylesheet' }

	// A loaded owner cannot suppress another owner still needing the same URL.
	// Once that second owner completes, only the other distinct requests remain.
	pending := document.get_element_by_id('pending') or { panic('missing pending link') }
	assert complete_browser_link_stylesheet(pending, child_parser_no_store_stylesheet(document, shared_url))
	remaining := browser_hosted_stylesheet_resource_jobs(document)
	assert remaining.len == 2
	assert remaining.any(it.url == other_url)
	assert remaining.any(it.url == preload_url)
	for id in ['other', 'duplicate'] {
		link := document.get_element_by_id(id) or { panic('missing duplicate link') }
		assert complete_browser_link_stylesheet(link, child_parser_no_store_stylesheet(document, other_url))
	}
	preloads := browser_hosted_stylesheet_resource_jobs(document)
	assert preloads.len == 1
	assert preloads[0].url == preload_url
}

fn test_same_origin_frame_without_scripts_installs_global_bindings_on_window_access() {
	mut host, mut parent := child_parser_lifecycle_fixture()
	defer { child_parser_lifecycle_close(mut host,mut parent) }
	mut frame := parent.get_element_by_id('frame') or { panic('frame') }
	frame.set_attribute_value('srcdoc','<!doctype html><meta http-equiv="Content-Security-Policy" content="script-src \'self\' \'unsafe-inline\'">')
	mut messages := []string{}
	child_parser_lifecycle_pump(mut host,mut messages)
	host.ensure_initial_realm(frame,mut messages)
	service := host.children[0].service or { panic('service') }
	assert service.runtime != unsafe { nil },messages.join('\n')
	assert service.runtime.evaluate_host('typeof setTimeout==="function"&&setTimeout("void 0",0)===0')! == 'true'
}

module main

import browserjs
import css
import dom
import html
import platform

fn style_preload_test_document(markup string) &dom.Document {
	address := dom.URL{ value: 'https://styles.test/board/' }
	return html.parse_navigation_document(markup, address, address.origin(), none) or { panic(err) }
}

fn test_style_preload_completion_can_promote_its_native_link_without_an_extra_fetch() {
	mut document := style_preload_test_document('<!doctype html><link id="preload" rel="preload" as="style" href="later.css"><p id="target">text</p>')
	document.enable_native_storage()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut app := BrowserApp{ document: document, background_resource_results: chan PreloadedResource{cap: 2} }
	address := 'https://styles.test/board/later.css'
	assert address in document_preload_resource_urls(document, document.base_url().serialize())
	assert document_preload_resource_types(document, document.base_url().serialize())[address] == 'stylesheet'
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.events=[];
document.addEventListener("load",event=>{if(event.target===preload)events.push("capture:"+preload.rel)},true);
preload.addEventListener("error",()=>events.push("error"));
preload.addEventListener("load",()=>{events.push(preload.sheet===null?"preload":"sheet");if(preload.rel==="preload")preload.rel="stylesheet"});
'], runtime, mut messages)
	assert messages == []string{}
	mut scratch := platform.begin_thread_scratch('style preload completion lifetime')
	app.queue_initial_style_preload_completions({
		address: PreloadedResource{ url: address.clone(), body: 'p { color: rgb(1,2,3) }'.clone(), source_url: document.url.serialize().clone(), request_type: 'stylesheet'.clone() }
	})
	scratch.finish()
	link := document.get_element_by_id('preload') or { panic('missing link') }
	assert css.style_sheet_for_owner_node(document, link) == none
	assert runtime.evaluate_host('events.length')! == '0'
	mut loop := html.main_thread_event_loop()
	mut tasks := loop.task_queue()
	for _ in 0 .. 10 {
		if task := tasks.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .networking
		}) {
			task.execute()
		} else {
			break
		}
	}
	// Replay the load listener's relationship mutation before scanning links.
	assert runtime.evaluate_host('preload.matches("[rel=stylesheet]")')! == 'true'
	assert app.request_script_inserted_stylesheets()
	assert css.style_sheet_for_owner_node(document, link) != none
	assert runtime.evaluate_host('JSON.stringify(events)')! == '["capture:preload","preload","capture:stylesheet","sheet"]'
	assert app.script_stylesheet_requests.len == 0
}

fn test_style_preload_failures_do_not_install_sheets_and_keep_each_link_owner() {
	mut document := style_preload_test_document('<!doctype html><link id="first" rel="preload" as="style" href="failed.css"><link id="second" rel="preload" as="style" href="failed.css"><link rel="preload" as="script" href="ignored.css">')
	defer { document.finalize() }
	mut app := BrowserApp{ document: document }
	address := 'https://styles.test/board/failed.css'
	app.queue_initial_style_preload_completions({
		address: PreloadedResource{ url: address, error: 'failed', request_type: 'stylesheet' }
	})
	mut loop := html.main_thread_event_loop()
	mut tasks := loop.task_queue()
	for _ in 0 .. 10 {
		if task := tasks.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .networking
		}) {
			task.execute()
		} else {
			break
		}
	}
	for id in ['first', 'second'] {
		link := document.get_element_by_id(id) or { panic('missing link') }
		model := html.html_link_element_model_for_dom_element(unsafe { &dom.HTMLLinkElement(link) })
		assert model.event_count('error') == 1
		assert model.event_count('load') == 0
		assert css.style_sheet_for_owner_node(document, link) == none
	}
}

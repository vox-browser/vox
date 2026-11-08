module main

import browserjs
import css
import dom
import html
import mimesniff
import platform

const max_browser_script_fetches = 8

type BrowserScriptFetch = fn (string, string, chan PreloadedResource)

@[heap]
struct BrowserScriptRequest {
	element &dom.Element
	url     string
	ordered bool
	// Parser-created elements keep scheduling, execution and events in HTML.
	parser_model ?&html.HTMLScriptElementModel
mut:
	ready     bool
	completed bool
	resource  PreloadedResource
	delayer   dom.DocumentLoadEventDelayer
}

// Own requests by element, rather than by URL: two elements fetching the same
// bundle still execute it twice and receive separate native completion events.
@[heap]
struct BrowserScriptRequestLoader {
	document &dom.Document
	results  chan PreloadedResource = chan PreloadedResource{cap: max_browser_script_fetches}
mut:
	requests       []&BrowserScriptRequest
	candidates     []&dom.Element
	queued         []string
	fetching       map[string]bool
	active_fetches int
	scan_version   u64
	scanned        bool
	cancelled      bool
	polling        bool
	fetch          BrowserScriptFetch = fetch_script_in_background
	resources      map[string]PreloadedResource
	parser_host    ?&BrowserParserScriptHost
}

fn new_browser_script_request_loader(document &dom.Document,
	resources map[string]PreloadedResource) &BrowserScriptRequestLoader {
	// A navigation can begin inside the outgoing document's task or frame arena.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return &BrowserScriptRequestLoader{document: document, resources: resources.clone()}
}

fn (loader &BrowserScriptRequestLoader) parser_fetch_hook() html.ScriptElementAsyncFetchHook {
	return fn [loader] (model &html.HTMLScriptElementModel, address dom.URL,
		kind html.ScriptElementType) ! {
		mut owner := unsafe { &BrowserScriptRequestLoader(loader) }
		owner.request_parser_script(model, address, kind)!
	}
}

// The parser has prepared the element and registered its execution order before
// calling this hook. This adapter supplies bytes only; HTML owns parser pauses,
// deferred/async execution, load-event delays and each element's load/error event.
fn (mut loader BrowserScriptRequestLoader) request_parser_script(model &html.HTMLScriptElementModel,
	address dom.URL, _ html.ScriptElementType) ! {
	if loader.cancelled { return error('Script loader is closed') }
	script := model.element() or { return error('Parser script has no DOM element') }
	element := unsafe { &dom.Element(script) }
	if voidptr(element.document()) != voidptr(loader.document) {
		return error('Parser script belongs to another document')
	}
	resource_url := address.serialize()
	if resource := loader.resources[resource_url] {
		filtered := filter_preloaded_resource(resource, loader.document.url.serialize(), 'script')!
		mut prepared := unsafe { &html.HTMLScriptElementModel(model) }
		prepared.complete_external_fetch(filtered.body)
		return
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	loader.requests << &BrowserScriptRequest{
		element: element
		url: resource_url.clone()
		parser_model: model
	}
	if resource_url !in loader.fetching {
		loader.fetching[resource_url] = true
		loader.queued << resource_url.clone()
	}
	loader.start_fetches()
}

// A paused parser may still encounter another element using an initial response.
// Keep those bytes until it reaches EOF, rather than dropping them at commit.
fn (mut loader BrowserScriptRequestLoader) finish_parsing() {
	loader.resources = map[string]PreloadedResource{}
}

fn fetch_script_in_background(address string, source string, results chan PreloadedResource) {
	fetch_resource_in_background(address, source, 'script', results)
	C.native_wake_browser()
}

fn (mut loader BrowserScriptRequestLoader) cancel() {
	loader.cancelled = true
	if mut host := loader.parser_host { host.closed = true }
	// Releasing a blocking model can schedule a resume check. Retirement must
	// not let that check parse more markup or prepare requests on a closed host.
	if parser := loader.document.active_parser() { parser.abort() }
	loader.queued = []string{}
	for mut request in loader.requests {
		if mut model := request.parser_model { model.cancel_external_fetch() }
		request.delayer.finish()
	}
	loader.requests = []&BrowserScriptRequest{}
	loader.candidates = []&dom.Element{}
	loader.resources = map[string]PreloadedResource{}
}

fn (mut loader BrowserScriptRequestLoader) start_fetches() {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	for !loader.cancelled && loader.active_fetches < max_browser_script_fetches && loader.queued.len > 0 {
		address := loader.queued[0]
		loader.queued.delete(0)
		loader.active_fetches++
		// Workers never retain DOM/model pointers or document-owned strings.
		source_url := loader.document.url.serialize().clone()
		spawn loader.fetch(address, source_url, loader.results)
	}
}

fn (mut loader BrowserScriptRequestLoader) discover() {
	if loader.cancelled || !browser_document_can_load_scripts(loader.document) { return }
	version := loader.document.dom_tree_version()
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if !loader.scanned || version != loader.scan_version {
		loader.scanned = true
		loader.scan_version = version
		loader.candidates = css.query_selector_all(loader.document.as_node(), 'script')
	}
	mut pending := []&dom.Element{}
	for element in loader.candidates {
		if !element.is_html_element() { continue }
		script := unsafe { &dom.HTMLScriptElement(element) }
		mut model := html.html_script_element_model_for_dom_element(script)
		if model.has_already_started() || model.is_parser_inserted() { continue }
		// Attribute changes do not advance the tree version. Retain unprepared
		// candidates so a later src/type change can prepare the existing element.
		if !element.has_attribute('src') {
			pending << element
			continue
		}
		type_ := if value := element.get_attribute('type') {
			value.trim_space()
		} else if value := element.get_attribute('language') {
			if value == '' { '' } else { 'text/${value}' }
		} else {
			''
		}
		// Dynamic module fetching/linking is a separate, still pending path.
		if type_ != '' && !mimesniff.is_javascript_mime_type_essence_match(type_) {
			pending << element
			continue
		}
		model.set_already_started(true)
		if element.has_attribute('nomodule') { continue }
		mut document := unsafe { &dom.Document(loader.document) }
		mut request := &BrowserScriptRequest{
			element: element
			url:     resolve_document_reference(element.get_attribute_value('src'), document.base_url().serialize())
			ordered: !html.html_script_element_async(script)
			delayer: dom.DocumentLoadEventDelayer.new(mut document)
		}
		loader.requests << request
		if element.get_attribute_value('src') == '' {
			request.ready = true
			request.resource = PreloadedResource{ url: request.url, source_url: document.url.serialize(), request_type: 'script', error: 'Empty external script URL' }
		} else if request.url !in loader.fetching {
			loader.fetching[request.url] = true
			loader.queued << request.url
		}
	}
	loader.candidates = pending
	loader.start_fetches()
}

fn (mut loader BrowserScriptRequestLoader) poll(runtime &browserjs.Runtime, mut messages []string) {
	// Script callbacks can spin the event loop. Leave responses in the channel
	// for the outer poll so their completion order survives that reentrancy.
	if loader.cancelled || loader.polling { return }
	loader.polling = true
	defer { loader.polling = false }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	loader.discover()
	loader.execute_ready(runtime, mut messages)
	for !loader.cancelled && loader.results.len > 0 {
		select {
			resource := <-loader.results {
				loader.active_fetches--
				loader.fetching.delete(resource.url)
				for mut request in loader.requests {
					if request.url == resource.url && !request.ready {
						request.resource = resource
						request.ready = true
					}
				}
				// Async scripts execute in completion order, even when several
				// fetches finish between two UI polls.
				loader.execute_ready(runtime, mut messages)
			}
			else {
				break
			}
		}
	}
	loader.start_fetches()
}

fn (mut loader BrowserScriptRequestLoader) execute_ready(runtime &browserjs.Runtime, mut messages []string) {
	mut ordered_waiting := false
	// A completion can enqueue another parser request. Retain each heap request
	// by value and read the current array again after reentrant preparation.
	request_count := loader.requests.len
	for index in 0 .. request_count {
		if loader.cancelled { return }
		mut request := loader.requests[index]
		if request.completed { continue }
		if request.ordered && ordered_waiting { continue }
		if !request.ready {
			if request.ordered { ordered_waiting = true }
			continue
		}
		if request.parser_model == none && runtime == unsafe { nil } { continue }
		request.completed = true
		// Removal alone does not cancel an already prepared script. Adoption
		// into another document, however, must not execute in the old realm.
		if voidptr(request.element.document()) != voidptr(loader.document)
			|| !compact_document_can_run_script(loader.document) {
			if mut model := request.parser_model { model.cancel_external_fetch() }
			request.delayer.finish()
			continue
		}
		if mut model := request.parser_model {
			if resource := filter_preloaded_resource(request.resource, loader.document.url.serialize(), 'script') {
				model.complete_external_fetch(resource.body)
			} else {
				messages << 'Script ${request.url}: ${err.msg()}'
				model.complete_external_fetch(none)
			}
			continue
		}
		mut event_name := 'load'
		if resource := filter_preloaded_resource(request.resource, loader.document.url.serialize(), 'script') {
			run_compact_document_script(loader.document, browserjs.ScriptSource{
				code:             resource.body
				url:              request.url
				external_element: request.element
			}, runtime) or { messages << 'JavaScript dynamic script: ${err.msg()}' }
		} else {
			event_name = 'error'
			messages << 'Script ${request.url}: ${err.msg()}'
		}
		runtime.dispatch_external_script_event(request.element, event_name) or {
			messages << 'JavaScript script completion: ${err.msg()}'
		}
		request.delayer.finish()
		mut mutable_runtime := unsafe { &browserjs.Runtime(runtime) }
		mutable_runtime.mark_document_state_dirty()
	}
	loader.requests = loader.requests.filter(!it.completed)
}

fn run_compact_document_script(owner &dom.Document, source browserjs.ScriptSource, runtime &browserjs.Runtime) ! {
	mut document := unsafe { &dom.Document(owner) }
	previous := document.current_script()
	defer { document.set_current_script(previous) }
	document.set_current_script(none)
	if source.source_type == .script {
		mut candidate := source.element
		if candidate == none { candidate = source.external_element }
		if element := candidate {
			if element.is_html_element() && element.local_name() == 'script' && !element.as_node().root().is_shadow_root() {
				document.set_current_script(unsafe { &dom.HTMLScriptElement(element) })
			}
		}
	}
	runtime.run_document_scripts([source])!
}

fn (mut app BrowserApp) poll_browser_script_requests() {
	mut loader := app.script_request_loader or { return }
	if voidptr(app.document) != voidptr(loader.document) {
		return
	}
	loader.poll(app.js_runtime, mut app.js_messages)
	// Completion callbacks can insert another bundle before window.load.
	if app.js_runtime != unsafe { nil } { app.poll_javascript_tasks() }
	if voidptr(app.document) == voidptr(loader.document) { loader.discover() }
}

fn copy_compact_script_started_state(original &dom.Node, copy &dom.Node) {
	if element := original.as_element() {
		if element.is_html_element() && element.local_name() == 'script' {
			if copy_element := copy.as_element() {
				model := html.html_script_element_model_for_dom_element(unsafe { &dom.HTMLScriptElement(element) })
				mut copy_model := html.html_script_element_model_for_dom_element(unsafe { &dom.HTMLScriptElement(copy_element) })
				copy_model.set_already_started(model.has_already_started())
			}
		}
	}
	mut child := original.first_child()
	mut child_copy := copy.first_child()
	for {
		original_child := child or { break }
		copied_child := child_copy or { break }
		copy_compact_script_started_state(original_child, copied_child)
		child = original_child.next_sibling()
		child_copy = copied_child.next_sibling()
	}
}

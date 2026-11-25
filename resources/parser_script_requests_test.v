module main

import browserjs
import browsernet
import dom
import html

@[heap]
struct ParserScriptRequestObservations {
mut:
	sources []string
	later_visible []bool
}

fn parser_script_request_fixture(markup string, resources map[string]PreloadedResource) (&dom.Document, &html.HTMLParser, &BrowserScriptRequestLoader, &ParserScriptRequestObservations) {
	address := dom.URL{value: 'https://parser-requests.test/'}
	mut document := html.create_navigation_document(address, address.origin(), none) or { panic(err) }
	document.set_ready_to_run_scripts()
	mut loader := new_browser_script_request_loader(document, resources)
	// Deliver responses explicitly so fetch completion order is deterministic.
	loader.fetch = fn (_ string, _ string, _ chan PreloadedResource, _ &browsernet.RequestScope) {}
	observations := &ParserScriptRequestObservations{}
	mut parser := html.HTMLParser.create(document, markup)
	parser.set_script_hooks(none, fn [document, observations] (_ html.ScriptElementType,
		source string, _ dom.URL) ! {
		mut observed := unsafe { &ParserScriptRequestObservations(observations) }
		observed.sources << source
		observed.later_visible << (document.get_element_by_id('later') != none)
	})
	parser.set_async_script_fetch_hook(loader.parser_fetch_hook())
	return document, parser, loader, observations
}

fn parser_script_request_response(loader &BrowserScriptRequestLoader, name string,
	source string, failure string) {
	loader.results <- PreloadedResource{
		url: 'https://parser-requests.test/${name}'
		source_url: loader.document.url.serialize()
		request_type: 'script'
		body: source
		error: failure
	}
}

fn parser_script_request_drain_tasks() {
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 64 {
		if !loop.task_queue().has_runnable_tasks() { return }
		loop.process()
	}
	assert !loop.task_queue().has_runnable_tasks(), 'parser script tasks did not settle'
}

fn parser_script_request_model(document &dom.Document, id string) &html.HTMLScriptElementModel {
	element := document.get_element_by_id(id) or { panic('missing script ${id}') }
	return html.html_script_element_model_for_dom_element(unsafe { &dom.HTMLScriptElement(element) })
}

fn test_parser_script_response_resumes_the_live_parser_without_a_runtime() {
	mut document, mut parser, mut loader, observed := parser_script_request_fixture(
		'<!doctype html><p id="before">Before</p><script id="block" src="blocking.js"></script><p id="later">After</p>', {})
	defer { loader.cancel(); document.finalize() }
	mut messages := []string{}
	parser.run()
	assert parser.paused()
	assert document.get_element_by_id('before') != none
	assert document.get_element_by_id('later') == none
	assert loader.requests.len == 1 && loader.active_fetches == 1
	assert document.anything_is_delaying_the_load_event()
	parser_script_request_response(loader, 'blocking.js', 'blocking', '')
	loader.poll(unsafe { &browserjs.Runtime(nil) }, mut messages)
	parser_script_request_drain_tasks()
	assert messages == []
	assert observed.sources == ['blocking']
	assert observed.later_visible == [false]
	assert !parser.paused()
	assert document.get_element_by_id('later') != none
	assert parser_script_request_model(document, 'block').event_count('load') == 1
	assert loader.requests.len == 0 && loader.active_fetches == 0
	assert !document.anything_is_delaying_the_load_event()
}

fn test_parser_async_requests_share_transport_but_complete_each_element_once() {
	mut document, mut parser, mut loader, observed := parser_script_request_fixture(
		'<!doctype html><html><head><script id="one" async src="shared.js"></script><script id="two" async src="shared.js"></script><script>inline</script></head><body><p id="later">Ready</p></body></html>', {})
	defer { loader.cancel(); document.finalize() }
	mut messages := []string{}
	parser.run()
	assert !parser.paused()
	assert document.get_element_by_id('later') != none
	assert observed.sources == ['inline']
	assert loader.requests.len == 2 && loader.active_fetches == 1
	parser_script_request_response(loader, 'shared.js', 'shared', '')
	loader.poll(unsafe { &browserjs.Runtime(nil) }, mut messages)
	parser_script_request_drain_tasks()
	assert messages == []
	assert observed.sources == ['inline', 'shared', 'shared']
	assert observed.later_visible == [false, true, true]
	for id in ['one', 'two'] {
		model := parser_script_request_model(document, id)
		assert model.event_count('load') == 1
		assert model.event_count('error') == 0
	}
	assert loader.requests.len == 0
	assert !document.anything_is_delaying_the_load_event()
}

fn test_parser_async_responses_preserve_completion_order_between_polls() {
	mut document, mut parser, mut loader, observed := parser_script_request_fixture(
		'<!doctype html><script async src="one.js"></script><script async src="two.js"></script><p id="later">Ready</p>', {})
	defer { loader.cancel(); document.finalize() }
	mut messages := []string{}
	parser.run()
	parser_script_request_response(loader, 'two.js', 'two', '')
	parser_script_request_response(loader, 'one.js', 'one', '')
	loader.poll(unsafe { &browserjs.Runtime(nil) }, mut messages)
	parser_script_request_drain_tasks()
	assert messages == []
	assert observed.sources == ['two', 'one']
	assert loader.active_fetches == 0
	assert !document.anything_is_delaying_the_load_event()
}

fn test_parser_loader_consumes_preload_failures_without_retrying() {
	address := 'https://parser-requests.test/failed.js'
	mut document, mut parser, mut loader, observed := parser_script_request_fixture(
		'<!doctype html><script id="failed" src="failed.js"></script><p id="later">Ready</p>', {
		address: PreloadedResource{url: address, source_url: 'https://parser-requests.test/', request_type: 'script', error: 'preloaded failure'}
	})
	defer { loader.cancel(); document.finalize() }
	parser.run()
	parser_script_request_drain_tasks()
	assert observed.sources == []
	assert document.get_element_by_id('later') != none
	assert loader.requests.len == 0 && loader.active_fetches == 0
	model := parser_script_request_model(document, 'failed')
	assert model.event_count('error') == 1 && model.event_count('load') == 0
	assert !document.anything_is_delaying_the_load_event()
	loader.finish_parsing()
	assert loader.resources.len == 0
}

fn test_parser_loader_cancellation_releases_delays_and_ignores_late_responses() {
	mut document, mut parser, mut loader, observed := parser_script_request_fixture(
		'<!doctype html><script id="cancelled" async src="pending.js"></script><p id="later">Ready</p>', {})
	defer { document.finalize() }
	mut messages := []string{}
	parser.run()
	assert document.anything_is_delaying_the_load_event()
	scope := loader.request_scope
	scope.retain()
	defer { scope.release() }
	loader.cancel()
	assert scope.is_cancelled()
	assert !publish_resource_result(PreloadedResource{}, loader.results, scope)
	loader.cancel()
	assert !document.anything_is_delaying_the_load_event()
	assert !document.has_scripts_to_execute_as_soon_as_possible()
	parser_script_request_response(loader, 'pending.js', 'late', '')
	loader.poll(unsafe { &browserjs.Runtime(nil) }, mut messages)
	parser_script_request_drain_tasks()
	assert observed.sources == []
	assert messages == []
	model := parser_script_request_model(document, 'cancelled')
	assert model.event_count('error') == 0 && model.event_count('load') == 0
}

fn test_cancelling_a_parser_request_does_not_resume_the_retired_document() {
	mut document, mut parser, mut loader, observed := parser_script_request_fixture(
		'<!doctype html><script src="pending.js"></script><p id="later">Unparsed</p><script>must not run</script>', {})
	defer { document.finalize() }
	mut messages := []string{}
	parser.run()
	assert parser.paused()
	loader.cancel()
	parser_script_request_response(loader, 'pending.js', 'late', '')
	loader.poll(unsafe { &browserjs.Runtime(nil) }, mut messages)
	parser_script_request_drain_tasks()
	assert parser.aborted()
	assert document.get_element_by_id('later') == none
	assert observed.sources == []
	assert !document.anything_is_delaying_the_load_event()
}

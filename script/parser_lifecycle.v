module main

import browserjs
import dom
import html

type BrowserParserRuntimeCreated = fn (&browserjs.Runtime)

// The parser owns script positions, scheduling and readiness. This adapter only
// supplies the document's runtime and resource service. It also installs on
// parsers created by document.open() and streamed child navigations.
@[heap]
struct BrowserParserScriptHost {
	document          &dom.Document
	engine            browserjs.Engine
	images            &BrowserImageRequestLoader
	scripts           &BrowserScriptRequestLoader
	media_loader      ?browserjs.MediaElementCreatedHook
	on_runtime_created ?BrowserParserRuntimeCreated
mut:
	runtime           &browserjs.Runtime = unsafe { nil }
	initial_resources map[string]PreloadedResource
	svg_resources     map[string]PreloadedResource
	messages          []string
	initialized       bool
	initialization_attempted bool
	closed            bool
	parser_generation u64
}

fn install_browser_parser_script_host(document &dom.Document, engine browserjs.Engine,
	images &BrowserImageRequestLoader, scripts &BrowserScriptRequestLoader,
	resources map[string]PreloadedResource, media_loader ?browserjs.MediaElementCreatedHook,
	on_runtime_created ?BrowserParserRuntimeCreated) &BrowserParserScriptHost {
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
	host := &BrowserParserScriptHost{
		document: document
		engine: engine
		images: images
		scripts: scripts
		initial_resources: resources.clone()
		media_loader: media_loader
		on_runtime_created: on_runtime_created
	}
	mut loader := unsafe { &BrowserScriptRequestLoader(scripts) }
	loader.parser_host = host
	html.install_document_fragment_parsing_hook(document)
	html.install_document_parser_creation_hook(document, voidptr(host), browser_parser_created)
	return host
}

fn browser_parser_created(target voidptr, parser &html.HTMLParser) {
	mut host := unsafe { &BrowserParserScriptHost(target) }
	host.parser_generation++
	mut owner := unsafe { &html.HTMLParser(parser) }
	// SVG's translated element uses the synchronous fetch/execute interface.
	// HTML elements use the asynchronous, element-aware hooks below.
	owner.set_script_hooks(fn [host] (address dom.URL, _ html.ScriptElementType) !string {
		if resource := host.initial_resources[address.serialize()] {
			return filter_preloaded_resource(resource, host.document.url.serialize(), 'script')!.body
		}
		return fetch_text_resource_for_request(address.serialize(), '', host.document.url.serialize(), 'script')!
	}, fn [host] (kind html.ScriptElementType, source string, address dom.URL) ! {
		mut binding := unsafe { &BrowserParserScriptHost(host) }
		mut document := unsafe { &dom.Document(host.document) }
		previous := document.current_script()
		document.set_current_script(none)
		defer { document.set_current_script(previous) }
		binding.run_script(browserjs.ScriptSource{
			code: source
			url: address.serialize()
			source_type: if kind == .module { .module } else { .script }
		})!
	})
	owner.set_async_script_fetch_hook(host.scripts.parser_fetch_hook())
	owner.set_script_execute_hook_with_element(fn [host] (element &dom.HTMLScriptElement, kind html.ScriptElementType, source string, address dom.URL) ! {
		mut binding := unsafe { &BrowserParserScriptHost(host) }
		binding.execute(element, kind, source, address)!
	})
	owner.add_parsing_complete_callback(fn [host] () {
		mut binding := unsafe { &BrowserParserScriptHost(host) }
		binding.did_finish_parsing()
	})
}

fn (mut host BrowserParserScriptHost) initialize() bool {
	if host.closed || host.document.has_been_destroyed() { return false }
	if host.initialization_attempted { return host.initialized }
	if !host.document.as_node().is_scripting_enabled() { return false }
	host.initialization_attempted = true
	host.runtime = create_browser_script_runtime(host.engine)
	if callback := host.on_runtime_created { callback(host.runtime) }
	host.initialized = initialize_document_script_runtime(host.document, host.document.url.serialize(),
		[]browserjs.ScriptSource{}, host.runtime, browser_fetch_image_request, host.images.callback(),
		host.scripts, host.media_loader, mut host.messages)
	mut runtime := host.runtime
	runtime.add_close_handler(fn [host] () {
		mut binding := unsafe { &BrowserParserScriptHost(host) }
		binding.closed = true
	})
	return host.initialized
}

fn (mut host BrowserParserScriptHost) execute(script &dom.HTMLScriptElement,
	kind html.ScriptElementType, source string, address dom.URL) ! {
	element := unsafe { &dom.Element(script) }
	host.run_script(browserjs.ScriptSource{
		code: source
		url: address.serialize()
		source_type: if kind == .module { .module } else { .script }
		element: element
		external_element: if element.has_attribute('src') { ?&dom.Element(element) } else { none }
	})!
}

fn (mut host BrowserParserScriptHost) run_script(source browserjs.ScriptSource) ! {
	install_parser_document_resources(host.document, host.images, host.media_loader)
	host.messages << install_parser_external_styles(host.document,
		host.document.base_url().serialize(), host.initial_resources)
	if !host.initialize() { return error('Document script runtime is unavailable') }
	if !compact_document_can_run_script(host.document) { return }
	if host.engine != .libjs { host.runtime.evaluate_host('__ladybirdRefreshNamedElements()')! }
	// The element model sets currentScript and restores it across nested writes.
	// Each evaluation flushes mutations before the parser consumes another token.
	host.runtime.run_document_scripts([source])!
	if host.engine != .libjs {
		flush_compact_dom_mutations(host.document, host.runtime)!
	}
	mut runtime := host.runtime
	runtime.mark_document_state_dirty()
	host.scripts.discover()
}

fn (mut host BrowserParserScriptHost) did_finish_parsing() {
	if host.closed || host.document.has_been_destroyed() { return }
	mut document := unsafe { &dom.Document(host.document) }
	document.obtain_supported_color_schemes()
	install_parser_document_resources(document, host.images, host.media_loader)
	// A resumed parser can discover links after the shell's first resource scan.
	// Install those before end-of-parsing tasks can publish document readiness.
	host.messages << install_parser_external_styles(document, document.base_url().serialize(),
		host.initial_resources)
	host.install_svg_use_resources()
	// Raw Window handlers need bindings before the parser queues readiness tasks,
	// even when the document contains no script element.
	if document_has_window_event_handlers(document) || browser_adblock_requires_runtime(document) {
		host.initialize()
	}
	if host.initialized {
		if host.engine != .libjs {
			host.runtime.evaluate_host('__ladybirdRefreshNamedElements()') or {
				host.messages << 'JavaScript named elements: ${err.msg()}'
			}
		}
		host.scripts.discover()
		mut runtime := host.runtime
		runtime.mark_document_state_dirty()
	}
	if document.has_page() { start_browser_child_navigations(document, host.engine, mut host.messages) }
	host.scripts.finish_parsing()
	host.initial_resources = map[string]PreloadedResource{}
	document.request_frame()
}

fn (mut host BrowserParserScriptHost) flush(mut messages []string) ?string {
	messages << host.messages
	host.messages = []string{}
	if !host.initialized || host.closed || host.engine == .libjs { return none }
	commit := commit_compact_dom_task(host.document, host.runtime, mut messages) or {
		messages << 'JavaScript parser state: ${err.msg()}'
		return none
	}
	return commit.navigation
}

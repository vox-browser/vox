module html

import dom
import fetch

@[heap]
struct EmbedderScriptFetchObservation {
mut:
	requests         []string
	javascript_calls int
}

fn embedder_script_fetch_document() !&dom.Document {
	document_url := dom.URL{
		value: 'https://wikipedia.org/'
	}
	mut document := create_navigation_document(document_url, document_url.origin(), none)!
	document.set_scripting_enabled_by_embedder(false)
	return document
}

fn test_embedder_disabled_speculation_skips_scripts_and_modules_but_keeps_render_resources() {
	mut document := embedder_script_fetch_document()!
	defer { document.finalize() }
	observation := &EmbedderScriptFetchObservation{}
	input := '<script src="classic.js"></script><script type="module" src="module.js"></script><link rel="modulepreload" href="module-preload.js"><link rel="modulepreload" as="style" href="module.css"><link rel="modulepreload" as="json" href="data.json"><link rel="preload" as="script" href="preload.js"><link rel="stylesheet" href="style.css"><link rel="preload" as="style" href="preload.css"><link rel="preload" as="font" href="font.woff2"><img src="image.png">'
	mut parser := SpeculativeHTMLParser.create(document, input, document.base_url(), fn [observation] (request PotentialCORSRequest) {
		mut state := unsafe { &EmbedderScriptFetchObservation(observation) }
		state.requests << request.url.serialize()
	})
	parser.run()
	assert observation.requests == ['https://wikipedia.org/style.css',
		'https://wikipedia.org/preload.css', 'https://wikipedia.org/font.woff2',
		'https://wikipedia.org/image.png']
	for source in ['classic.js', 'module.js', 'module-preload.js', 'module.css', 'data.json',
		'preload.js'] {
		assert !document.has_speculative_fetch_url(dom.URL{ value: 'https://wikipedia.org/${source}' })
	}
}

fn test_embedder_disabled_link_preloads_skip_fetch_module_maps_and_error_events() {
	mut document := embedder_script_fetch_document()!
	defer { document.finalize() }
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut mutable_settings := unsafe { &EnvironmentSettingsObject(settings) }
	mutable_settings.set_script_fetch_hook(fn (_ &fetch.Request, _ TopLevelModule) !&fetch.Response {
		panic('disabled modulepreloads must not fetch')
	})
	for destination in ['', 'script', 'style', 'json', 'text', 'image', 'invalid'] {
		mut module_link := HTMLLinkElementModel.create(document.base_url())
		module_link.set_parser_document(document)
		module_link.set_rel('modulepreload')
		module_link.set_href('/module.js')
		module_link.set_as(destination)
		module_link.fetch_and_process_linked_resource()
		assert module_link.event_count('load') == 0
		assert module_link.event_count('error') == 0
	}
	assert settings.module_map().values_.len == 0
	assert settings.realm().reported_exceptions.len == 0
	mut script_link := HTMLLinkElementModel.create(document.base_url())
	script_link.set_parser_document(document)
	script_link.set_rel('preload')
	script_link.set_href('/classic.js')
	script_link.set_as('script')
	script_link.set_fetch_hook(fn (_ dom.URL, _ LinkResourceKind, _ CORSSettingAttribute) !LinkResourceResponse {
		panic('disabled script preloads must not fetch')
	})
	script_link.fetch_and_process_linked_resource()
	mut direct_options := LinkProcessingOptions{
		href:        '/direct.js'
		base_url:    document.base_url()
		document:    document
		destination: 'script'
	}
	script_link.preload(mut direct_options)
	assert script_link.preloaded_response_ == none
	assert script_link.event_count('load') == 0
	assert script_link.event_count('error') == 0

	// CSS remains fetchable through the same link lifecycle.
	script_link.set_as('style')
	script_link.set_href('/site.css')
	script_link.set_fetch_hook(fn (resource_url dom.URL, kind LinkResourceKind, _ CORSSettingAttribute) !LinkResourceResponse {
		assert resource_url.serialize() == 'https://wikipedia.org/site.css'
		assert kind == .preload
		return LinkResourceResponse{
			content_type: 'text/css'
			body:         'body { color: green; }'.bytes()
		}
	})
	script_link.fetch_and_process_linked_resource()
	assert script_link.event_count('load') == 1
	assert script_link.event_count('error') == 0
}

fn test_javascript_url_checks_current_document_scripting_before_the_host_hook() {
	mut document := embedder_script_fetch_document()!
	defer { document.finalize() }
	host := document.navigable()?
	mut model := navigable_model_for_host(host)?
	observation := &EmbedderScriptFetchObservation{}
	model.set_javascript_url_hook(fn [observation] (source string, owner &dom.Document) ?string {
		mut state := unsafe { &EmbedderScriptFetchObservation(observation) }
		state.javascript_calls++
		assert source == "'generated'"
		assert owner.is_scripting_enabled_by_embedder()
		return '<!doctype html><p>generated</p>'
	})
	script_url := dom.URL{
		value: "javascript:'generated'"
	}
	assert model.evaluate_javascript_url(script_url, document.origin(), .none, '') == none
	assert observation.javascript_calls == 0
	document.set_scripting_enabled_by_embedder(true)
	assert model.evaluate_javascript_url(script_url, document.origin(), .none, '') != none
	assert observation.javascript_calls == 1
	document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_scripts))
	assert model.evaluate_javascript_url(script_url, document.origin(), .none, '') == none
	assert observation.javascript_calls == 1
}

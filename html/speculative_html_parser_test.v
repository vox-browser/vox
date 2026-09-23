@[has_globals]
module html

import dom

__global speculative_parser_requests []PotentialCORSRequest

fn record_speculative_parser_request(request PotentialCORSRequest) {
	speculative_parser_requests << request
}

fn test_speculative_parser_tracks_base_filters_subtrees_and_deduplicates_urls() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/root/page.html' })
	speculative_parser_requests.clear()
	input := '<base href="/assets/"><script src="app.js" crossorigin></script><img src="logo.png"><img src="logo.png"><template><img src="hidden.png"></template><svg><script src="foreign.js"></script></svg><link rel="PRELOAD stylesheet" href="site.css" as="image"><link rel="preload" href="font.woff2" as="font" crossorigin="use-credentials"><link rel="preload" href="ignored.bin" as="invalid"><link rel="preload" href="uppercase.png" as="IMAGE">'
	mut parser := SpeculativeHTMLParser.create(document, input, document.base_url(), record_speculative_parser_request)
	parser.run()

	assert speculative_parser_requests.len == 4
	assert speculative_parser_requests[0].url.serialize() == 'https://example.test/assets/app.js'
	assert speculative_parser_requests[0].destination? == .script
	assert speculative_parser_requests[0].mode == .cors
	assert speculative_parser_requests[1].url.serialize() == 'https://example.test/assets/logo.png'
	assert speculative_parser_requests[1].destination? == .image
	assert speculative_parser_requests[2].destination? == .style
	assert speculative_parser_requests[3].destination? == .font
	assert speculative_parser_requests[3].credentials_mode == .include
	assert !document.has_speculative_fetch_url(dom.URL{ value: 'https://example.test/assets/uppercase.png' })
	assert !document.has_speculative_fetch_url(dom.URL{ value: 'https://example.test/assets/hidden.png' })
	assert !document.has_speculative_fetch_url(dom.URL{ value: 'https://example.test/assets/foreign.js' })
}

fn test_blocked_html_parser_scans_and_stops_the_remaining_input() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/page.html' })
	document.set_ready_to_run_scripts()
	mut blocking_style := document.create_element_ns('http://www.w3.org/1999/xhtml', 'style')!
	document.script_blocking_style_sheet_set << blocking_style
	speculative_parser_requests.clear()
	mut parser := HTMLParser.create(document, '<script>blocked()</script><img src="later.png">')
	parser.scripting_mode = .normal
	parser.set_speculative_fetch_hook(record_speculative_parser_request)
	parser.run()

	assert parser.paused()
	assert parser.has_active_speculative_html_parser()
	assert speculative_parser_requests.len == 1
	assert speculative_parser_requests[0].url.serialize() == 'https://example.test/later.png'

	parser.abort()
	assert !parser.has_active_speculative_html_parser()
}

fn test_speculative_parser_scans_modulepreload_without_module_map_side_effects() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/page.html' })
	window := WindowModel.create_top_level(document, none, 'modulepreload-scanner') or {
		panic(err)
	}
	settings_pointer := document.relevant_settings_object()
	assert settings_pointer != unsafe { nil }
	settings := unsafe { &EnvironmentSettingsObject(settings_pointer) }
	_ = window
	speculative_parser_requests.clear()
	input := '<link rel="modulepreload" href="module.js" nonce="abc" integrity="sha256-xyz" referrerpolicy="origin" fetchpriority="high"><link rel="modulepreload" href="data.json" as="JSON" crossorigin="use-credentials"><link rel="modulepreload" href="default.js" as="invalid"><link rel="modulepreload" href="image.png" as="image"><link rel="modulepreload" href="hidden.js" media="not all"><link rel="modulepreload preload" href="fetch.bin" as="fetch">'
	mut parser := SpeculativeHTMLParser.create(document, input, document.base_url(),
		record_speculative_parser_request)
	parser.run()

	assert speculative_parser_requests.len == 3
	module_request := speculative_parser_requests[0]
	assert module_request.url.serialize() == 'https://example.test/module.js'
	assert module_request.destination? == .script
	assert module_request.mode == .cors
	assert module_request.credentials_mode == .same_origin
	assert module_request.is_module_preload
	assert module_request.cryptographic_nonce_metadata == 'abc'
	assert module_request.integrity_metadata == 'sha256-xyz'
	assert module_request.parser_metadata == .not_parser_inserted
	assert module_request.referrer_policy == 'origin'
	assert module_request.priority == .high

	json_request := speculative_parser_requests[1]
	assert json_request.destination? == .json
	assert json_request.credentials_mode == .include
	assert speculative_parser_requests[2].destination? == .script
	assert !document.has_speculative_fetch_url(dom.URL{ value: 'https://example.test/image.png' })
	assert !document.has_speculative_fetch_url(dom.URL{ value: 'https://example.test/hidden.js' })
	assert !document.has_speculative_fetch_url(dom.URL{ value: 'https://example.test/fetch.bin' })
	assert settings.module_map().get(dom.URL{ value: 'https://example.test/module.js' },
		'javascript-or-wasm') == none
}

fn test_html_tokenizer_exposes_only_unparsed_code_points() {
	mut tokenizer := HTMLTokenizer.new('one<span>two</span>')
	for {
		token := tokenizer.next_token() or { break }
		if token.is_start_tag() {
			break
		}
	}
	assert tokenizer.unparsed_input() == 'two</span>'
}

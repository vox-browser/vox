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
	input := '<base href="/assets/"><script src="app.js" crossorigin></script><img src="logo.png"><img src="logo.png"><template><img src="hidden.png"></template><svg><script src="foreign.js"></script></svg><link rel="PRELOAD stylesheet" href="site.css" as="image"><link rel="preload" href="font.woff2" as="font" crossorigin="use-credentials"><link rel="preload" href="ignored.bin" as="invalid">'
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

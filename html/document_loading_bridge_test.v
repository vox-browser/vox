module html

import dom

fn loading_navigation_params(associated &dom.Document, mime_type string, body []u8) &dom.NavigationParams {
	return &dom.NavigationParams{
		response_mime_type:         mime_type
		response_body:              body
		response_url:               dom.URL{ value: 'https://example.test/resource' }
		html_fragment_parsing_hook: associated.html_fragment_parsing_hook()
	}
}

fn test_document_loader_uses_translated_html_parser_and_encoding_detection() {
	associated := parse_document('<!doctype html>')
	body := '<!doctype html><title>Loaded</title><p id="content">Привет</p>'.bytes()
	params := loading_navigation_params(associated, 'text/html;charset=utf-8', body)
	mut document := dom.load_document(params, body) or { panic('HTML load failed') }
	assert document.has_deferred_parser_start()
	assert document.document_element() == none
	document.set_ready_to_run_scripts()
	assert !document.has_deferred_parser_start()
	assert document.document_type() == .html
	assert document.title() == 'Loaded'
	assert document.get_element_by_id('content')?.as_node().text_content()? == 'Привет'
}

fn test_document_loader_uses_translated_xml_builder_and_mime_parameters() {
	associated := parse_document('<!doctype html>')
	body := '<?xml version="1.0"?><root xmlns="urn:test"><item>A &amp; B</item></root>'.bytes()
	params := loading_navigation_params(associated, 'application/xml;charset=utf-8', body)
	mut document := dom.load_document(params, body) or { panic('XML load failed') }
	assert document.has_deferred_parser_start()
	document.set_ready_to_run_scripts()
	root := document.document_element() or { panic('missing XML root') }
	assert document.document_type() == .xml
	assert root.local_name() == 'root'
	assert root.namespace_uri()? == 'urn:test'
	assert root.as_node().text_content()? == 'A & B'
}

fn test_document_loader_uses_translated_plaintext_tokenizer_sequence() {
	associated := parse_document('<!doctype html>')
	body := 'literal <b>markup</b>'.bytes()
	params := loading_navigation_params(associated, 'text/plain;charset=utf-8', body)
	mut document := dom.load_document(params, body) or { panic('text load failed') }
	assert document.has_deferred_parser_start()
	document.set_ready_to_run_scripts()
	pre := document.get_elements_by_tag_name('pre').item(0) or { panic('missing pre') }
	assert pre.as_node().text_content()? == 'literal <b>markup</b>'
	assert document.get_elements_by_tag_name('b').length() == 0
}

fn test_document_loader_uses_translated_mime_sniffing() {
	associated := parse_document('<!doctype html>')
	body := [u8(0x89), `P`, `N`, `G`, 0x0d, 0x0a, 0x1a, 0x0a]
	params := loading_navigation_params(associated, 'application/unknown', body)
	mut document := dom.load_document(params, body) or { panic('sniffed image load failed') }
	assert document.content_type == 'image/png'
	assert document.get_elements_by_tag_name('img').length() == 1
}

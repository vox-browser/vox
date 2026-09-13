module html

import dom
import fetch
import mimesniff
import streams

fn incremental_test_parser(content_type string) (&dom.Document, &fetch.Body, &IncrementalDocumentParser) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.update_readiness(.loading)
	document.set_ready_to_run_scripts()
	body := fetch.Body.streaming()
	mime_type := mimesniff.MimeType.parse(content_type) or { panic(err) }
	parser := IncrementalDocumentParser.create(document, body, dom.URL{ value: 'https://example.test/stream' }, mime_type)
	return document, body, parser
}

fn enqueue_incremental_chunk(mut body fetch.Body, bytes []u8) {
	body.append_sniff_bytes(bytes)
	mut stream := body.stream()
	stream.enqueue(streams.bytes_value(bytes)) or { panic(err) }
}

fn finish_incremental_body(mut body fetch.Body) {
	body.set_sniff_bytes_complete()
	mut stream := body.stream()
	stream.close()
}

fn test_incremental_document_parser_exposes_partial_dom_before_eof() {
	document, body, parser := incremental_test_parser('text/html;charset=utf-8')
	mut incremental_parser := parser
	incremental_parser.start()

	first := '<!doctype html><body><div id="first">first</div>${' '.repeat(1500)}'.bytes()
	mut mutable_body := body
	enqueue_incremental_chunk(mut mutable_body, first)
	assert document.get_element_by_id('first')?.as_node().text_content()? == 'first'
	assert document.get_element_by_id('last') == none
	assert document.ready_state() == 'loading'

	enqueue_incremental_chunk(mut mutable_body, '<div id="last">last</div>'.bytes())
	finish_incremental_body(mut mutable_body)
	assert document.get_element_by_id('last')?.as_node().text_content()? == 'last'
	assert document.ready_state() == 'complete'
	assert document.get_source().contains('id="first"')
	assert incremental_parser.error_ == ''
}

fn test_incremental_document_parser_preserves_split_utf8_and_tokenizer_lookahead() {
	document, body, parser := incremental_test_parser('text/html;charset=utf-8')
	mut incremental_parser := parser
	incremental_parser.start()

	prefix := '<!doctype html><body>${' '.repeat(1500)}<p id="utf8">caf'.bytes()
	mut first := prefix.clone()
	first << u8(0xc3)
	mut mutable_body := body
	enqueue_incremental_chunk(mut mutable_body, first)
	mut second := [u8(0xa9)]
	second << '</p><p id="entity">&not'.bytes()
	enqueue_incremental_chunk(mut mutable_body, second)
	enqueue_incremental_chunk(mut mutable_body, 'in;</p><p id="crlf">line1\r'.bytes())
	enqueue_incremental_chunk(mut mutable_body, '\nline2</p>'.bytes())
	finish_incremental_body(mut mutable_body)

	assert document.get_element_by_id('utf8')?.as_node().text_content()? == 'café'
	assert document.get_element_by_id('entity')?.as_node().text_content()? == '∉'
	assert document.get_element_by_id('crlf')?.as_node().text_content()? == 'line1\nline2'
	assert !document.get_source().contains('�')
	assert incremental_parser.error_ == ''
}

fn test_incremental_document_parser_defers_pumping_until_scripts_are_ready() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.update_readiness(.loading)
	body := fetch.Body.from_bytes('<!doctype html><title>Deferred</title>'.bytes(), .bytes)
	mime_type := mimesniff.MimeType.parse('text/html;charset=utf-8') or { panic(err) }
	mut parser := IncrementalDocumentParser.create(document, body, dom.URL{ value: 'https://example.test/deferred' }, mime_type)
	parser.start()
	assert document.has_deferred_parser_start()
	assert document.document_element() == none

	document.set_ready_to_run_scripts()
	assert !document.has_deferred_parser_start()
	assert document.title() == 'Deferred'
	assert document.ready_state() == 'complete'
}

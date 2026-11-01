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
	mime_type := mimesniff.MimeType.parse(content_type) or { panic('invalid MIME fixture') }
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
	assert incremental_parser.body_ == none
	assert incremental_parser.error_ == ''
}

fn test_incremental_document_parser_releases_body_after_read_error() {
	_, _, parser := incremental_test_parser('text/html;charset=utf-8')
	mut incremental_parser := parser
	assert incremental_parser.body_ != none
	incremental_parser.process_body_error('network error')
	assert incremental_parser.body_ == none
	assert incremental_parser.error_ == 'network error'
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
	mime_type := mimesniff.MimeType.parse('text/html;charset=utf-8') or { panic('invalid MIME fixture') }
	mut parser := IncrementalDocumentParser.create(document, body, dom.URL{ value: 'https://example.test/deferred' }, mime_type)
	parser.start()
	assert document.has_deferred_parser_start()
	assert document.document_element() == none

	document.set_ready_to_run_scripts()
	assert !document.has_deferred_parser_start()
	assert document.title() == 'Deferred'
	assert document.ready_state() == 'complete'
}

fn test_incremental_document_parser_holds_encoding_sensitive_bytes_for_late_meta_charset() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.update_readiness(.loading)
	body := fetch.Body.streaming()
	mime_type := mimesniff.MimeType.parse('text/html') or { panic('invalid MIME fixture') }
	mut parser := IncrementalDocumentParser.create(document, body, dom.URL{
		value: 'https://example.test/late-charset'
	}, mime_type)
	parser.start()

	// Keep the declaration beyond the 1024-byte prescan limit, but deliver it as
	// an ASCII prefix that can be decoded safely while script execution is held.
	first := ('<!doctype html><head>${' '.repeat(1100)}<meta charset=windows-1252></head><body><p id="late">${' '.repeat(350)}').bytes()
	mut mutable_body := body
	enqueue_incremental_chunk(mut mutable_body, first)
	mut second := [u8(0x80)]
	second << '</p>'.bytes()
	enqueue_incremental_chunk(mut mutable_body, second)
	finish_incremental_body(mut mutable_body)

	assert document.has_deferred_parser_start()
	html_parser := parser.parser_ or { panic('incremental parser was not initialized') }
	assert html_parser.get_encoding_confidence() == .tentative
	assert parser.input_bytes_.len - parser.decoded_byte_count_ == second.len
	document.set_ready_to_run_scripts()

	assert document.get_encoding()? == 'windows-1252'
	assert document.get_element_by_id('late')?.as_node().text_content()? == '${' '.repeat(350)}€'
	assert document.ready_state() == 'complete'
	assert parser.input_bytes_.len - parser.decoded_byte_count_ == 0
	assert parser.error_ == ''
}

fn test_encoding_independent_prefix_stops_at_non_ascii_and_escape() {
	assert encoding_independent_prefix_length('ascii'.bytes()) == 5
	assert encoding_independent_prefix_length([u8(`a`), `b`, 0x80, `c`]) == 2
	assert encoding_independent_prefix_length([u8(`a`), 0x1b, `c`]) == 1
}

fn incremental_blocked_script_execute(_ ScriptElementType, _ string, _ dom.URL) ! {}

fn test_incremental_document_parser_releases_bytes_after_blocking_script() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.update_readiness(.loading)
	document.set_ready_to_run_scripts()
	mut blocking_style := document.create_element('style') or { panic(err) }
	document.script_blocking_style_sheet_set << blocking_style
	body := fetch.Body.streaming()
	mime_type := mimesniff.MimeType.parse('text/html') or { panic('invalid MIME fixture') }
	mut parser := IncrementalDocumentParser.create(document, body, dom.URL{
		value: 'https://example.test/blocked-late-charset'
	}, mime_type)
	parser.start()

	first := ('<!doctype html><head>${' '.repeat(1450)}<script>blocked()</script><meta charset=windows-1252></head><body><p id="late">').bytes()
	mut mutable_body := body
	mutable_body.append_sniff_bytes(first)
	mut html_parser := parser.parser_ or { panic('incremental parser was not initialized') }
	html_parser.scripting_mode = .normal
	html_parser.set_script_hooks(none, incremental_blocked_script_execute)
	mut stream := mutable_body.stream()
	stream.enqueue(streams.bytes_value(first)) or { panic(err) }
	assert html_parser.paused()

	mut second := [u8(0x80)]
	second << '</p>'.bytes()
	enqueue_incremental_chunk(mut mutable_body, second)
	finish_incremental_body(mut mutable_body)
	assert parser.input_bytes_.len - parser.decoded_byte_count_ == second.len

	document.script_blocking_style_sheet_set.clear()
	document.schedule_html_parser_end_check()
	mut event_loop := main_thread_event_loop()
	for _ in 0 .. 8 {
		if !html_parser.paused() {
			break
		}
		event_loop.process()
	}

	assert !html_parser.paused()
	assert document.get_encoding()? == 'windows-1252'
	assert document.get_element_by_id('late')?.as_node().text_content()? == '€'
	assert document.ready_state() == 'complete'
	assert parser.input_bytes_.len - parser.decoded_byte_count_ == 0
}

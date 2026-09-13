// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/Parser/IncrementalDocumentParser.cpp.
module html

import dom
import encoding
import fetch
import mimesniff

@[heap]
pub struct IncrementalDocumentParser {
mut:
	document_  &dom.Document = unsafe { nil }
	body_      &fetch.Body = unsafe { nil }
	url_       dom.URL
	mime_type_ ?mimesniff.MimeType
	parser_    ?&HTMLParser
	decoder_   ?&encoding.TextDecoder
	source_    string
	error_     string
}

pub fn IncrementalDocumentParser.create(document &dom.Document, body &fetch.Body, url dom.URL, mime_type ?mimesniff.MimeType) &IncrementalDocumentParser {
	return &IncrementalDocumentParser{
		document_: document
		body_: body
		url_: url
		mime_type_: mime_type
	}
}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#read-html
pub fn (mut parser IncrementalDocumentParser) start() {
	mut body := parser.body_
	body.wait_for_sniff_bytes(fn [mut parser] (sniff_bytes []u8) {
		parser.initialize_parser(sniff_bytes)
	})
}

fn (mut parser IncrementalDocumentParser) initialize_parser(sniff_bytes []u8) {
	if parser.parser_ != none {
		return
	}

	transport_encoding := if mime_type := parser.mime_type_ {
		mime_type.parameters()['charset']
	} else {
		none
	}
	encoding_name := parser.document_.get_encoding() or {
		run_html_encoding_sniffing_algorithm(sniff_bytes, transport_encoding)
	}
	decoder := encoding.TextDecoder.construct(encoding_name, encoding.TextDecoderOptions{}) or {
		parser.process_body_error(err.msg())
		return
	}
	standardized_encoding := encoding.get_an_encoding(encoding_name) or {
		parser.process_body_error('Unsupported document encoding: ${encoding_name}')
		return
	}

	parser.decoder_ = decoder
	mut document := parser.document_
	document.set_encoding(standardized_encoding)
	document.set_url(parser.url_)
	parser.parser_ = HTMLParser.create_with_open_input_stream(parser.document_)
	parser.start_incremental_read()
}

fn (mut parser IncrementalDocumentParser) start_incremental_read() {
	mut body := parser.body_
	body.incrementally_read(fn [mut parser] (bytes []u8) {
		parser.process_body_chunk(bytes)
	}, fn [mut parser] () {
		parser.process_end_of_body()
	}, fn [mut parser] (reason string) {
		parser.process_body_error(reason)
	})
}

fn (parser &IncrementalDocumentParser) should_continue() bool {
	concrete_parser := parser.parser_ or { return false }
	if concrete_parser.aborted() {
		return false
	}
	active_parser := parser.document_.active_parser() or { return false }
	return active_parser.target == voidptr(concrete_parser)
}

fn (mut parser IncrementalDocumentParser) append_decoded(decoded string) {
	parser.source_ += decoded
	mut html_parser := parser.parser_ or { return }
	html_parser.tokenizer.append_to_input_stream(decoded)
}

fn (mut parser IncrementalDocumentParser) process_body_chunk(bytes []u8) {
	if !parser.should_continue() {
		return
	}
	mut decoder := parser.decoder_ or { return }
	decoded := decoder.decode(bytes, encoding.TextDecodeOptions{
		stream: true
	}) or {
		parser.process_body_error(err.msg())
		return
	}
	parser.append_decoded(decoded)
	parser.pump()
}

fn (mut parser IncrementalDocumentParser) process_end_of_body() {
	if !parser.should_continue() {
		return
	}
	mut decoder := parser.decoder_ or { return }
	decoded := decoder.decode(none, encoding.TextDecodeOptions{}) or {
		parser.process_body_error(err.msg())
		return
	}
	parser.append_decoded(decoded)

	mut document := parser.document_
	document.set_source(parser.source_)
	mut html_parser := parser.parser_ or { return }
	html_parser.tokenizer.close_input_stream()
	parser.pump()
}

fn (mut parser IncrementalDocumentParser) process_body_error(reason string) {
	parser.error_ = reason
	HTMLParser.the_end(parser.document_, parser.parser_)
}

fn (mut parser IncrementalDocumentParser) register_deferred_start() {
	if parser.document_.has_deferred_parser_start() {
		return
	}
	mut document := parser.document_
	document.set_deferred_parser_start(fn [mut parser] () {
		parser.pump()
	})
}

fn (mut parser IncrementalDocumentParser) pump() {
	if !parser.should_continue() {
		return
	}
	if !parser.document_.document_ready_to_run_scripts() {
		parser.register_deferred_start()
		return
	}

	mut html_parser := parser.parser_ or { return }
	if html_parser.stopped() {
		return
	}
	if html_parser.tokenizer.is_input_stream_closed() {
		html_parser.run_until_completion()
		return
	}
	if html_parser.paused() {
		return
	}
	html_parser.run()
}

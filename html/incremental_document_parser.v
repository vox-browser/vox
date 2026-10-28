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
	document_              &dom.Document = unsafe { nil }
	body_                  ?&fetch.Body
	url_                   dom.URL
	mime_type_             ?mimesniff.MimeType
	parser_                ?&HTMLParser
	decoder_               ?&encoding.TextDecoder
	input_bytes_           []u8
	decoded_byte_count_    int
	source_                string
	error_                 string
	body_is_exhausted_     bool
	processed_implied_eof_ bool
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
	mut body := parser.body_ or { return }
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
	result := if document_encoding := parser.document_.get_encoding() {
		EncodingSniffingResult{
			encoding: document_encoding
			confidence: .certain
		}
	} else {
		run_html_encoding_sniffing_algorithm_with_confidence(sniff_bytes, transport_encoding)
	}
	standardized_encoding := encoding.get_an_encoding(result.encoding) or {
		parser.process_body_error('Unsupported document encoding: ${result.encoding}')
		return
	}
	decoder := encoding.TextDecoder.construct(standardized_encoding, encoding.TextDecoderOptions{}) or {
		parser.process_body_error(err.msg())
		return
	}

	parser.decoder_ = decoder
	mut document := parser.document_
	document.set_encoding(standardized_encoding)
	document.set_url(parser.url_)
	mut html_parser := HTMLParser.create_with_open_input_stream_and_confidence(parser.document_, result.confidence)
	html_parser.set_change_encoding_callback(fn [mut parser] (new_encoding string) bool {
		return parser.change_encoding(new_encoding)
	})
	html_parser.set_parsing_complete_callback(fn [mut parser] () {
		parser.release_encoding_change_buffers()
	})
	html_parser.set_ready_for_more_input_callback(fn [mut parser] () {
		parser.feed_parser()
	})
	parser.parser_ = html_parser
	parser.start_incremental_read()
}

fn (mut parser IncrementalDocumentParser) start_incremental_read() {
	mut body := parser.body_ or { return }
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
		parser.discard_input_bytes()
		return
	}
	parser.input_bytes_ << bytes
	parser.feed_parser()
}

fn encoding_independent_prefix_length(bytes []u8) int {
	mut length := 0
	for length < bytes.len {
		byte := bytes[length]
		if byte > 0x7f || byte == 0x1b {
			break
		}
		length++
	}
	return length
}

fn (parser &IncrementalDocumentParser) tokenizer_will_consume_input_immediately() bool {
	html_parser := parser.parser_ or { return false }
	return parser.document_.document_ready_to_run_scripts() && !html_parser.paused()
}

fn (mut parser IncrementalDocumentParser) feed_parser() {
	for parser.decoded_byte_count_ < parser.input_bytes_.len {
		if !parser.should_continue() {
			parser.discard_input_bytes()
			return
		}
		mut length_to_decode := parser.input_bytes_.len - parser.decoded_byte_count_
		html_parser := parser.parser_ or { return }
		if html_parser.get_encoding_confidence() == .tentative {
			current_encoding := parser.document_.get_encoding() or { 'UTF-8' }
			standardized := encoding.get_an_encoding(current_encoding) or { current_encoding }
			if standardized.to_lower() !in ['utf-16be', 'utf-16le'] {
				undecoded := parser.input_bytes_[parser.decoded_byte_count_..].clone()
				prefix_length := encoding_independent_prefix_length(undecoded)
				if prefix_length == 0 && !parser.tokenizer_will_consume_input_immediately() {
					if !parser.document_.document_ready_to_run_scripts() {
						parser.register_deferred_start()
					}
					return
				}
				if prefix_length > 0 {
					length_to_decode = prefix_length
				}
			}
		}
		parser.decode_and_process(length_to_decode)
	}

	html_parser := parser.parser_ or { return }
	if !parser.should_continue() || html_parser.get_encoding_confidence() != .tentative {
		parser.release_encoding_change_buffers()
	}
	if parser.body_is_exhausted_ {
		parser.finish_body()
	}
}

fn (mut parser IncrementalDocumentParser) process_end_of_body() {
	// The response stream can belong to the document that initiated this
	// navigation. Release it as soon as it is exhausted instead of keeping the
	// previous document alive until the new document's load event.
	parser.body_ = none
	parser.body_is_exhausted_ = true
	if !parser.should_continue() {
		parser.discard_input_bytes()
		return
	}
	parser.feed_parser()
}

fn (mut parser IncrementalDocumentParser) finish_body() {
	if parser.processed_implied_eof_ || !parser.should_continue() {
		return
	}
	if !parser.body_is_exhausted_ || parser.decoded_byte_count_ != parser.input_bytes_.len {
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
	parser.processed_implied_eof_ = true
	mut html_parser := parser.parser_ or { return }
	html_parser.tokenizer.close_input_stream()
	parser.pump()
	if !parser.should_continue() {
		parser.release_encoding_change_buffers()
	}
}

fn (mut parser IncrementalDocumentParser) change_encoding(new_encoding string) bool {
	new_decoder := encoding.TextDecoder.construct(new_encoding, encoding.TextDecoderOptions{}) or {
		parser.release_encoding_change_buffers()
		return false
	}
	decoded_bytes := parser.input_bytes_[..parser.decoded_byte_count_].clone()
	mut redecoded_source := new_decoder.decode(decoded_bytes, encoding.TextDecodeOptions{
		stream: true
	}) or {
		parser.release_encoding_change_buffers()
		return false
	}
	if parser.processed_implied_eof_ {
		finished := new_decoder.decode(none, encoding.TextDecodeOptions{}) or {
			parser.release_encoding_change_buffers()
			return false
		}
		redecoded_source += finished
	}
	current_source := if parser.processed_implied_eof_ {
		parser.document_.get_source()
	} else {
		parser.source_
	}
	if !redecoded_source.starts_with(current_source)
		|| (parser.processed_implied_eof_ && redecoded_source.len != current_source.len) {
		parser.release_encoding_change_buffers()
		return false
	}
	if redecoded_source.len > current_source.len {
		if parser.processed_implied_eof_ {
			parser.release_encoding_change_buffers()
			return false
		}
		parser.append_decoded(redecoded_source[current_source.len..])
	}
	parser.decoder_ = new_decoder
	parser.release_encoding_change_buffers()
	return true
}

fn (mut parser IncrementalDocumentParser) decode_and_process(length int) {
	if length <= 0 || parser.decoded_byte_count_ + length > parser.input_bytes_.len {
		return
	}
	bytes := parser.input_bytes_[parser.decoded_byte_count_..parser.decoded_byte_count_ + length].clone()
	mut decoder := parser.decoder_ or { return }
	decoded := decoder.decode(bytes, encoding.TextDecodeOptions{
		stream: true
	}) or {
		parser.process_body_error(err.msg())
		return
	}
	parser.decoded_byte_count_ += length
	parser.append_decoded(decoded)
	parser.pump()
}

fn (mut parser IncrementalDocumentParser) release_encoding_change_buffers() {
	if parser.decoded_byte_count_ == 0 {
		return
	}
	parser.input_bytes_ = parser.input_bytes_[parser.decoded_byte_count_..].clone()
	parser.decoded_byte_count_ = 0
}

fn (mut parser IncrementalDocumentParser) discard_input_bytes() {
	parser.input_bytes_.clear()
	parser.decoded_byte_count_ = 0
}

fn (mut parser IncrementalDocumentParser) process_body_error(reason string) {
	parser.body_ = none
	parser.error_ = reason
	if parser.should_continue() && parser.decoded_byte_count_ < parser.input_bytes_.len {
		parser.decode_and_process(parser.input_bytes_.len - parser.decoded_byte_count_)
	}
	parser.discard_input_bytes()
	HTMLParser.the_end(parser.document_, parser.parser_)
}

fn (mut parser IncrementalDocumentParser) register_deferred_start() {
	if parser.document_.has_deferred_parser_start() {
		return
	}
	mut document := parser.document_
	document.set_deferred_parser_start(fn [mut parser] () {
		parser.pump()
		parser.feed_parser()
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

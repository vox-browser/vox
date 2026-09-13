// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Body.cpp, BodyInit.cpp, and Infrastructure/HTTP/Bodies.cpp.
module fetch

import encoding
import mimesniff
import streams
import x.json2

pub type SniffBytesCallback = fn ([]u8)

pub type BodyChunkCallback = fn ([]u8)

pub type BodyEndCallback = fn ()

pub type BodyErrorCallback = fn (string)

pub enum BodySourceKind {
	empty
	bytes
	blob
	form_data
	url_search_params
	string_
	readable_stream
}

@[heap]
pub struct Body {
pub mut:
	source_kind BodySourceKind
	length      ?u64
mut:
	stream_               &streams.ReadableStream = unsafe { nil }
	source_bytes_         []u8
	sniff_bytes_          []u8
	sniff_bytes_complete_ bool
	sniff_callback_       ?SniffBytesCallback
}

pub fn Body.from_bytes(bytes []u8, source_kind BodySourceKind) &Body {
	mut stream := streams.ReadableStream.construct_impl(streams.UnderlyingSource{
		type_: .bytes
	}, streams.QueuingStrategy{}) or { panic(err) }
	if bytes.len > 0 {
		stream.enqueue(streams.bytes_value(bytes)) or { panic(err) }
	}
	stream.close()
	return &Body{
		source_kind: source_kind
		length: u64(bytes.len)
		stream_: stream
		source_bytes_: bytes.clone()
	}
}

pub fn Body.streaming() &Body {
	stream := streams.ReadableStream.construct_impl(streams.UnderlyingSource{
		type_: .bytes
	}, streams.QueuingStrategy{}) or { panic(err) }
	return &Body{
		source_kind: .readable_stream
		stream_: stream
	}
}

pub fn (body &Body) bytes() []u8 {
	return body.source_bytes_.clone()
}

pub fn (mut body Body) set_source(source []u8, length ?u64) {
	body.source_kind = .bytes
	body.source_bytes_ = source.clone()
	body.length = length
}

pub fn (body &Body) stream_locked() bool {
	return body.stream_.locked()
}

pub fn (body &Body) disturbed() bool {
	return body.stream_.disturbed()
}

pub fn (body &Body) errored() bool {
	return body.stream_.state() == .errored
}

pub fn (body &Body) error_reason() string {
	return body.stream_.stored_error()
}

pub fn (mut body Body) error_stream(reason string) {
	mut stream := body.stream_
	stream.error(reason)
}

pub fn (mut body Body) append_sniff_bytes(bytes []u8) {
	if body.sniff_bytes_complete_ || body.sniff_bytes_.len >= 1445 {
		return
	}
	remaining := 1445 - body.sniff_bytes_.len
	body.sniff_bytes_ << bytes[..if bytes.len < remaining { bytes.len } else { remaining }]
	if body.sniff_bytes_.len >= 1445 {
		body.set_sniff_bytes_complete()
	}
}

pub fn (mut body Body) set_sniff_bytes_complete() {
	if body.sniff_bytes_complete_ {
		return
	}
	body.sniff_bytes_complete_ = true
	if callback := body.sniff_callback_ {
		callback(body.sniff_bytes_.clone())
		body.sniff_callback_ = none
	}
}

pub fn (body &Body) sniff_bytes_if_available() ?[]u8 {
	if body.source_kind != .readable_stream {
		limit := if body.source_bytes_.len < 1445 {
			body.source_bytes_.len
		} else {
			1445
		}
		return body.source_bytes_[..limit].clone()
	}
	if body.sniff_bytes_complete_ {
		return body.sniff_bytes_.clone()
	}
	return none
}

pub fn (mut body Body) wait_for_sniff_bytes(callback SniffBytesCallback) {
	if bytes := body.sniff_bytes_if_available() {
		callback(bytes)
		return
	}
	body.sniff_callback_ = callback
}

pub fn (mut body Body) clone() &Body {
	mut stream := body.stream_
	pair := stream.tee() or { panic(err) }
	body.stream_ = pair.first
	return &Body{
		source_kind: body.source_kind
		length: body.length
		stream_: pair.second
		source_bytes_: body.source_bytes_.clone()
		sniff_bytes_: body.sniff_bytes_.clone()
		sniff_bytes_complete_: body.sniff_bytes_complete_
	}
}

fn clone_body(body ?&Body) ?&Body {
	mut source := body or { return none }
	return source.clone()
}

pub fn (mut body Body) fully_read() ![]u8 {
	mut stream := body.stream_
	mut reader := stream.get_default_reader()!
	return reader.read_all_bytes()
}

pub fn (mut body Body) incrementally_read(process_chunk BodyChunkCallback, process_end BodyEndCallback, process_error BodyErrorCallback) &streams.ReadableStreamDefaultReader {
	mut stream := body.stream_
	reader := stream.get_default_reader() or { panic(err) }
	body.incrementally_read_loop(reader, process_chunk, process_end, process_error)
	return reader
}

pub fn cancel_incremental_read(mut reader streams.ReadableStreamDefaultReader) {
	reader.cancel(streams.undefined_value())
}

pub fn (mut body Body) incrementally_read_loop(reader &streams.ReadableStreamDefaultReader, process_chunk BodyChunkCallback, process_end BodyEndCallback, process_error BodyErrorCallback) {
	mut mutable_reader := unsafe { &streams.ReadableStreamDefaultReader(reader) }
	read := mutable_reader.read()
	if read.state() == .pending {
		mut mutable_read := unsafe { &streams.ReadPromise(read) }
		mutable_read.upon_settlement(fn [mut body, reader, process_chunk, process_end, process_error] (result streams.ReadResult) {
			body.process_incremental_read_result(reader, result, process_chunk, process_end, process_error)
		}, fn [process_error] (reason string) {
			process_error(reason)
		})
		return
	}
	if read.state() == .rejected {
		process_error(read.reason())
		return
	}
	body.process_incremental_read_result(reader, read.result(), process_chunk, process_end, process_error)
}

fn (mut body Body) process_incremental_read_result(reader &streams.ReadableStreamDefaultReader, result streams.ReadResult, process_chunk BodyChunkCallback, process_end BodyEndCallback, process_error BodyErrorCallback) {
	if result.done {
		process_end()
		return
	}
	if result.value.kind != .bytes {
		process_error('TypeError: Body stream produced a non-byte chunk')
		return
	}
	process_chunk(result.value.bytes_.clone())
	body.incrementally_read_loop(reader, process_chunk, process_end, process_error)
}

pub struct BodyWithType {
pub:
	body  &Body
	type_ ?string
}

pub struct BodyInit {
pub:
	kind             BodySourceKind
	bytes            []u8
	text             string
	type_            string
	stream_locked    bool
	stream_disturbed bool
	stream           ?&streams.ReadableStream
}

pub fn extract_body(object BodyInit, keepalive bool) !BodyWithType {
	if object.kind == .readable_stream {
		if keepalive {
			return error('TypeError: A ReadableStream body cannot be used with keepalive')
		}
		if object.stream_locked || object.stream_disturbed {
			return error('TypeError: ReadableStream body is disturbed or locked')
		}
		if supplied_stream := object.stream {
			return BodyWithType{
				body: &Body{
					source_kind: .readable_stream
					stream_: supplied_stream
				}
			}
		}
		return BodyWithType{
			body: Body.streaming()
		}
	}
	mut bytes := object.bytes.clone()
	mut type_ := ?string(none)
	match object.kind {
		.string_ {
			bytes = object.text.bytes()
			type_ = 'text/plain;charset=UTF-8'
		}
		.url_search_params {
			bytes = object.text.bytes()
			type_ = 'application/x-www-form-urlencoded;charset=UTF-8'
		}
		.blob {
			if object.type_ != '' {
				type_ = object.type_
			}
		}
		.form_data {
			type_ = if object.type_ != '' { object.type_ } else { 'multipart/form-data' }
		}
		else {}
	}
	return BodyWithType{
		body: Body.from_bytes(bytes, object.kind)
		type_: type_
	}
}

pub fn safely_extract_body(object BodyInit) BodyWithType {
	return extract_body(object, false) or { panic(err) }
}

pub struct FormDataEntry {
pub:
	name         string
	value        string
	filename     ?string
	content_type ?string
}

struct MultipartLexer {
	input string
mut:
	position int
}

fn (lexer &MultipartLexer) next_is(value string) bool {
	return lexer.position + value.len <= lexer.input.len && lexer.input[lexer.position..lexer.position + value.len] == value
}

fn (mut lexer MultipartLexer) consume_specific(value string) bool {
	if !lexer.next_is(value) {
		return false
	}
	lexer.position += value.len
	return true
}

fn (mut lexer MultipartLexer) consume_until_any(delimiters string) string {
	start := lexer.position
	for lexer.position < lexer.input.len && lexer.input[lexer.position] !in delimiters.bytes() {
		lexer.position++
	}
	return lexer.input[start..lexer.position]
}

fn (mut lexer MultipartLexer) consume_until(value string) string {
	start := lexer.position
	relative_end := lexer.input[start..].index(value) or {
		lexer.position = lexer.input.len
		return lexer.input[start..]
	}
	lexer.position = start + relative_end
	return lexer.input[start..lexer.position]
}

fn trim_http_tab_or_space(value string) string {
	return value.trim(' \t')
}

fn trim_http_tab_or_space_right(value string) string {
	return value.trim_right(' \t')
}

fn parse_multipart_form_data_name_from_lexer(mut lexer MultipartLexer) !string {
	name := lexer.consume_until_any('\n\r"')
	if !lexer.consume_specific('"') {
		return error('Multipart parsing failed: expected quote at position ${lexer.position}')
	}
	return name.replace('%0A', '\n').replace('%0D', '\r').replace('%22', '"')
}

fn parse_multipart_form_data_header_from_lexer(mut lexer MultipartLexer) !MultipartFormDataHeader {
	mut name := ?string(none)
	mut filename := ?string(none)
	mut content_type := ?string(none)
	for {
		if lexer.next_is('\r\n') {
			parsed_name := name or {
				return error('Multipart parsing failed: missing name parameter in Content-Disposition header')
			}
			return MultipartFormDataHeader{
				name: parsed_name
				filename: filename
				content_type: content_type
			}
		}

		header_name := trim_http_tab_or_space(lexer.consume_until_any('\n\r:'))
		if header_name == '' || !header_name.bytes().all(http_header_name_byte) {
			return error('Multipart parsing failed: invalid header name ${header_name}')
		}
		if !lexer.consume_specific(':') {
			return error('Multipart parsing failed: expected colon at position ${lexer.position}')
		}
		for lexer.position < lexer.input.len && lexer.input[lexer.position] in [` `, `\t`] {
			lexer.position++
		}

		if header_name.to_lower() == 'content-disposition' {
			name = none
			filename = none
			if !lexer.consume_specific('form-data; name="') {
				return error('Multipart parsing failed: expected form-data name at position ${lexer.position}')
			}
			name = parse_multipart_form_data_name_from_lexer(mut lexer)!
			if lexer.consume_specific('; filename="') {
				filename = parse_multipart_form_data_name_from_lexer(mut lexer)!
			}
		} else if header_name.to_lower() == 'content-type' {
			content_type = trim_http_tab_or_space_right(lexer.consume_until_any('\n\r'))
		} else {
			lexer.consume_until_any('\n\r')
		}

		if !lexer.consume_specific('\r\n') {
			return error('Multipart parsing failed: expected CRLF at position ${lexer.position}')
		}
	}
	return error('Multipart parsing failed')
}

// Direct translation of Body.cpp's position-driven multipart parser.
pub fn parse_multipart_form_data(input string, mime_type mimesniff.MimeType) ![]FormDataEntry {
	parameters := mime_type.parameters()
	boundary := parameters['boundary'] or {
		return error('Multipart parsing failed: missing boundary')
	}
	boundary_with_dashes := '--${boundary}'
	mut lexer := MultipartLexer{
		input: input
	}
	mut entries := []FormDataEntry{}
	for {
		if !lexer.consume_specific(boundary_with_dashes) {
			return error('Multipart parsing failed: expected boundary at position ${lexer.position}')
		}
		if lexer.next_is('--') {
			return entries
		}
		if !lexer.consume_specific('\r\n') {
			return error('Multipart parsing failed: expected CRLF at position ${lexer.position}')
		}

		header := parse_multipart_form_data_header_from_lexer(mut lexer)!
		lexer.position += 2
		mut value := lexer.consume_until(boundary_with_dashes)
		if lexer.next_is(boundary_with_dashes) && value.len >= 2 {
			value = value[..value.len - 2]
			lexer.position -= 2
		}
		if !lexer.consume_specific('\r\n') {
			return error('Multipart parsing failed: expected CRLF before boundary at position ${lexer.position}')
		}

		mut entry_content_type := header.content_type
		if header.filename != none {
			mut file_type := entry_content_type or { 'text/plain' }
			if !file_type.is_ascii() {
				file_type = ''
			}
			entry_content_type = file_type
		}
		entries << FormDataEntry{
			name: header.name or { return error('Multipart parsing failed: missing name') }
			value: value
			filename: header.filename
			content_type: entry_content_type
		}
	}
	return entries
}

pub struct BodyMixin {
pub:
	body      ?&Body
	mime_type ?mimesniff.MimeType
}

pub fn (mixin &BodyMixin) is_unusable() bool {
	body := mixin.body or { return false }
	return body.stream_locked() || body.disturbed()
}

pub fn (mixin &BodyMixin) body_used() bool {
	body := mixin.body or { return false }
	return body.disturbed()
}

pub fn (mixin &BodyMixin) bytes() ![]u8 {
	mut body := mixin.body or { return []u8{} }
	return body.fully_read()
}

pub fn (mixin &BodyMixin) array_buffer() ![]u8 {
	return mixin.bytes()
}

pub fn (mixin &BodyMixin) text() !string {
	bytes := mixin.bytes()!
	decoder := encoding.TextDecoder.create()
	return decoder.decode(bytes, encoding.TextDecodeOptions{})!
}

pub fn (mixin &BodyMixin) json() !string {
	text := mixin.text()!
	json2.decode[json2.Any](text) or { return error('SyntaxError: Invalid JSON body') }
	return text
}

fn decode_url_encoded_component(input string) string {
	return percent_decode(input.replace('+', ' ')).bytestr()
}

pub fn (mixin &BodyMixin) form_data() ![]FormDataEntry {
	mime := mixin.mime_type or { return error('TypeError: Body MIME type is unavailable') }
	if mime.essence() == 'multipart/form-data' {
		return parse_multipart_form_data(mixin.text()!, mime)
	}
	if mime.essence() == 'application/x-www-form-urlencoded' {
		mut entries := []FormDataEntry{}
		text := mixin.text()!
		if text == '' {
			return entries
		}
		for pair in text.split('&') {
			if pair == '' {
				continue
			}
			parts := pair.split_nth('=', 2)
			entries << FormDataEntry{
				name: decode_url_encoded_component(parts[0])
				value: if parts.len > 1 { decode_url_encoded_component(parts[1]) } else { '' }
			}
		}
		return entries
	}
	return error('TypeError: Unsupported form data MIME type')
}

// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Remaining Body/BodyMixin entry points from the Fetch implementation.
module fetch

import streams

pub fn Body.create(stream &streams.ReadableStream, source_kind BodySourceKind, length ?u64) &Body {
	return &Body{
		source_kind: source_kind
		length: length
		stream_: stream
	}
}

pub fn (body &Body) stream() &streams.ReadableStream {
	return body.stream_
}

pub fn (mut body Body) set_stream(stream &streams.ReadableStream) {
	body.stream_ = stream
}

pub fn (body &Body) body_source() BodySourceKind {
	return body.source_kind
}

pub fn (body &Body) body_length() ?u64 {
	return body.length
}

pub fn to_source_type_internal(source_kind BodySourceKind) BodySourceKind {
	return source_kind
}

pub fn byte_sequence_as_body(bytes []u8) &Body {
	return Body.from_bytes(bytes, .bytes)
}

pub struct FetchBlob {
pub:
	bytes []u8
	type_ string
}

pub fn (mixin &BodyMixin) body_stream() ?&streams.ReadableStream {
	body := mixin.body or { return none }
	return body.stream()
}

pub fn (mixin &BodyMixin) blob() !FetchBlob {
	bytes := mixin.bytes()!
	return FetchBlob{
		bytes: bytes
		type_: if mime := mixin.mime_type { mime.serialized() } else { '' }
	}
}

pub type ConvertBodyBytes = fn ([]u8) !string

pub fn consume_body(mixin &BodyMixin, convert ConvertBodyBytes) !string {
	if mixin.is_unusable() {
		return error('TypeError: Body is unusable')
	}
	bytes := mixin.bytes()!
	return convert(bytes)
}

pub fn parse_multipart_form_data_name(input string) !string {
	mut lexer := MultipartLexer{
		input: '${input}"'
	}
	return parse_multipart_form_data_name_from_lexer(mut lexer)
}

pub struct MultipartFormDataHeader {
pub:
	name         ?string
	filename     ?string
	content_type ?string
}

pub fn parse_multipart_form_data_header(input string) !MultipartFormDataHeader {
	mut terminated_input := input
	if !terminated_input.ends_with('\r\n\r\n') {
		terminated_input += '\r\n'
	}
	mut lexer := MultipartLexer{
		input: terminated_input
	}
	return parse_multipart_form_data_header_from_lexer(mut lexer)
}

fn http_header_name_byte(value u8) bool {
	return value >= 0x21 && value <= 0x7e && value !in [`(`, `)`, `<`, `>`, `@`, `,`, `;`, `:`,
		`\\`, `"`, `/`, `[`, `]`, `?`, `=`, `{`, `}`]
}

// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Remaining Body/BodyMixin entry points from the Fetch implementation. A Body
// also represents its translated readable-stream state, so stream() returns
// that state object rather than introducing a second incomplete stream model.
module fetch

pub fn Body.create(stream &Body, source_kind BodySourceKind, length ?u64) &Body {
	return &Body{
		source_kind: source_kind
		length: length
		bytes_: stream.bytes_.clone()
		stream_locked_: stream.stream_locked_
		disturbed_: stream.disturbed_
		errored_: stream.errored_
		error_reason_: stream.error_reason_
		sniff_bytes_: stream.sniff_bytes_.clone()
		sniff_bytes_complete_: stream.sniff_bytes_complete_
	}
}

pub fn (body &Body) stream() &Body {
	return body
}

pub fn (mut body Body) set_stream(stream &Body) {
	body.bytes_ = stream.bytes_.clone()
	body.stream_locked_ = stream.stream_locked_
	body.disturbed_ = stream.disturbed_
	body.errored_ = stream.errored_
	body.error_reason_ = stream.error_reason_
}

pub fn (body &Body) body_source() BodySourceKind {
	return body.source_kind
}

pub fn (body &Body) body_length() ?u64 {
	return body.length
}

pub fn (mut body Body) incrementally_read_loop(chunk_size int, process_chunk BodyChunkCallback, process_end BodyEndCallback, process_error BodyErrorCallback) {
	body.incrementally_read(chunk_size, process_chunk, process_end, process_error)
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

pub fn (mixin &BodyMixin) body_stream() ?&Body {
	return mixin.body
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
	if input.contains('\n') || input.contains('\r') || input.contains('"') {
		return error('Multipart parsing failed: invalid quoted name')
	}
	return input.replace('%0A', '\n').replace('%0D', '\r').replace('%22', '"')
}

pub struct MultipartFormDataHeader {
pub:
	name         ?string
	filename     ?string
	content_type ?string
}

pub fn parse_multipart_form_data_header(input string) !MultipartFormDataHeader {
	mut name := ?string(none)
	mut filename := ?string(none)
	mut content_type := ?string(none)
	for line in input.split('\r\n') {
		if line == '' {
			continue
		}
		colon := line.index_u8(`:`)
		if colon < 0 {
			return error('Multipart parsing failed: missing header colon')
		}
		header_name := line[..colon].trim_space()
		if !header_name.bytes().all(http_header_name_byte) {
			return error('Multipart parsing failed: invalid header name')
		}
		header_value := line[colon + 1..].trim_left(' \t')
		if header_name.to_lower() == 'content-disposition' {
			if !header_value.starts_with('form-data; name="') {
				return error('Multipart parsing failed: invalid content disposition')
			}
			value_start := 'form-data; name="'.len
			value_end_relative := header_value[value_start..].index_u8(`"`)
			if value_end_relative < 0 {
				return error('Multipart parsing failed: unterminated name')
			}
			value_end := value_start + value_end_relative
			name = parse_multipart_form_data_name(header_value[value_start..value_end])!
			remainder := header_value[value_end + 1..]
			if remainder.starts_with('; filename="') {
				filename_start := '; filename="'.len
				filename_end_relative := remainder[filename_start..].index_u8(`"`)
				if filename_end_relative < 0 {
					return error('Multipart parsing failed: unterminated filename')
				}
				filename = parse_multipart_form_data_name(remainder[filename_start..filename_start + filename_end_relative])!
			}
		} else if header_name.to_lower() == 'content-type' {
			content_type = header_value.trim_right(' \t')
		}
	}
	parsed_name := name or { return error('Multipart parsing failed: missing name') }
	return MultipartFormDataHeader{
		name: parsed_name
		filename: filename
		content_type: content_type
	}
}

fn http_header_name_byte(value u8) bool {
	return value >= 0x21 && value <= 0x7e && value !in [`(`, `)`, `<`, `>`, `@`, `,`, `;`, `:`,
		`\\`, `"`, `/`, `[`, `]`, `?`, `=`, `{`, `}`]
}

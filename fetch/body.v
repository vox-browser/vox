// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Body.cpp, BodyInit.cpp, and Infrastructure/HTTP/Bodies.cpp.
module fetch

import encoding
import mimesniff
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
pub:
	source_kind BodySourceKind
	length      ?u64
mut:
	bytes_                []u8
	stream_locked_        bool
	disturbed_            bool
	sniff_bytes_          []u8
	sniff_bytes_complete_ bool
	sniff_callback_       ?SniffBytesCallback
}

pub fn Body.from_bytes(bytes []u8, source_kind BodySourceKind) &Body {
	return &Body{
		source_kind:           source_kind
		length:                u64(bytes.len)
		bytes_:                bytes.clone()
		sniff_bytes_:          bytes[..if bytes.len < 1445 { bytes.len } else { 1445 }].clone()
		sniff_bytes_complete_: true
	}
}

pub fn Body.streaming() &Body {
	return &Body{
		source_kind: .readable_stream
	}
}

pub fn (body &Body) bytes() []u8 {
	return body.bytes_.clone()
}

pub fn (body &Body) stream_locked() bool {
	return body.stream_locked_
}

pub fn (body &Body) disturbed() bool {
	return body.disturbed_
}

pub fn (mut body Body) set_stream_locked(value bool) {
	body.stream_locked_ = value
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

pub fn (body &Body) clone() &Body {
	return &Body{
		source_kind:           body.source_kind
		length:                body.length
		bytes_:                body.bytes_.clone()
		sniff_bytes_:          body.sniff_bytes_.clone()
		sniff_bytes_complete_: body.sniff_bytes_complete_
	}
}

pub fn (mut body Body) fully_read() ![]u8 {
	if body.stream_locked_ || body.disturbed_ {
		return error('TypeError: Body is unusable')
	}
	body.disturbed_ = true
	return body.bytes_.clone()
}

pub fn (mut body Body) incrementally_read(chunk_size int, process_chunk BodyChunkCallback, process_end BodyEndCallback, process_error BodyErrorCallback) {
	if body.stream_locked_ || body.disturbed_ {
		process_error('TypeError: Body is unusable')
		return
	}
	body.disturbed_ = true
	if chunk_size <= 0 {
		process_error('TypeError: Invalid chunk size')
		return
	}
	mut offset := 0
	for offset < body.bytes_.len {
		end := if offset + chunk_size < body.bytes_.len {
			offset + chunk_size
		} else {
			body.bytes_.len
		}
		process_chunk(body.bytes_[offset..end].clone())
		offset = end
	}
	process_end()
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
}

pub fn extract_body(object BodyInit, keepalive bool) !BodyWithType {
	if object.kind == .readable_stream {
		if keepalive {
			return error('TypeError: A ReadableStream body cannot be used with keepalive')
		}
		if object.stream_locked || object.stream_disturbed {
			return error('TypeError: ReadableStream body is disturbed or locked')
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
		body:  Body.from_bytes(bytes, object.kind)
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

fn unquote_header_parameter(value string) string {
	trimmed := value.trim_space()
	if trimmed.len >= 2 && trimmed[0] == `"` && trimmed[trimmed.len - 1] == `"` {
		return trimmed[1..trimmed.len - 1].replace('\\"', '"').replace('\\\\', '\\')
	}
	return trimmed
}

// Multipart parser used by Body.formData(). It preserves entry order and the
// upstream name/filename/content-type projection.
pub fn parse_multipart_form_data(input string, mime_type mimesniff.MimeType) ![]FormDataEntry {
	parameters := mime_type.parameters()
	boundary := parameters['boundary'] or {
		return error('Multipart parsing failed: missing boundary')
	}
	if boundary == '' {
		return error('Multipart parsing failed: empty boundary')
	}
	marker := '--${boundary}'
	mut entries := []FormDataEntry{}
	for raw_part in input.split(marker)[1..] {
		if raw_part.starts_with('--') {
			break
		}
		mut part := raw_part
		if part.starts_with('\r\n') { part = part[2..] }
		separator := part.index('\r\n\r\n') or {
			return error('Multipart parsing failed: malformed headers')
		}
		headers_text := part[..separator]
		mut value := part[separator + 4..]
		if value.ends_with('\r\n') { value = value[..value.len - 2] }
		mut name := ?string(none)
		mut filename := ?string(none)
		mut content_type := ?string(none)
		for line in headers_text.split('\r\n') {
			colon := line.index_u8(`:`)
			if colon < 0 { continue
			 }
			header_name := ascii_lowercase(line[..colon].trim_space())
			header_value := line[colon + 1..].trim_space()
			if header_name == 'content-disposition' {
				pieces := header_value.split(';')
				if ascii_lowercase(pieces[0].trim_space()) != 'form-data' { continue
				 }
				for parameter in pieces[1..] {
					equals := parameter.index_u8(`=`)
					if equals < 0 { continue
					 }
					parameter_name := ascii_lowercase(parameter[..equals].trim_space())
					parameter_value := unquote_header_parameter(parameter[equals + 1..])
					if parameter_name == 'name' { name = parameter_value }
					if parameter_name == 'filename' { filename = parameter_value }
				}
			} else if header_name == 'content-type' {
				content_type = header_value
			}
		}
		entry_name := name or { return error('Multipart parsing failed: missing name') }
		entries << FormDataEntry{
			name:         entry_name
			value:        value
			filename:     filename
			content_type: content_type
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
				name:  decode_url_encoded_component(parts[0])
				value: if parts.len > 1 { decode_url_encoded_component(parts[1]) } else { '' }
			}
		}
		return entries
	}
	return error('TypeError: Unsupported form data MIME type')
}

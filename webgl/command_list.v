// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebGL/WebGLCommandList.{h,cpp}. The generated C++ command
// structs are represented as opaque, trivially-copyable payload bytes in V.
module webgl

import encoding.binary

pub const webgl_command_type_count = u16(183)
pub const webgl_sync_call_type_count = u16(45)
pub const webgl_command_alignment = 16

pub type WebGLCommandType = u16

pub type WebGLSyncCallType = u16

const webgl_command_header_size = 8
const webgl_sync_call_header_size = 8

fn align_command_value(value int) !int {
	if value < 0 || value > max_int - (webgl_command_alignment - 1) {
		return error('WebGL command size overflow')
	}
	return (value + webgl_command_alignment - 1) / webgl_command_alignment * webgl_command_alignment
}

fn payload_layout_size(payload []u8, inline_data []u8, more_inline_data []u8) !int {
	mut size := payload.len
	for blob in [inline_data, more_inline_data] {
		if blob.len == 0 {
			continue
		}
		size = align_command_value(size)!
		if blob.len > max_int - size {
			return error('WebGL command payload size overflow')
		}
		size += blob.len
	}
	return size
}

fn write_payload(mut destination []u8, payload []u8, inline_data []u8, more_inline_data []u8) ! {
	required_size := payload_layout_size(payload, inline_data, more_inline_data)!
	if destination.len < required_size {
		return error('WebGL command destination is too small')
	}
	for index in 0 .. destination.len {
		destination[index] = 0
	}
	copy(mut destination[..payload.len], payload)
	mut cursor := payload.len
	for blob in [inline_data, more_inline_data] {
		if blob.len == 0 {
			continue
		}
		offset := align_command_value(cursor)!
		copy(mut destination[offset..offset + blob.len], blob)
		cursor = offset + blob.len
	}
}

pub struct WebGLCommandRecord {
pub:
	type_   WebGLCommandType
	payload []u8
}

pub struct WebGLCommandList {
mut:
	bytes_ []u8
}

pub fn WebGLCommandList.first_inline_data_offset(command_size int) u32 {
	return u32(align_command_value(command_size) or { 0 })
}

pub fn WebGLCommandList.next_inline_data_offset(previous WebGLDataSpan) u32 {
	end := u64(previous.offset) + u64(previous.size)
	if end > u64(max_int) {
		return 0
	}
	return u32(align_command_value(int(end)) or { 0 })
}

pub fn WebGLCommandList.padded_record_size(payload []u8, inline_data []u8) !int {
	layout_size := payload_layout_size(payload, inline_data, []u8{})!
	if layout_size > max_int - webgl_command_header_size {
		return error('WebGL command record size overflow')
	}
	return align_command_value(webgl_command_header_size + layout_size)
}

pub fn WebGLCommandList.write_record(mut destination []u8, type_ WebGLCommandType, payload []u8, inline_data []u8) ! {
	record_size := WebGLCommandList.padded_record_size(payload, inline_data)!
	if destination.len != record_size {
		return error('WebGL command destination has the wrong size')
	}
	padded_payload_size := destination.len - webgl_command_header_size
	if u64(padded_payload_size) > u64(max_u32) {
		return error('WebGL command payload exceeds u32')
	}
	destination[0] = u8(type_ & 0xff)
	destination[1] = u8(type_ >> 8)
	destination[2] = 0
	destination[3] = 0
	payload_size_bytes := binary.little_endian_get_u32(u32(padded_payload_size))
	copy(mut destination[4..8], payload_size_bytes)
	write_payload(mut destination[webgl_command_header_size..], payload, inline_data, []u8{})!
}

pub fn (mut list WebGLCommandList) append_bytes(type_ WebGLCommandType, payload []u8, inline_data []u8) ! {
	if list.bytes_.len % webgl_command_alignment != 0 {
		return error('WebGL command list is not aligned')
	}
	record_size := WebGLCommandList.padded_record_size(payload, inline_data)!
	if record_size > max_int - list.bytes_.len {
		return error('WebGL command list size overflow')
	}
	record_offset := list.bytes_.len
	list.bytes_ << []u8{len: record_size}
	WebGLCommandList.write_record(mut list.bytes_[record_offset..], type_, payload, inline_data)!
}

pub fn WebGLCommandList.for_each_command(bytes []u8) ![]WebGLCommandRecord {
	mut records := []WebGLCommandRecord{}
	mut offset := 0
	for offset < bytes.len {
		if bytes.len - offset < webgl_command_header_size {
			return error('Truncated WebGL command header')
		}
		type_ := WebGLCommandType(u16(bytes[offset]) | (u16(bytes[offset + 1]) << 8))
		if type_ >= webgl_command_type_count {
			return error('Invalid WebGL command type')
		}
		payload_size := u64(binary.little_endian_u32_at(bytes, offset + 4))
		remaining_size := u64(bytes.len - offset - webgl_command_header_size)
		if payload_size > remaining_size {
			return error('Truncated WebGL command payload')
		}
		payload_start := offset + webgl_command_header_size
		payload_end := payload_start + int(payload_size)
		records << WebGLCommandRecord{
			type_: type_
			payload: bytes[payload_start..payload_end].clone()
		}
		offset = payload_end
	}
	return records
}

pub fn WebGLCommandList.resolve_data_span(payload []u8, span WebGLDataSpan) ![]u8 {
	if u64(span.offset) > u64(payload.len)
		|| u64(span.size) > u64(payload.len) - u64(span.offset) {
		return error('WebGL data span is outside its payload')
	}
	return payload[int(span.offset)..int(span.offset + span.size)]
}

pub fn WebGLCommandList.resolve_typed_span(payload []u8, span WebGLDataSpan, element_size int, element_alignment int) ![]u8 {
	if element_size <= 0 || element_alignment <= 0 || span.offset % u32(element_alignment) != 0
		|| span.size % u32(element_size) != 0 {
		return error('WebGL typed data span is misaligned')
	}
	return WebGLCommandList.resolve_data_span(payload, span)
}

pub fn WebGLCommandList.resolve_string_span(payload []u8, span WebGLDataSpan) ![]u8 {
	bytes := WebGLCommandList.resolve_data_span(payload, span)!
	if bytes.len == 0 || bytes.last() != 0 {
		return error('WebGL string span is not NUL terminated')
	}
	return bytes
}

pub fn WebGLCommandList.copy_data_span(payload []u8, span WebGLDataSpan, mut destination []u8) ! {
	resolved := WebGLCommandList.resolve_data_span(payload, span)!
	if resolved.len > destination.len {
		return error('WebGL data span destination is too small')
	}
	copy(mut destination[..resolved.len], resolved)
}

pub fn (list &WebGLCommandList) bytes() []u8 {
	return list.bytes_.clone()
}

pub fn (list &WebGLCommandList) buffer() []u8 {
	return list.bytes_.clone()
}

pub fn (mut list WebGLCommandList) clear_with_capacity() {
	list.bytes_.clear()
}

pub fn (list &WebGLCommandList) is_empty() bool {
	return list.bytes_.len == 0
}

pub fn (list &WebGLCommandList) size_in_bytes() int {
	return list.bytes_.len
}

pub struct WebGLSyncRequest {
pub:
	type_   WebGLSyncCallType
	payload []u8
}

pub struct WebGLSyncCall {}

pub fn WebGLSyncCall.encode_request_bytes(type_ WebGLSyncCallType, request []u8, inline_data []u8) ![]u8 {
	layout_size := payload_layout_size(request, inline_data, []u8{})!
	padded_payload_size := align_command_value(layout_size)!
	if u64(padded_payload_size) > u64(max_u32) {
		return error('WebGL sync call payload exceeds u32')
	}
	mut bytes := []u8{len: webgl_sync_call_header_size + padded_payload_size}
	bytes[0] = u8(type_ & 0xff)
	bytes[1] = u8(type_ >> 8)
	payload_size_bytes := binary.little_endian_get_u32(u32(padded_payload_size))
	copy(mut bytes[4..8], payload_size_bytes)
	write_payload(mut bytes[webgl_sync_call_header_size..], request, inline_data, []u8{})!
	return bytes
}

pub fn WebGLSyncCall.dispatch_request(bytes []u8) !WebGLSyncRequest {
	if bytes.len < webgl_sync_call_header_size {
		return error('Truncated WebGL sync call header')
	}
	type_ := WebGLSyncCallType(u16(bytes[0]) | (u16(bytes[1]) << 8))
	if type_ >= webgl_sync_call_type_count {
		return error('Invalid WebGL sync call type')
	}
	payload_size := u64(binary.little_endian_u32_at(bytes, 4))
	if payload_size != u64(bytes.len - webgl_sync_call_header_size) {
		return error('Truncated WebGL sync call payload')
	}
	return WebGLSyncRequest{
		type_: type_
		payload: bytes[webgl_sync_call_header_size..].clone()
	}
}

pub fn WebGLSyncCall.encode_reply_bytes(reply []u8, inline_data []u8, more_inline_data []u8) ![]u8 {
	if more_inline_data.len > 0 && inline_data.len == 0 {
		return error('A second WebGL reply span requires a first span')
	}
	layout_size := payload_layout_size(reply, inline_data, more_inline_data)!
	reply_size := align_command_value(layout_size)!
	mut bytes := []u8{len: reply_size}
	write_payload(mut bytes, reply, inline_data, more_inline_data)!
	return bytes
}

pub fn WebGLSyncCall.decode_reply(bytes []u8, reply_size int) ![]u8 {
	if reply_size < 0 || bytes.len < reply_size {
		return error('Truncated WebGL sync reply')
	}
	return bytes[..reply_size].clone()
}

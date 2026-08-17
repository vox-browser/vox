// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebIDL/Buffers.{h,cpp} and buffer-source operations from
// WebIDL/AbstractOperations.cpp.
module webidl

pub enum BufferSourceKind {
	array_buffer
	data_view
	int8_array
	uint8_array
	uint8_clamped_array
	int16_array
	uint16_array
	int32_array
	uint32_array
	bigint64_array
	biguint64_array
	float32_array
	float64_array
}

pub struct BufferSource {
pub:
	kind          BufferSourceKind
	byte_offset   u32
	byte_length   u32
	detached      bool
	out_of_bounds bool
pub mut:
	bytes []u8
}

pub fn BufferSource.array_buffer(bytes []u8) BufferSource {
	return BufferSource{
		kind:        .array_buffer
		byte_length: u32(bytes.len)
		bytes:       bytes.clone()
	}
}

pub fn BufferSource.view(kind BufferSourceKind, bytes []u8, offset u32, length u32) !BufferSource {
	if kind == .array_buffer {
		return error('TypeError: use array_buffer for an ArrayBuffer')
	}
	if u64(offset) + u64(length) > u64(bytes.len) {
		return error('RangeError: buffer view is out of bounds')
	}
	element_size := element_size_for_kind(kind)
	if kind != .data_view && (offset % element_size != 0 || length % element_size != 0) {
		return error('RangeError: typed-array byte offset and length must be element aligned')
	}
	return BufferSource{
		kind:        kind
		byte_offset: offset
		byte_length: length
		bytes:       bytes.clone()
	}
}

pub fn (source BufferSource) element_size() u32 {
	return element_size_for_kind(source.kind)
}

fn element_size_for_kind(kind BufferSourceKind) u32 {
	return match kind {
		.int16_array, .uint16_array { 2 }
		.int32_array, .uint32_array, .float32_array { 4 }
		.bigint64_array, .biguint64_array, .float64_array { 8 }
		else { 1 }
	}
}

pub fn (source BufferSource) is_array_buffer() bool {
	return source.kind == .array_buffer
}

pub fn (source BufferSource) is_data_view() bool {
	return source.kind == .data_view
}

pub fn (source BufferSource) is_typed_array() bool {
	return source.kind !in [.array_buffer, .data_view]
}

pub fn is_buffer_source_detached(value Value) bool {
	if source := value.buffer_value {
		return source.detached
	}
	return false
}

// get_buffer_source_copy returns an empty byte sequence for detached or
// out-of-bounds sources, exactly like the upstream operation.
pub fn get_buffer_source_copy(source BufferSource) []u8 {
	if source.detached || source.out_of_bounds {
		return []u8{}
	}
	if source.kind == .array_buffer {
		return source.bytes.clone()
	}
	start := int(source.byte_offset)
	end := start + int(source.byte_length)
	if start < 0 || end > source.bytes.len {
		return []u8{}
	}
	return source.bytes[start..end].clone()
}

pub fn (mut source BufferSource) write(bytes []u8, starting_offset u32) ! {
	if source.detached || source.out_of_bounds {
		return error('InvalidStateError: cannot write a detached or out-of-bounds view')
	}
	if source.is_typed_array() && bytes.len % int(source.element_size()) != 0 {
		return error('RangeError: byte count must be a multiple of the typed-array element size')
	}
	start := int(source.byte_offset + starting_offset)
	view_end := int(source.byte_offset + source.byte_length)
	if start < int(source.byte_offset) || start + bytes.len > view_end
		|| start + bytes.len > source.bytes.len {
		return error('RangeError: bytes do not fit in the view')
	}
	for index in 0 .. bytes.len {
		source.bytes[start + index] = bytes[index]
	}
}

// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebGLRenderingContextBase's BufferSource and typed-array
// helpers. Offsets and overrides are expressed in elements, matching WebIDL.
module webgl

pub struct WebGLBufferSource {
pub:
	buffer        []u8
	byte_offset   int
	byte_length   int
	element_size  int = 1
	detached      bool
	out_of_bounds bool
}

pub struct SpanWithStorage {
mut:
	storage_     []u8
	element_size int = 1
}

pub fn (span &SpanWithStorage) size() int {
	if span.element_size <= 0 {
		return 0
	}
	return span.storage_.len / span.element_size
}

// The returned view aliases the span's owned storage, like C++ Span::data().
pub fn (span &SpanWithStorage) data() []u8 {
	return span.storage_
}

fn checked_buffer_source_range(source WebGLBufferSource, source_offset u64, source_length_override u32) !(int, int) {
	if source.detached {
		return error('BufferSource is detached')
	}
	if source.out_of_bounds {
		if source_offset == 0 && source_length_override == 0 {
			return 0, 0
		}
		return error('BufferSource is out of bounds')
	}
	if source.element_size <= 0 || source.byte_offset < 0 || source.byte_length < 0
		|| source.byte_offset > source.buffer.len
		|| source.byte_length > source.buffer.len - source.byte_offset {
		return error('BufferSource has an invalid view')
	}
	element_size := u64(source.element_size)
	if source_offset > max_u64 / element_size {
		return error('BufferSource byte offset overflow')
	}
	byte_offset_in_view := source_offset * element_size
	if byte_offset_in_view > u64(source.byte_length) {
		return error('BufferSource offset exceeds the view')
	}
	mut byte_length := u64(source.byte_length) - byte_offset_in_view
	if source_length_override != 0 {
		if u64(source_length_override) > max_u64 / element_size {
			return error('BufferSource byte length overflow')
		}
		requested_byte_length := u64(source_length_override) * element_size
		if requested_byte_length > byte_length {
			return error('BufferSource length exceeds the view')
		}
		byte_length = requested_byte_length
	}
	absolute_offset := u64(source.byte_offset) + byte_offset_in_view
	if absolute_offset < byte_offset_in_view || absolute_offset > u64(source.buffer.len)
		|| byte_length > u64(source.buffer.len) - absolute_offset {
		return error('BufferSource range exceeds its buffer')
	}
	return int(absolute_offset), int(byte_length)
}

// Readonly view adapter for synchronous host dispatch. It uses the same
// checked witness/range as with_buffer_source_bytes without callback capture.
pub fn buffer_source_bytes(source WebGLBufferSource, source_offset u64, source_length_override u32) ![]u8 {
    offset,length:=checked_buffer_source_range(source,source_offset,source_length_override)!
    return source.buffer[offset..offset+length]
}

pub fn with_buffer_source_bytes(source WebGLBufferSource, source_offset u64, source_length_override u32, callback fn ([]u8) !) ! {
	offset, length := checked_buffer_source_range(source, source_offset, source_length_override)!
	callback(source.buffer[offset..offset + length])!
}

pub fn span_from_typed_array(source WebGLBufferSource, source_offset u64, source_length_override u32) !SpanWithStorage {
	// A detached typed array is an out-of-bounds witness too. The typed-list
	// helper accepts an empty default range; BufferSource byte access rejects
	// detachment independently in checked_buffer_source_range above.
	if source.detached || source.out_of_bounds {
		if source_offset != 0 || source_length_override != 0 {return error('TypedArray is out of bounds')}
		return SpanWithStorage{element_size:source.element_size}
	}
	offset, length := checked_buffer_source_range(source, source_offset, source_length_override)!
	return SpanWithStorage{
		storage_: source.buffer[offset..offset + length].clone()
		element_size: source.element_size
	}
}

pub fn null_terminated_utf8_string(value string) []u8 {
	mut result := value.bytes()
	result << u8(0)
	return result
}

pub fn utf16_string_from_gl_string(data []u8, length int) string {
	if length <= 0 {
		return ''
	}
	end := if length > data.len { data.len } else { length }
	return data[..end].bytestr()
}

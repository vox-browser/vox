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
	float16_array
	float32_array
	float64_array
}

pub struct BufferSource {
pub:
	kind BufferSourceKind
mut:
	byte_offset_   u32
	byte_length_   u32
	// This typed boundary represents fixed views. Source initializes the
	// retained [[ArrayLength]] separately from the buffer witness length.
	array_length_  u32
	detached_      bool
	out_of_bounds_ bool
	bytes_         []u8
}

pub fn BufferSource.array_buffer(bytes []u8) BufferSource {
	return BufferSource{
		kind: .array_buffer
		byte_length_: u32(bytes.len)
		bytes_: bytes.clone()
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
		kind: kind
		byte_offset_: offset
		byte_length_: length
		array_length_: if kind == .data_view { u32(0) } else { length / element_size }
		bytes_: bytes.clone()
	}
}

// TypedArray.h::array_length and TypedArray.cpp's fixed-view initialization.
// Detachment/OOB changes the witness, not this retained fixed slot. Native
// auto-length arrays require the actual JS TypedArray record instead.
pub fn (source &BufferSource) fixed_array_length() ?u32 {
	if !source.is_typed_array() { return none }
	return source.array_length_
}

// from_object is the typed V boundary corresponding to conversion from a JS
// ArrayBuffer, DataView, or TypedArray object.
pub fn BufferSource.from_object(source BufferSource) BufferSource {
	return source
}

pub fn (source &BufferSource) buffer_source() BufferSource {
	return *source
}

pub fn (source &BufferSource) byte_length() u32 {
	if source.out_of_bounds_ {
		return 0
	}
	return source.byte_length_
}

pub fn (source &BufferSource) byte_offset() u32 {
	return if source.kind == .array_buffer { u32(0) } else { source.byte_offset_ }
}

pub fn (source &BufferSource) element_size() u32 {
	return element_size_for_kind(source.kind)
}

fn element_size_for_kind(kind BufferSourceKind) u32 {
	return match kind {
		.int16_array, .uint16_array, .float16_array { 2 }
		.int32_array, .uint32_array, .float32_array { 4 }
		.bigint64_array, .biguint64_array, .float64_array { 8 }
		else { 1 }
	}
}

pub fn (source &BufferSource) viewed_array_buffer() BufferSource {
	return BufferSource{
		kind: .array_buffer
		byte_length_: u32(source.bytes_.len)
		detached_: source.detached_
		out_of_bounds_: source.out_of_bounds_
		bytes_: source.bytes_.clone()
	}
}

pub fn (source &BufferSource) typed_array_base() ?BufferSource {
	if source.is_typed_array() {
		return *source
	}
	return none
}

pub fn (source &BufferSource) is_out_of_bounds() bool {
	return source.out_of_bounds_
}

pub fn (source &BufferSource) is_array_buffer() bool {
	return source.kind == .array_buffer
}

pub fn (source &BufferSource) is_data_view() bool {
	return source.kind == .data_view
}

pub fn (source &BufferSource) is_typed_array() bool {
	return source.kind !in [.array_buffer, .data_view]
}

pub fn BufferSource.is_detached(value Value) bool {
	if source := value.buffer_value {
		return source.detached_
	}
	return false
}

pub fn is_buffer_source_detached(value Value) bool {
	return BufferSource.is_detached(value)
}

pub struct ArrayBufferView {
mut:
	array_buffer_view_ BufferSource
}

pub fn ArrayBufferView.from_object(source BufferSource) !ArrayBufferView {
	return ArrayBufferView.create(source)
}

pub fn ArrayBufferView.create(source BufferSource) !ArrayBufferView {
	if source.kind == .array_buffer {
		return error('TypeError: ArrayBufferView requires a DataView or TypedArray')
	}
	return ArrayBufferView{
		array_buffer_view_: source
	}
}

pub fn (view &ArrayBufferView) array_buffer_view() BufferSource {
	return view.array_buffer_view_
}

pub fn (view &ArrayBufferView) byte_length() u32 {
	return view.array_buffer_view_.byte_length()
}

pub fn (view &ArrayBufferView) byte_offset() u32 {
	return view.array_buffer_view_.byte_offset()
}

pub fn (view &ArrayBufferView) element_size() u32 {
	return view.array_buffer_view_.element_size()
}

pub fn (view &ArrayBufferView) viewed_array_buffer() BufferSource {
	return view.array_buffer_view_.viewed_array_buffer()
}

pub fn (view &ArrayBufferView) typed_array_base() ?BufferSource {
	return view.array_buffer_view_.typed_array_base()
}

pub fn (view &ArrayBufferView) is_out_of_bounds() bool {
	return view.array_buffer_view_.is_out_of_bounds()
}

pub fn (view &ArrayBufferView) is_data_view() bool {
	return view.array_buffer_view_.is_data_view()
}

pub struct ValidatedBufferSource {
pub:
	buffer          BufferSource
	byte_offset     uint
	byte_length     uint
	element_size    uint = 1
	is_data_view    bool
	is_array_buffer bool
}

fn validate_buffer_source_bounds(source BufferSource, byte_offset uint, byte_length uint, element_size uint, is_data_view bool, is_array_buffer bool) !ValidatedBufferSource {
	if source.detached_ {
		return error('InvalidStateError: buffer source is detached')
	}
	byte_end := u64(byte_offset) + u64(byte_length)
	if byte_end < u64(byte_offset) || byte_end > u64(source.bytes_.len) {
		return error('RangeError: buffer source is out of bounds')
	}
	return ValidatedBufferSource{
		buffer: source.viewed_array_buffer()
		byte_offset: byte_offset
		byte_length: byte_length
		element_size: element_size
		is_data_view: is_data_view
		is_array_buffer: is_array_buffer
	}
}

pub fn validate_buffer_source(source BufferSource) !ValidatedBufferSource {
	if source.is_out_of_bounds() {
		return error('RangeError: buffer source is out of bounds')
	}
	return validate_buffer_source_bounds(source, uint(source.byte_offset()), uint(source.byte_length()), uint(source.element_size()), source.is_data_view(), source.is_array_buffer())
}

pub fn validate_array_buffer_view(view ArrayBufferView) !ValidatedBufferSource {
	return validate_buffer_source(view.array_buffer_view_)
}

// https://webidl.spec.whatwg.org/#arraybufferview-write
pub fn (mut view ArrayBufferView) write_checked(bytes []u8, starting_offset u32) ! {
	view_byte_length := view.byte_length()
	if starting_offset > view_byte_length || u64(bytes.len) > u64(view_byte_length - starting_offset) {
		return error('RangeError: bytes do not fit in the view')
	}
	if !view.is_data_view() && bytes.len % int(view.element_size()) != 0 {
		return error('RangeError: byte count must be a multiple of the typed-array element size')
	}
	if bytes.len == 0 {
		return
	}
	validated := validate_array_buffer_view(view)!
	write_offset := u64(validated.byte_offset) + u64(starting_offset)
	if write_offset < u64(validated.byte_offset) || write_offset > u64(view.array_buffer_view_.bytes_.len)
		|| u64(bytes.len) > u64(view.array_buffer_view_.bytes_.len) - write_offset {
		return error('RangeError: bytes do not fit in the backing buffer')
	}
	for index, byte in bytes {
		view.array_buffer_view_.bytes_[int(write_offset) + index] = byte
	}
}

pub fn (mut view ArrayBufferView) write(bytes []u8, starting_offset u32) ! {
	view.write_checked(bytes, starting_offset)!
}

pub fn (view &ArrayBufferView) raw_object() BufferSource {
	return view.array_buffer_view_
}

// get_buffer_source_copy returns an empty byte sequence for detached or
// out-of-bounds sources, exactly like the upstream operation.
pub fn get_buffer_source_copy(source BufferSource) []u8 {
	validated := validate_buffer_source(source) or { return []u8{} }
	start := int(validated.byte_offset)
	end := start + int(validated.byte_length)
	return source.bytes_[start..end].clone()
}

pub fn (mut source BufferSource) write(bytes []u8, starting_offset u32) ! {
	if source.kind == .array_buffer {
		mut view := ArrayBufferView{
			array_buffer_view_: source
		}
		view.write_checked(bytes, starting_offset)!
		source = view.array_buffer_view_
		return
	}
	mut view := ArrayBufferView.create(source)!
	view.write_checked(bytes, starting_offset)!
	source = view.array_buffer_view_
}

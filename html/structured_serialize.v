// Copyright (c) 2022, Daniel Ehrenberg <dan@littledan.dev>
// Copyright (c) 2022, Andrew Kaster <akaster@serenityos.org>
// Copyright (c) 2024, Kenneth Myhra <kennethmyhra@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of StructuredSerialize.{h,cpp} and StructuredSerializeTypes.h.
module html

import dom
import math
import libjs

// StructuredObject is the small host-independent object model used until the
// LibJS VM is translated. Its address is the object identity used by the
// structured clone memory, so aliases and cycles are preserved.
pub enum StructuredObjectKind {
	boolean_object
	number_object
	string_object
	big_int_object
	date
	regexp
	map
	set
	array
	error_object
	object
	array_buffer
	array_buffer_view
	shared_array_buffer
}

pub enum AllowSharedArrayBuffers {
	cross_origin_isolated_only
	same_agent_always
}

@[heap]
pub struct StructuredSharedArrayBufferBackingStore {
pub mut:
	bytes []u8
}

pub enum StructuredErrorType {
	error
	eval_error
	range_error
	reference_error
	syntax_error
	type_error
	uri_error
}

pub struct StructuredProperty {
pub:
	key   string
	value &dom.JSValue = unsafe { nil }
}

pub struct StructuredMapEntry {
pub:
	key   &dom.JSValue = unsafe { nil }
	value &dom.JSValue = unsafe { nil }
}

@[heap]
pub struct StructuredObject {
pub:
	kind StructuredObjectKind
pub mut:
	boolean_data        bool
	number_data         f64
	string_data         string
	second_string_data  string
	error_type          StructuredErrorType
	has_cause           bool
	cause               string
	bytes               []u8
	shared_backing_store ?&StructuredSharedArrayBufferBackingStore
	max_byte_length      ?u32
	viewed_array_buffer ?&StructuredObject
	byte_length         ?u32
	byte_offset         u32
	array_length        ?u32
	values              []&dom.JSValue
	entries             []StructuredMapEntry
	properties          []StructuredProperty
}

pub fn StructuredObject.create(kind StructuredObjectKind) &StructuredObject {
	return &StructuredObject{
		kind: kind
	}
}

pub fn StructuredObject.create_shared_array_buffer(bytes []u8, max_byte_length ?u32) &StructuredObject {
	return &StructuredObject{
		kind: .shared_array_buffer
		shared_backing_store: &StructuredSharedArrayBufferBackingStore{
			bytes: bytes.clone()
		}
		max_byte_length: max_byte_length
	}
}

pub fn (object &StructuredObject) array_buffer_bytes() []u8 {
	if object.kind == .shared_array_buffer {
		store := object.shared_backing_store or { return [] }
		return store.bytes
	}
	return object.bytes
}

pub fn (mut object StructuredObject) overwrite_array_buffer(offset int, bytes []u8) ! {
	if offset < 0 {
		return error('RangeError: ArrayBuffer write starts before the buffer')
	}
	if object.kind == .shared_array_buffer {
		mut store := object.shared_backing_store or {
			return error('TypeError: SharedArrayBuffer has no backing store')
		}
		if offset > store.bytes.len || bytes.len > store.bytes.len - offset {
			return error('RangeError: ArrayBuffer write exceeds the buffer')
		}
		for index, byte in bytes {
			store.bytes[offset + index] = byte
		}
		return
	}
	if object.kind != .array_buffer {
		return error('TypeError: value is not an ArrayBuffer')
	}
	if offset > object.bytes.len || bytes.len > object.bytes.len - offset {
		return error('RangeError: ArrayBuffer write exceeds the buffer')
	}
	for index, byte in bytes {
		object.bytes[offset + index] = byte
	}
}

pub fn (mut object StructuredObject) grow_shared_array_buffer(new_byte_length int) ! {
	if object.kind != .shared_array_buffer {
		return error('TypeError: value is not a SharedArrayBuffer')
	}
	max_byte_length := object.max_byte_length or {
		return error('TypeError: SharedArrayBuffer is fixed length')
	}
	mut store := object.shared_backing_store or {
		return error('TypeError: SharedArrayBuffer has no backing store')
	}
	if new_byte_length < store.bytes.len || u64(new_byte_length) > u64(max_byte_length) {
		return error('RangeError: invalid SharedArrayBuffer growth length')
	}
	store.bytes << []u8{len: new_byte_length - store.bytes.len}
}

pub fn structured_object_value(object &StructuredObject) dom.JSValue {
	return dom.js_structured_object(voidptr(object))
}

pub fn structured_object_from_value(value dom.JSValue) !&StructuredObject {
	if !value.is_structured_object() || value.object_data == unsafe { nil } {
		return error('DataCloneError: value is not a structured-clone object')
	}
	return unsafe { &StructuredObject(value.object_data) }
}

fn error_name_to_type(name string) StructuredErrorType {
	return match name {
		'EvalError' { .eval_error }
		'RangeError' { .range_error }
		'ReferenceError' { .reference_error }
		'SyntaxError' { .syntax_error }
		'TypeError' { .type_error }
		'URIError' { .uri_error }
		else { .error }
	}
}

struct StructuredSerializer {
mut:
	data                 []u8
	memory               map[u64]u32
	shared_array_buffers []&StructuredObject
}

fn (mut serializer StructuredSerializer) write_u8(value u8) {
	serializer.data << value
}

fn (mut serializer StructuredSerializer) write_u32(value u32) {
	serializer.data << u8(value)
	serializer.data << u8(value >> 8)
	serializer.data << u8(value >> 16)
	serializer.data << u8(value >> 24)
}

fn (mut serializer StructuredSerializer) write_u64(value u64) {
	for shift in 0 .. 8 {
		serializer.data << u8(value >> (shift * 8))
	}
}

fn (mut serializer StructuredSerializer) write_f64(value f64) {
	serializer.write_u64(math.f64_bits(value))
}

fn (mut serializer StructuredSerializer) write_bytes(value []u8) ! {
	if u64(value.len) > u64(4294967295) {
		return error('DataCloneError: byte sequence is too large')
	}
	serializer.write_u32(u32(value.len))
	serializer.data << value
}

fn (mut serializer StructuredSerializer) write_string(value string) ! {
	serializer.write_bytes(value.bytes())!
}

fn (mut serializer StructuredSerializer) write_tag(tag StructuredSerializeValueTag) {
	serializer.write_u8(u8(tag))
}

fn (mut serializer StructuredSerializer) write_optional_u32(value ?u32) {
	if actual := value {
		serializer.write_u8(1)
		serializer.write_u32(actual)
	} else {
		serializer.write_u8(0)
	}
}

fn serialize_array_buffer(mut serializer StructuredSerializer, array_buffer &StructuredObject, for_storage bool, allow_shared_array_buffers AllowSharedArrayBuffers) ! {
	if array_buffer.kind != .array_buffer && array_buffer.kind != .shared_array_buffer {
		return error('DataCloneError: value is not an ArrayBuffer')
	}
	if array_buffer.kind == .shared_array_buffer {
		if allow_shared_array_buffers == .cross_origin_isolated_only {
			return error('DataCloneError: cannot serialize SharedArrayBuffer when cross-origin isolated capability is unavailable')
		}
		if for_storage {
			return error('DataCloneError: cannot serialize SharedArrayBuffer for storage')
		}
		store := array_buffer.shared_backing_store or {
			return error('DataCloneError: SharedArrayBuffer has no backing store')
		}
		if max_byte_length := array_buffer.max_byte_length {
			if max_byte_length < u32(store.bytes.len) {
				return error('DataCloneError: SharedArrayBuffer maximum length is smaller than its byte length')
			}
			serializer.write_tag(.growable_shared_array_buffer)
		} else {
			serializer.write_tag(.shared_array_buffer)
		}
		if u64(serializer.shared_array_buffers.len) >= u64(4294967295) {
			return error('DataCloneError: too many SharedArrayBuffers')
		}
		serializer.write_u32(u32(serializer.shared_array_buffers.len))
		serializer.shared_array_buffers << array_buffer
		serializer.write_bytes(store.bytes)!
		if max_byte_length := array_buffer.max_byte_length {
			serializer.write_u32(max_byte_length)
		}
		return
	}
	// StructuredSerialize.cpp: serialize_array_buffer, steps 2.5–2.6.
	// Presence of [[ArrayBufferMaxByteLength]] distinguishes a resizable buffer,
	// including an empty buffer whose maximum is zero.
	if max_byte_length := array_buffer.max_byte_length {
		if max_byte_length < u32(array_buffer.bytes.len) {
			return error('DataCloneError: ArrayBuffer maximum length is smaller than its byte length')
		}
		serializer.write_tag(.resizable_array_buffer)
		serializer.write_bytes(array_buffer.bytes)!
		serializer.write_u32(max_byte_length)
	} else {
		serializer.write_tag(.array_buffer)
		serializer.write_bytes(array_buffer.bytes)!
	}
}

fn serialize_viewed_array_buffer(mut serializer StructuredSerializer, view &StructuredObject, for_storage bool, allow_shared_array_buffers AllowSharedArrayBuffers) ! {
	if view.kind != .array_buffer_view {
		return error('DataCloneError: value is not an ArrayBuffer view')
	}
	buffer := view.viewed_array_buffer or {
		return error('DataCloneError: ArrayBuffer view has no viewed buffer')
	}
	if buffer.kind != .array_buffer && buffer.kind != .shared_array_buffer {
		return error('DataCloneError: ArrayBuffer view has an invalid viewed buffer')
	}
	serializer.write_tag(.array_buffer_view)
	serializer.serialize_value(structured_object_value(buffer), for_storage, allow_shared_array_buffers)!
	serializer.write_string(view.string_data)!
	serializer.write_optional_u32(view.byte_length)
	serializer.write_u32(view.byte_offset)
	serializer.write_optional_u32(view.array_length)
}

fn (mut serializer StructuredSerializer) serialize_value(value dom.JSValue, for_storage bool, allow_shared_array_buffers AllowSharedArrayBuffers) ! {
	match value.kind {
		.undefined {
			serializer.write_tag(.undefined_primitive)
			return
		}
		.null_ {
			serializer.write_tag(.null_primitive)
			return
		}
		.boolean {
			serializer.write_tag(.boolean_primitive)
			serializer.write_u8(if value.boolean_data { u8(1) } else { u8(0) })
			return
		}
		.number {
			if libjs.Value.from_f64(value.number_data).is_int32() {
				serializer.write_tag(.int32_primitive)
				serializer.write_u32(u32(i32(value.number_data)))
			} else {
				serializer.write_tag(.number_primitive)
				serializer.write_f64(value.number_data)
			}
			return
		}
		.string {
			serializer.write_tag(.string_primitive)
			serializer.write_string(value.string_data)!
			return
		}
		.object {}
		.runtime_value { return error('DataCloneError: actual host JavaScript values require their engine structured-clone binding') }
	}

	object := structured_object_from_value(value)!
	identity := u64(voidptr(object))
	if id := serializer.memory[identity] {
		serializer.write_tag(.object_reference)
		serializer.write_u32(id)
		return
	}
	serializer.memory[identity] = u32(serializer.memory.len)

	match object.kind {
		.boolean_object {
			serializer.write_tag(.boolean_object)
			serializer.write_u8(if object.boolean_data { u8(1) } else { u8(0) })
		}
		.number_object {
			serializer.write_tag(.number_object)
			serializer.write_f64(object.number_data)
		}
		.string_object {
			serializer.write_tag(.string_object)
			serializer.write_string(object.string_data)!
		}
		.big_int_object {
			serializer.write_tag(.big_int_object)
			serializer.write_string(object.string_data)!
		}
		.date {
			serializer.write_tag(.date_object)
			serializer.write_f64(object.number_data)
		}
		.regexp {
			serializer.write_tag(.regexp_object)
			serializer.write_string(object.string_data)!
			serializer.write_string(object.second_string_data)!
		}
		.map {
			serializer.write_tag(.map_object)
			serializer.write_u32(u32(object.entries.len))
			for entry in object.entries {
				if entry.key == unsafe { nil } || entry.value == unsafe { nil } {
					return error('DataCloneError: map contains a missing key or value')
				}
				serializer.serialize_value(*entry.key, for_storage, allow_shared_array_buffers)!
				serializer.serialize_value(*entry.value, for_storage, allow_shared_array_buffers)!
			}
		}
		.set {
			serializer.write_tag(.set_object)
			serializer.write_u32(u32(object.values.len))
			for item in object.values {
				if item == unsafe { nil } {
					return error('DataCloneError: set contains a missing value')
				}
				serializer.serialize_value(*item, for_storage, allow_shared_array_buffers)!
			}
		}
		.array {
			serializer.write_tag(.array_object)
			serializer.write_u32(u32(object.values.len))
			for item in object.values {
				if item == unsafe { nil } {
					return error('DataCloneError: array contains a missing value')
				}
				serializer.serialize_value(*item, for_storage, allow_shared_array_buffers)!
			}
		}
		.error_object {
			serializer.write_tag(.error_object)
			serializer.write_u8(u8(object.error_type))
			serializer.write_string(object.string_data)!
			serializer.write_u8(if object.has_cause { u8(1) } else { u8(0) })
			if object.has_cause {
				serializer.write_string(object.cause)!
			}
		}
		.object {
			serializer.write_tag(.object)
			serializer.write_u32(u32(object.properties.len))
			for property in object.properties {
				if property.value == unsafe { nil } {
					return error('DataCloneError: object contains a missing property value')
				}
				serializer.write_string(property.key)!
				serializer.serialize_value(*property.value, for_storage, allow_shared_array_buffers)!
			}
		}
		.array_buffer {
			serialize_array_buffer(mut serializer, object, for_storage, allow_shared_array_buffers)!
		}
		.array_buffer_view {
			serialize_viewed_array_buffer(mut serializer, object, for_storage, allow_shared_array_buffers)!
		}
		.shared_array_buffer {
			serialize_array_buffer(mut serializer, object, for_storage, allow_shared_array_buffers)!
		}
	}
}

pub fn structured_serialize(value dom.JSValue) !SerializationRecord {
	return structured_serialize_with_shared_array_buffers(value, .cross_origin_isolated_only)
}

pub fn structured_serialize_with_shared_array_buffers(value dom.JSValue, allow_shared_array_buffers AllowSharedArrayBuffers) !SerializationRecord {
	mut serializer := StructuredSerializer{}
	serializer.serialize_value(value, false, allow_shared_array_buffers)!
	return SerializationRecord{
		data: serializer.data
		shared_array_buffers: serializer.shared_array_buffers
	}
}

pub fn structured_serialize_for_storage(value dom.JSValue) !SerializationRecord {
	return structured_serialize_for_storage_with_shared_array_buffers(value, .cross_origin_isolated_only)
}

fn structured_serialize_for_storage_with_shared_array_buffers(value dom.JSValue, allow_shared_array_buffers AllowSharedArrayBuffers) !SerializationRecord {
	mut serializer := StructuredSerializer{}
	serializer.serialize_value(value, true, allow_shared_array_buffers)!
	return SerializationRecord{
		data: serializer.data
	}
}

struct StructuredDecoder {
	data                 []u8
	shared_array_buffers []&StructuredObject
mut:
	offset int
	memory []&dom.JSValue
}

fn (mut decoder StructuredDecoder) read_u8() !u8 {
	if decoder.offset >= decoder.data.len {
		return error('DataCloneError: truncated serialization record')
	}
	value := decoder.data[decoder.offset]
	decoder.offset++
	return value
}

fn (mut decoder StructuredDecoder) read_u32() !u32 {
	if decoder.offset + 4 > decoder.data.len {
		return error('DataCloneError: truncated serialization record')
	}
	value := u32(decoder.data[decoder.offset]) | (u32(decoder.data[decoder.offset + 1]) << 8) | (u32(decoder.data[decoder.offset + 2]) << 16) | (u32(decoder.data[decoder.offset + 3]) << 24)
	decoder.offset += 4
	return value
}

fn (mut decoder StructuredDecoder) read_u64() !u64 {
	if decoder.offset + 8 > decoder.data.len {
		return error('DataCloneError: truncated serialization record')
	}
	mut value := u64(0)
	for shift in 0 .. 8 {
		value |= u64(decoder.data[decoder.offset + shift]) << (shift * 8)
	}
	decoder.offset += 8
	return value
}

fn (mut decoder StructuredDecoder) read_f64() !f64 {
	return math.f64_from_bits(decoder.read_u64()!)
}

fn (mut decoder StructuredDecoder) read_bytes() ![]u8 {
	length := int(decoder.read_u32()!)
	if length < 0 || length > decoder.data.len - decoder.offset {
		return error('DataCloneError: truncated serialization record')
	}
	value := decoder.data[decoder.offset..decoder.offset + length].clone()
	decoder.offset += length
	return value
}

fn (mut decoder StructuredDecoder) read_string() !string {
	return decoder.read_bytes()!.bytestr()
}

struct DecodedOptionalU32 {
	value ?u32
}

fn (mut decoder StructuredDecoder) read_optional_u32() !DecodedOptionalU32 {
	present := decoder.read_u8()!
	if present > 1 {
		return error('DataCloneError: invalid optional integer encoding')
	}
	if present == 0 {
		return DecodedOptionalU32{}
	}
	return DecodedOptionalU32{
		value: decoder.read_u32()!
	}
}

fn (mut decoder StructuredDecoder) register_object(object &StructuredObject) &dom.JSValue {
	value := &dom.JSValue{
		kind: .object
		object_data: voidptr(object)
		is_structured_object_: true
	}
	decoder.memory << value
	return value
}

fn (mut decoder StructuredDecoder) decode_value() !&dom.JSValue {
	tag_byte := decoder.read_u8()!
	if tag_byte == 0 || tag_byte > u8(StructuredSerializeValueTag.int32_primitive) {
		return error('DataCloneError: invalid structured serialization tag')
	}
	tag := unsafe { StructuredSerializeValueTag(tag_byte) }
	match tag {
		.undefined_primitive {
			return &dom.JSValue{}
		}
		.null_primitive {
			return &dom.JSValue{
				kind: .null_
			}
		}
		.boolean_primitive {
			value := decoder.read_u8()!
			if value > 1 {
				return error('DataCloneError: invalid Boolean encoding')
			}
			return &dom.JSValue{
				kind: .boolean
				boolean_data: value == 1
			}
		}
		.number_primitive {
			return &dom.JSValue{
				kind: .number
				number_data: decoder.read_f64()!
			}
		}
		.int32_primitive {
			return &dom.JSValue{kind: .number, number_data: f64(i32(decoder.read_u32()!))}
		}
		.string_primitive {
			return &dom.JSValue{
				kind: .string
				string_data: decoder.read_string()!
			}
		}
		.object_reference {
			index := int(decoder.read_u32()!)
			if index < 0 || index >= decoder.memory.len {
				return error('DataCloneError: invalid object reference')
			}
			return decoder.memory[index]
		}
		.boolean_object {
			encoded := decoder.read_u8()!
			if encoded > 1 {
				return error('DataCloneError: invalid Boolean object encoding')
			}
			mut object := StructuredObject.create(.boolean_object)
			value := decoder.register_object(object)
			object.boolean_data = encoded == 1
			return value
		}
		.number_object, .date_object {
			kind := if tag == .number_object {
				StructuredObjectKind.number_object
			} else {
				StructuredObjectKind.date
			}
			mut object := StructuredObject.create(kind)
			value := decoder.register_object(object)
			object.number_data = decoder.read_f64()!
			return value
		}
		.string_object, .big_int_object {
			kind := if tag == .string_object {
				StructuredObjectKind.string_object
			} else {
				StructuredObjectKind.big_int_object
			}
			mut object := StructuredObject.create(kind)
			value := decoder.register_object(object)
			object.string_data = decoder.read_string()!
			return value
		}
		.regexp_object {
			mut object := StructuredObject.create(.regexp)
			value := decoder.register_object(object)
			object.string_data = decoder.read_string()!
			object.second_string_data = decoder.read_string()!
			return value
		}
		.map_object {
			mut object := StructuredObject.create(.map)
			value := decoder.register_object(object)
			length := int(decoder.read_u32()!)
			for _ in 0 .. length {
				object.entries << StructuredMapEntry{
					key: decoder.decode_value()!
					value: decoder.decode_value()!
				}
			}
			return value
		}
		.set_object, .array_object {
			kind := if tag == .set_object {
				StructuredObjectKind.set
			} else {
				StructuredObjectKind.array
			}
			mut object := StructuredObject.create(kind)
			value := decoder.register_object(object)
			length := int(decoder.read_u32()!)
			for _ in 0 .. length {
				object.values << decoder.decode_value()!
			}
			return value
		}
		.error_object {
			mut object := StructuredObject.create(.error_object)
			value := decoder.register_object(object)
			error_type := decoder.read_u8()!
			if error_type > u8(StructuredErrorType.uri_error) {
				return error('DataCloneError: invalid Error type')
			}
			object.error_type = unsafe { StructuredErrorType(error_type) }
			object.string_data = decoder.read_string()!
			has_cause := decoder.read_u8()!
			if has_cause > 1 {
				return error('DataCloneError: invalid Error cause encoding')
			}
			object.has_cause = has_cause == 1
			if object.has_cause {
				object.cause = decoder.read_string()!
			}
			return value
		}
		.object {
			mut object := StructuredObject.create(.object)
			value := decoder.register_object(object)
			length := int(decoder.read_u32()!)
			for _ in 0 .. length {
				object.properties << StructuredProperty{
					key: decoder.read_string()!
					value: decoder.decode_value()!
				}
			}
			return value
		}
		.array_buffer, .resizable_array_buffer {
			mut object := StructuredObject.create(.array_buffer)
			value := decoder.register_object(object)
			object.bytes = decoder.read_bytes()!
			if tag == .resizable_array_buffer {
				max_byte_length := decoder.read_u32()!
				if max_byte_length < u32(object.bytes.len) {
					return error('DataCloneError: ArrayBuffer maximum length is smaller than its byte length')
				}
				object.max_byte_length = max_byte_length
			}
			return value
		}
		.shared_array_buffer, .growable_shared_array_buffer {
			side_table_index := int(decoder.read_u32()!)
			bytes := decoder.read_bytes()!
			mut max_byte_length := ?u32(none)
			if tag == .growable_shared_array_buffer {
				actual_max_byte_length := decoder.read_u32()!
				if actual_max_byte_length < u32(bytes.len) {
					return error('DataCloneError: SharedArrayBuffer maximum length is smaller than its byte length')
				}
				max_byte_length = actual_max_byte_length
			}
			mut object := StructuredObject.create_shared_array_buffer(bytes, max_byte_length)
			value := decoder.register_object(object)
			if side_table_index >= 0 && side_table_index < decoder.shared_array_buffers.len {
				source := decoder.shared_array_buffers[side_table_index]
				if source.kind == .shared_array_buffer {
					if source_store := source.shared_backing_store {
						object.shared_backing_store = source_store
					}
				}
			}
			return value
		}
		.array_buffer_view {
			mut object := StructuredObject.create(.array_buffer_view)
			value := decoder.register_object(object)
			buffer_value := decoder.decode_value()!
			buffer := structured_object_from_value(*buffer_value)!
			if buffer.kind != .array_buffer && buffer.kind != .shared_array_buffer {
				return error('DataCloneError: ArrayBuffer view references a non-buffer')
			}
			object.viewed_array_buffer = buffer
			object.string_data = decoder.read_string()!
			object.byte_length = decoder.read_optional_u32()!.value
			object.byte_offset = decoder.read_u32()!
			object.array_length = decoder.read_optional_u32()!.value
			return value
		}
		.empty, .big_int_primitive, .serializable_object, .end_object {
			return error('DataCloneError: unsupported structured serialization tag')
		}
	}
}

pub fn structured_deserialize(record SerializationRecord) !dom.JSValue {
	if record.data.len == 0 {
		return error('DataCloneError: empty serialization record')
	}
	mut decoder := StructuredDecoder{
		data: record.data
		shared_array_buffers: record.shared_array_buffers
	}
	value := decoder.decode_value()!
	if decoder.offset != decoder.data.len {
		return error('DataCloneError: trailing structured serialization data')
	}
	return *value
}

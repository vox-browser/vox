// Copyright (c) 2022, Daniel Ehrenberg <dan@littledan.dev>
// Copyright (c) 2022, Andrew Kaster <akaster@serenityos.org>
// Copyright (c) 2024, Kenneth Myhra <kennethmyhra@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of StructuredSerialize.{h,cpp} and StructuredSerializeTypes.h.
module html

import dom
import math

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
	boolean_data       bool
	number_data        f64
	string_data        string
	second_string_data string
	error_type         StructuredErrorType
	has_cause          bool
	cause              string
	bytes              []u8
	values             []&dom.JSValue
	entries            []StructuredMapEntry
	properties         []StructuredProperty
}

pub fn StructuredObject.create(kind StructuredObjectKind) &StructuredObject {
	return &StructuredObject{
		kind: kind
	}
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

struct StructuredSerializer {
mut:
	data   []u8
	memory map[u64]u32
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

fn (mut serializer StructuredSerializer) serialize_value(value dom.JSValue, for_storage bool) ! {
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
			serializer.write_tag(.number_primitive)
			serializer.write_f64(value.number_data)
			return
		}
		.string {
			serializer.write_tag(.string_primitive)
			serializer.write_string(value.string_data)!
			return
		}
		.object {}
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
				serializer.serialize_value(*entry.key, for_storage)!
				serializer.serialize_value(*entry.value, for_storage)!
			}
		}
		.set {
			serializer.write_tag(.set_object)
			serializer.write_u32(u32(object.values.len))
			for item in object.values {
				if item == unsafe { nil } {
					return error('DataCloneError: set contains a missing value')
				}
				serializer.serialize_value(*item, for_storage)!
			}
		}
		.array {
			serializer.write_tag(.array_object)
			serializer.write_u32(u32(object.values.len))
			for item in object.values {
				if item == unsafe { nil } {
					return error('DataCloneError: array contains a missing value')
				}
				serializer.serialize_value(*item, for_storage)!
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
				serializer.serialize_value(*property.value, for_storage)!
			}
		}
		.array_buffer {
			// ArrayBuffer cloning is allowed for storage. Transfer-only host
			// objects are rejected by structured_serialize_for_storage in the
			// transfer layer.
			_ = for_storage
			serializer.write_tag(.array_buffer)
			serializer.write_bytes(object.bytes)!
		}
	}
}

pub fn structured_serialize(value dom.JSValue) !SerializationRecord {
	mut serializer := StructuredSerializer{}
	serializer.serialize_value(value, false)!
	return SerializationRecord{
		data: serializer.data
	}
}

pub fn structured_serialize_for_storage(value dom.JSValue) !SerializationRecord {
	mut serializer := StructuredSerializer{}
	serializer.serialize_value(value, true)!
	return SerializationRecord{
		data: serializer.data
	}
}

struct StructuredDecoder {
	data []u8
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
	value := u32(decoder.data[decoder.offset]) | (u32(decoder.data[decoder.offset + 1]) << 8) | (u32(decoder.data[
		decoder.offset + 2]) << 16) | (u32(decoder.data[decoder.offset + 3]) << 24)
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

fn (mut decoder StructuredDecoder) register_object(object &StructuredObject) &dom.JSValue {
	value := &dom.JSValue{
		kind:                  .object
		object_data:           voidptr(object)
		is_structured_object_: true
	}
	decoder.memory << value
	return value
}

fn (mut decoder StructuredDecoder) decode_value() !&dom.JSValue {
	tag_byte := decoder.read_u8()!
	if tag_byte > u8(StructuredSerializeValueTag.array_buffer) {
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
			if value > 1 { return error('DataCloneError: invalid Boolean encoding') }
			return &dom.JSValue{
				kind:         .boolean
				boolean_data: value == 1
			}
		}
		.number_primitive {
			return &dom.JSValue{
				kind:        .number
				number_data: decoder.read_f64()!
			}
		}
		.string_primitive {
			return &dom.JSValue{
				kind:        .string
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
			if encoded > 1 { return error('DataCloneError: invalid Boolean object encoding') }
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
					key:   decoder.decode_value()!
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
			if has_cause > 1 { return error('DataCloneError: invalid Error cause encoding') }
			object.has_cause = has_cause == 1
			if object.has_cause { object.cause = decoder.read_string()! }
			return value
		}
		.object {
			mut object := StructuredObject.create(.object)
			value := decoder.register_object(object)
			length := int(decoder.read_u32()!)
			for _ in 0 .. length {
				object.properties << StructuredProperty{
					key:   decoder.read_string()!
					value: decoder.decode_value()!
				}
			}
			return value
		}
		.array_buffer {
			mut object := StructuredObject.create(.array_buffer)
			value := decoder.register_object(object)
			object.bytes = decoder.read_bytes()!
			return value
		}
		.empty, .big_int_primitive {
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
	}
	value := decoder.decode_value()!
	if decoder.offset != decoder.data.len {
		return error('DataCloneError: trailing structured serialization data')
	}
	return *value
}

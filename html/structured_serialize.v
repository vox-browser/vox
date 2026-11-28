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
import webidl
import webcrypto
import webassembly
import fileapi
import math.big

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
	serializable_object
	message_port
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
	internal_error
	range_error
	reference_error
	syntax_error
	type_error
	uri_error
}

pub struct StructuredProperty {
pub:
	key   string
	key_utf16_ ?libjs.Utf16String
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
	string_utf16_       ?libjs.Utf16String
	bigint_data         ?&libjs.BigInt
	second_string_data  string
	second_string_utf16_ ?libjs.Utf16String
	error_type          StructuredErrorType
	has_message         bool
	has_cause           bool
	cause               string
	cause_utf16_        ?libjs.Utf16String
	bytes               []u8
	shared_backing_store ?&StructuredSharedArrayBufferBackingStore
	max_byte_length      ?u64
	viewed_array_buffer ?&StructuredObject
	byte_length         ?u32
	byte_offset         u32
	array_length        ?u32
	null_prototype      bool
	values              []&dom.JSValue
	entries             []StructuredMapEntry
	properties          []StructuredProperty
	serializable_interface_ ?StructuredSerializableInterface
	dom_exception_      ?&webidl.DOMException
	quota_exceeded_error_ ?&webidl.QuotaExceededError
	crypto_key_         ?&webcrypto.CryptoKey
	webassembly_module_ ?&webassembly.Module
	blob_               ?&fileapi.Blob
	file_               ?&fileapi.File
	file_list_          ?&fileapi.FileList
	message_port_       ?&MessagePort
}

pub fn StructuredObject.create(kind StructuredObjectKind) &StructuredObject {
	return &StructuredObject{
		kind: kind
	}
}

pub fn StructuredObject.create_dom_exception(exception &webidl.DOMException) &StructuredObject {
	return &StructuredObject{kind: .serializable_object, serializable_interface_: .dom_exception, dom_exception_: exception}
}

pub fn StructuredObject.create_quota_exceeded_error(exception &webidl.QuotaExceededError) &StructuredObject {
	return &StructuredObject{kind: .serializable_object, serializable_interface_: .quota_exceeded_error, quota_exceeded_error_: exception}
}

pub fn StructuredObject.create_crypto_key(key &webcrypto.CryptoKey) &StructuredObject {
	return &StructuredObject{ kind: .serializable_object, serializable_interface_: .crypto_key, crypto_key_: key }
}

pub fn StructuredObject.create_webassembly_module(compiled &webassembly.Module) &StructuredObject {
	return &StructuredObject{kind: .serializable_object, serializable_interface_: .module, webassembly_module_: compiled}
}

pub fn StructuredObject.create_blob(blob &fileapi.Blob) &StructuredObject {
	return &StructuredObject{kind: .serializable_object, serializable_interface_: .blob, blob_: blob}
}

pub fn StructuredObject.create_file(file &fileapi.File) &StructuredObject {
	return &StructuredObject{kind: .serializable_object, serializable_interface_: .file, file_: file}
}

pub fn StructuredObject.create_file_list(list &fileapi.FileList) &StructuredObject {
	return &StructuredObject{kind: .serializable_object, serializable_interface_: .file_list, file_list_: list}
}

pub fn StructuredObject.create_shared_array_buffer(bytes []u8, max_byte_length ?u64) &StructuredObject {
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
		'InternalError' { .internal_error }
		'RangeError' { .range_error }
		'ReferenceError' { .reference_error }
		'SyntaxError' { .syntax_error }
		'TypeError' { .type_error }
		'URIError' { .uri_error }
		else { .error }
	}
}

fn structured_error_type_name(error_type StructuredErrorType) string {
	return match error_type {
		.error { 'Error' }
		.eval_error { 'EvalError' }
		.internal_error { 'InternalError' }
		.range_error { 'RangeError' }
		.reference_error { 'ReferenceError' }
		.syntax_error { 'SyntaxError' }
		.type_error { 'TypeError' }
		.uri_error { 'URIError' }
	}
}

struct StructuredSerializer {
mut:
	data                 []u8
	memory               map[u64]u32
	shared_array_buffers []&StructuredObject
	type_                SerializationType
}

fn (mut serializer StructuredSerializer) write_u8(value u8) {
	serializer.data << value
}

fn (mut serializer StructuredSerializer) write_serializable_interface(value StructuredSerializableInterface) ! {
	if serializer.type_ == .storage {
		serializer.write_string(structured_serializable_interface_name(value))!
	} else {
		serializer.write_u8(u8(u16(value)))
		serializer.write_u8(u8(u16(value) >> 8))
	}
}

fn (mut serializer StructuredSerializer) write_u32(value u32) {
	if serializer.type_ == .storage {
		serializer.write_unsigned_leb128(u64(value))
		return
	}
	serializer.data << u8(value)
	serializer.data << u8(value >> 8)
	serializer.data << u8(value >> 16)
	serializer.data << u8(value >> 24)
}

fn (mut serializer StructuredSerializer) write_u64(value u64) {
	if serializer.type_ == .storage {
		serializer.write_unsigned_leb128(value)
		return
	}
	serializer.write_fixed_u64(value)
}

fn (mut serializer StructuredSerializer) write_fixed_u64(value u64) {
	for shift in 0 .. 8 {
		serializer.data << u8(value >> (shift * 8))
	}
}

fn (mut serializer StructuredSerializer) write_f64(value f64) {
	serializer.write_fixed_u64(math.f64_bits(value))
}

fn (mut serializer StructuredSerializer) write_optional_f64(value ?f64) {
	serializer.write_u8(if value != none { u8(1) } else { u8(0) })
	if number := value { serializer.write_f64(number) }
}

fn (mut serializer StructuredSerializer) write_bytes(value []u8) ! {
	if u64(value.len) > u64(4294967295) {
		return error('DataCloneError: byte sequence is too large')
	}
	if serializer.type_ == .storage {
		serializer.write_u64(u64(value.len))
	} else {
		serializer.write_u32(u32(value.len))
	}
	serializer.data << value
}

fn (mut serializer StructuredSerializer) write_string(value string) ! {
	serializer.write_utf16_string(libjs.utf16_string(value))!
}

fn (mut serializer StructuredSerializer) write_utf16_string(value libjs.Utf16String) ! {
	// LibIPC/Encoder.cpp::encode(Utf16View): ASCII storage, u32 code-unit
	// count, then ASCII bytes or raw host-endian UTF-16 (pinned little endian).
	units := value.code_units()
	ascii := value.has_ascii_storage()
	if serializer.type_ == .storage {
		serializer.write_u64((u64(units.len) << 1) | if ascii { u64(1) } else { u64(0) })
	} else {
		serializer.write_u8(if ascii { u8(1) } else { u8(0) })
		serializer.write_u32(u32(units.len))
	}
	for unit in units {
		serializer.write_u8(u8(unit))
		if !ascii { serializer.write_u8(u8(unit >> 8)) }
	}
}

fn (mut serializer StructuredSerializer) write_bigint(integer &libjs.BigInt) ! {
	// StructuredSerialize.cpp::encode_signed_big_integer delegates to
	// Crypto::SignedBigInteger::export_data:
	// one sign byte followed by the big-endian unsigned magnitude.
	magnitude, _ := integer.big_integer.bytes()
	mut bytes := []u8{cap: magnitude.len + 1}
	bytes << if integer.big_integer.signum < 0 { u8(1) } else { u8(0) }
	bytes << magnitude
	serializer.write_bytes(bytes)!
}

fn (mut serializer StructuredSerializer) write_tag(tag StructuredSerializeValueTag) {
	serializer.write_u8(u8(tag))
}

fn (mut serializer StructuredSerializer) write_byte_length(value ?u32) {
	// JS::ByteLength's source boolean means is_auto, not optional presence.
	if actual := value {
		serializer.write_u8(0)
		serializer.write_u32(actual)
	} else {
		serializer.write_u8(1)
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
			if max_byte_length < u64(store.bytes.len) {
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
			serializer.write_u64(max_byte_length)
		}
		return
	}
	// StructuredSerialize.cpp: serialize_array_buffer, steps 2.5–2.6.
	// Presence of [[ArrayBufferMaxByteLength]] distinguishes a resizable buffer,
	// including an empty buffer whose maximum is zero.
	if max_byte_length := array_buffer.max_byte_length {
		if max_byte_length < u64(array_buffer.bytes.len) {
			return error('DataCloneError: ArrayBuffer maximum length is smaller than its byte length')
		}
		serializer.write_tag(.resizable_array_buffer)
		serializer.write_bytes(array_buffer.bytes)!
		serializer.write_u64(max_byte_length)
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
	validate_array_buffer_view(view, buffer)!
	serializer.write_tag(.array_buffer_view)
	serializer.serialize_value(structured_object_value(buffer), for_storage, allow_shared_array_buffers)!
	serializer.write_string(view.string_data)!
	serializer.write_byte_length(view.byte_length)
	serializer.write_u32(view.byte_offset)
	if view.string_data != 'DataView' {
		serializer.write_byte_length(view.array_length)
	}
}

fn structured_typed_array_element_size(constructor_name string) !u64 {
	// JS_ENUMERATE_TYPED_ARRAYS in the pinned LibJS Forward.h.
	return match constructor_name {
		'Uint8Array', 'Uint8ClampedArray', 'Int8Array' { u64(1) }
		'Uint16Array', 'Int16Array', 'Float16Array' { u64(2) }
		'Uint32Array', 'Int32Array', 'Float32Array' { u64(4) }
		'BigUint64Array', 'BigInt64Array', 'Float64Array' { u64(8) }
		else { return error('DataCloneError: Unknown ArrayBufferView constructor') }
	}
}

fn structured_view_length_fits_buffer(length ?u32, element_size u64, byte_offset u32, buffer &StructuredObject) bool {
	buffer_length := u64(buffer.array_buffer_bytes().len)
	if actual := length {
		// Source validates u32 slots in u64, before the engine element check.
		return u64(actual) * element_size + u64(byte_offset) <= buffer_length
	}
	return buffer.max_byte_length != none && u64(byte_offset) <= buffer_length
}

fn validate_array_buffer_view(view &StructuredObject, buffer &StructuredObject) ! {
	// StructuredSerialize.cpp's decoder rejects slot combinations that no
	// actual source view can produce. The DTO applies that same source gate.
	if view.string_data == 'DataView' {
		if !structured_view_length_fits_buffer(view.byte_length, 1, view.byte_offset, buffer) {
			return error('DataCloneError: DataView does not fit its ArrayBuffer')
		}
		return
	}
	element_size := structured_typed_array_element_size(view.string_data)!
	mut consistent := (view.byte_length == none) == (view.array_length == none)
		&& u64(view.byte_offset) % element_size == 0
	if consistent {
		if array_length := view.array_length {
			byte_length := view.byte_length or { return error('DataCloneError: inconsistent view lengths') }
			consistent = u64(byte_length) == u64(array_length) * element_size
		}
	}
	if !consistent || !structured_view_length_fits_buffer(view.array_length, element_size, view.byte_offset, buffer) {
		return error('DataCloneError: ArrayBufferView does not fit its ArrayBuffer')
	}
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
				serializer.write_i32(i32(value.number_data))
			} else {
				serializer.write_tag(.number_primitive)
				serializer.write_f64(value.number_data)
			}
			return
		}
		.string {
			serializer.write_tag(.string_primitive)
			serializer.write_utf16_string(value.string_utf16_ or { libjs.utf16_string(value.string_data) })!
			return
		}
		.object {}
		.runtime_value {
			native := value.native_value_ or { return error('DataCloneError: missing source primitive value') }
			if native.kind != .bigint {
				return error('DataCloneError: actual host JavaScript values require their engine structured-clone binding')
			}
			serializer.write_tag(.big_int_primitive)
			serializer.write_bigint(webidl.value_to_bigint(native)!)!
			return
		}
	}

	object := structured_object_from_value(value)!
	identity := u64(voidptr(object))
	if id := serializer.memory[identity] {
		serializer.write_tag(.object_reference)
		serializer.write_u32(id)
		return
	}
	// Source registration follows non-deep serialization. A view's nested
	// buffer may claim an earlier id before the view itself is registered.
	if object.kind != .array_buffer_view {
		serializer.memory[identity] = u32(serializer.memory.len)
	}

	match object.kind {
		.message_port { return error('DataCloneError: MessagePort must be transferred') }
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
			serializer.write_utf16_string(object.string_utf16_ or { libjs.utf16_string(object.string_data) })!
		}
		.big_int_object {
			serializer.write_tag(.big_int_object)
			integer := object.bigint_data or {
				libjs.string_to_bigint(libjs.utf16_string(object.string_data)) or { return error('DataCloneError: BigInt object has invalid internal value') }
			}
			serializer.write_bigint(integer)!
		}
		.date {
			serializer.write_tag(.date_object)
			serializer.write_f64(object.number_data)
		}
		.regexp {
			serializer.write_tag(.regexp_object)
			serializer.write_utf16_string(object.string_utf16_ or { libjs.utf16_string(object.string_data) })!
			serializer.write_utf16_string(object.second_string_utf16_ or { libjs.utf16_string(object.second_string_data) })!
		}
		.map {
			serializer.write_tag(.map_object)
			serializer.write_u64(u64(object.entries.len))
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
			serializer.write_u64(u64(object.values.len))
			for item in object.values {
				if item == unsafe { nil } {
					return error('DataCloneError: set contains a missing value')
				}
				serializer.serialize_value(*item, for_storage, allow_shared_array_buffers)!
			}
		}
		.array {
			serializer.write_tag(.array_object)
			serializer.write_u64(u64(object.array_length or { u32(object.values.len) }))
			// The legacy dense prefix is projected into the source ordered
			// enumerable property list; sparse/named properties stay explicit.
			for index, item in object.values {
				if item == unsafe { nil } { continue }
				serializer.serialize_value(*item, for_storage, allow_shared_array_buffers)!
				serializer.write_string(index.str())!
			}
			serialize_object_properties(mut serializer, object.properties, for_storage, allow_shared_array_buffers)!
		}
		.error_object {
			serializer.write_tag(.error_object)
			// InternalError is native to LibJS, but is not a structured-clone Error name.
			error_type := if object.error_type == .internal_error { StructuredErrorType.error } else { object.error_type }
			if serializer.type_ == .storage {
				serializer.write_string(structured_error_type_name(error_type))!
			} else {
				serializer.write_u8(u8(error_type))
			}
			// Source message/cause are optional UTF16 descriptor values, not
			// a mandatory message or a recursively cloned cause object.
			// Nonempty compatibility text projects a present message.
			has_message := object.has_message || object.string_utf16_ != none || object.string_data.len != 0
			serializer.write_u8(if has_message { u8(1) } else { u8(0) })
			if has_message {
				serializer.write_utf16_string(object.string_utf16_ or { libjs.utf16_string(object.string_data) })!
			}
			has_cause := object.has_cause || object.cause_utf16_ != none
			serializer.write_u8(if has_cause { u8(1) } else { u8(0) })
			if has_cause {
				serializer.write_utf16_string(object.cause_utf16_ or { libjs.utf16_string(object.cause) })!
			}
		}
		.object {
			serializer.write_tag(.object)
			serialize_object_properties(mut serializer, object.properties, for_storage, allow_shared_array_buffers)!
		}
		.array_buffer {
			serialize_array_buffer(mut serializer, object, for_storage, allow_shared_array_buffers)!
		}
		.array_buffer_view {
			serialize_viewed_array_buffer(mut serializer, object, for_storage, allow_shared_array_buffers)!
			serializer.memory[identity] = u32(serializer.memory.len)
		}
		.shared_array_buffer {
			serialize_array_buffer(mut serializer, object, for_storage, allow_shared_array_buffers)!
		}
		.serializable_object {
			interface_name := object.serializable_interface_ or { return error('DataCloneError: serializable object has no primary interface') }
			if interface_name !in [.dom_exception, .quota_exceeded_error, .crypto_key, .blob, .file, .file_list, .module] { return error('DataCloneError: source serializable payload is not yet translated for ${structured_serializable_interface_name(interface_name)}') }
			serializer.write_tag(.serializable_object)
			serializer.write_serializable_interface(interface_name)!
			if serializer.type_ == .storage { serializer.write_u64(structured_serializable_payload_version) }
			if interface_name in [.blob, .file, .file_list] {
				serializer.write_fileapi_payload(object)!
			} else if interface_name == .crypto_key {
				key := object.crypto_key_ or { return error('DataCloneError: serializable CryptoKey has no native record') }
				serializer.write_crypto_key_payload(key)!
			} else if interface_name == .module {
				// Module::serialization_steps rejects storage and copies the
				// original source bytes, retaining structured-clone identity.
				compiled := object.webassembly_module_ or { return error('DataCloneError: serializable WebAssembly Module has no native record') }
				serialized := compiled.serialization_steps(for_storage)!
				serializer.write_bytes(serialized.bytes)!
			} else if interface_name == .dom_exception {
				exception := object.dom_exception_ or { return error('DataCloneError: serializable DOMException has no native record') }
				for field in exception.serialization_steps_utf16() { serializer.write_utf16_string(field)! }
			} else {
				exception := object.quota_exceeded_error_ or { return error('DataCloneError: serializable QuotaExceededError has no native record') }
				fields := exception.serialization_steps_utf16()
				serializer.write_utf16_string(fields.name)!
				serializer.write_utf16_string(fields.message)!
				serializer.write_optional_f64(fields.quota)
				serializer.write_optional_f64(fields.requested)
			}
		}
	}
}

fn serialize_object_properties(mut serializer StructuredSerializer, properties []StructuredProperty, for_storage bool, allow_shared_array_buffers AllowSharedArrayBuffers) ! {
	// StructuredSerialize.cpp: serialize each value before its UTF-16 key,
	// then EndObject. Property order is the source enumerable-own-key list.
	for property in properties {
		if property.value == unsafe { nil } { return error('DataCloneError: object contains a missing property value') }
		serializer.serialize_value(*property.value, for_storage, allow_shared_array_buffers)!
		serializer.write_utf16_string(property.key_utf16_ or { libjs.utf16_string(property.key) })!
	}
	serializer.write_tag(.end_object)
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
	// StorageStructuredSerializeDataEncoder's pinned LBSC envelope.
	mut serializer := StructuredSerializer{type_: .storage, data: [u8(76), 66, 83, 67, 1, 0]}
	serializer.serialize_value(value, true, allow_shared_array_buffers)!
	return SerializationRecord{
		data: serializer.data
		type_: .storage
	}
}

pub struct StructuredDeserializationContext {
pub:
	// Actual target realm's source is_exposed boundary. Standalone convenience
	// decoders have no browser realm and do not invent platform exposure.
	is_exposed ?fn (StructuredSerializableInterface) bool
}

struct StructuredDecoder {
	data                 []u8
	shared_array_buffers []&StructuredObject
	type_                SerializationType
	context              StructuredDeserializationContext
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

fn (mut decoder StructuredDecoder) read_serializable_interface() !StructuredSerializableInterface {
	if decoder.type_ == .storage { return structured_serializable_interface_from_name(decoder.read_string()!) }
	low := decoder.read_u8()!
	high := decoder.read_u8()!
	return structured_serializable_interface_from_u16(u16(low) | (u16(high) << 8))
}

fn (mut decoder StructuredDecoder) read_u32() !u32 {
	if decoder.type_ == .storage { return u32(decoder.read_unsigned_leb128(32)!) }
	if decoder.offset + 4 > decoder.data.len {
		return error('DataCloneError: truncated serialization record')
	}
	value := u32(decoder.data[decoder.offset]) | (u32(decoder.data[decoder.offset + 1]) << 8) | (u32(decoder.data[decoder.offset + 2]) << 16) | (u32(decoder.data[decoder.offset + 3]) << 24)
	decoder.offset += 4
	return value
}

fn (mut decoder StructuredDecoder) read_u64() !u64 {
	if decoder.type_ == .storage { return decoder.read_unsigned_leb128(64) }
	return decoder.read_fixed_u64()
}

fn (mut decoder StructuredDecoder) read_fixed_u64() !u64 {
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
	return math.f64_from_bits(decoder.read_fixed_u64()!)
}

struct DecodedOptionalF64 {
	value ?f64
}

fn (mut decoder StructuredDecoder) read_optional_f64() !DecodedOptionalF64 {
	present := decoder.read_u8()!
	// Source storage bool decoding explicitly rejects noncanonical bytes.
	// IPC source records write native bool bytes 0/1. This adapter makes no
	// portable source-parity claim for noncanonical raw IPC bool storage.
	if decoder.type_ == .storage && present > 1 { return error('DataCloneError: Invalid structured serialize bool') }
	if present == 0 { return DecodedOptionalF64{} }
	return DecodedOptionalF64{value: decoder.read_f64()!}
}

fn (mut decoder StructuredDecoder) read_bytes() ![]u8 {
	raw_length := if decoder.type_ == .storage { decoder.read_u64()! } else { u64(decoder.read_u32()!) }
	if raw_length > u64(decoder.data.len - decoder.offset) {
		return error('DataCloneError: truncated serialization record')
	}
	length := int(raw_length)
	value := decoder.data[decoder.offset..decoder.offset + length].clone()
	decoder.offset += length
	return value
}

fn (mut decoder StructuredDecoder) read_string() !string {
	return decoder.read_utf16_string()!.str()
}

fn (mut decoder StructuredDecoder) read_utf16_string() !libjs.Utf16String {
	mut flag := u8(0)
	mut count := u64(0)
	if decoder.type_ == .storage {
		header := decoder.read_u64()!
		flag = u8(header & 1)
		count = header >> 1
	} else {
		flag = decoder.read_u8()!
		if flag > 1 { return error('DataCloneError: invalid UTF-16 storage flag') }
		count = u64(decoder.read_u32()!)
	}
	unit_bytes := if flag == 1 { u64(1) } else { u64(2) }
	if count > u64(decoder.data.len - decoder.offset) / unit_bytes { return error('DataCloneError: truncated UTF-16 string') }
	mut units := []u16{cap: int(count)}
	for _ in 0 .. int(count) {
		mut unit := u16(decoder.read_u8()!)
		if flag == 0 { unit |= u16(decoder.read_u8()!) << 8 }
		if flag == 1 && unit >= 128 { return error('DataCloneError: invalid ASCII string storage') }
		units << unit
	}
	if decoder.type_ == .storage {
		// Unlike from_ipc_stream, source Storage decode constructs from_utf16.
		return libjs.utf16_string_from_code_units(units)
	}
	return libjs.utf16_string_from_code_units_with_storage(units, flag == 1) or {
		return error('DataCloneError: invalid ASCII string storage')
	}
}

fn (mut decoder StructuredDecoder) read_bigint() !&libjs.BigInt {
	bytes := decoder.read_bytes()!
	if bytes.len == 0 { return error('DataCloneError: invalid BigInt encoding') }
	return libjs.BigInt.create(big.integer_from_bytes(bytes[1..], big.IntegerConfig{signum: if bytes[0] == 0 { 1 } else { -1 }}))
}

struct DecodedOptionalU32 {
	value ?u32
}

fn (mut decoder StructuredDecoder) read_byte_length() !DecodedOptionalU32 {
	is_auto := decoder.read_u8()!
	if is_auto > 1 {
		return error('DataCloneError: invalid byte-length auto encoding')
	}
	if is_auto == 1 {
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
	return decoder.decode_value_with_tag(decoder.read_u8()!)
}

fn (mut decoder StructuredDecoder) decode_value_with_tag(tag_byte u8) !&dom.JSValue {
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
			return &dom.JSValue{kind: .number, number_data: f64(decoder.read_i32()!)}
		}
		.string_primitive {
			value := dom.js_utf16_string(decoder.read_utf16_string()!)
			return &value
		}
		.big_int_primitive {
			value := dom.js_webidl_value(webidl.bigint_value_for_record(decoder.read_bigint()!))
			return &value
		}
		.object_reference {
			raw_index := decoder.read_u32()!
			if raw_index == u32(-1) {
				object := &StructuredObject{kind: .object, null_prototype: true}
				value := structured_object_value(object)
				return &value
			}
			index := int(raw_index)
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
		.string_object {
			mut object := StructuredObject.create(.string_object)
			value := decoder.register_object(object)
			text := decoder.read_utf16_string()!
			object.string_data = text.str()
			object.string_utf16_ = text
			return value
		}
		.big_int_object {
			mut object := StructuredObject.create(.big_int_object)
			value := decoder.register_object(object)
			integer := decoder.read_bigint()!
			object.bigint_data = integer
			object.string_data = integer.big_integer.str()
			return value
		}
		.regexp_object {
			mut object := StructuredObject.create(.regexp)
			value := decoder.register_object(object)
			pattern := decoder.read_utf16_string()!
			flags := decoder.read_utf16_string()!
			object.string_data = pattern.str()
			object.string_utf16_ = pattern
			object.second_string_data = flags.str()
			object.second_string_utf16_ = flags
			return value
		}
		.map_object {
			mut object := StructuredObject.create(.map)
			value := decoder.register_object(object)
			length := decoder.read_collection_count(2)!
			for _ in 0 .. length {
				object.entries << StructuredMapEntry{
					key: decoder.decode_value()!
					value: decoder.decode_value()!
				}
			}
			return value
		}
		.set_object {
			mut object := StructuredObject.create(.set)
			value := decoder.register_object(object)
			length := decoder.read_collection_count(1)!
			for _ in 0 .. length {
				object.values << decoder.decode_value()!
			}
			return value
		}
		.array_object {
			length := decoder.read_u64()!
			if length > u64(4294967295) { return error('DataCloneError: Array length out of range') }
			mut object := StructuredObject.create(.array)
			object.array_length = u32(length)
			value := decoder.register_object(object)
			decode_object_properties(mut decoder, mut object)!
			return value
		}
		.error_object {
			mut object := StructuredObject.create(.error_object)
			value := decoder.register_object(object)
			if decoder.type_ == .storage {
				object.error_type = error_name_to_type(decoder.read_string()!)
			} else {
				error_type := decoder.read_u8()!
				if error_type > u8(StructuredErrorType.uri_error) {
					return error('DataCloneError: invalid Error type')
				}
				object.error_type = unsafe { StructuredErrorType(error_type) }
			}
			has_message := decoder.read_u8()!
			if has_message > 1 { return error('DataCloneError: invalid Error message encoding') }
			object.has_message = has_message == 1
			if object.has_message {
				message := decoder.read_utf16_string()!
				object.string_data = message.str()
				object.string_utf16_ = message
			}
			has_cause := decoder.read_u8()!
			if has_cause > 1 {
				return error('DataCloneError: invalid Error cause encoding')
			}
			object.has_cause = has_cause == 1
			if object.has_cause {
				cause := decoder.read_utf16_string()!
				object.cause = cause.str()
				object.cause_utf16_ = cause
			}
			return value
		}
		.object {
			mut object := StructuredObject.create(.object)
			value := decoder.register_object(object)
			decode_object_properties(mut decoder, mut object)!
			return value
		}
		.array_buffer, .resizable_array_buffer {
			mut object := StructuredObject.create(.array_buffer)
			value := decoder.register_object(object)
			object.bytes = decoder.read_bytes()!
			if tag == .resizable_array_buffer {
				max_byte_length := decoder.read_u64()!
				if max_byte_length < u64(object.bytes.len) {
					return error('DataCloneError: ArrayBuffer maximum length is smaller than its byte length')
				}
				object.max_byte_length = max_byte_length
			}
			return value
		}
		.shared_array_buffer, .growable_shared_array_buffer {
			side_table_index := int(decoder.read_u32()!)
			bytes := decoder.read_bytes()!
			mut max_byte_length := ?u64(none)
			if tag == .growable_shared_array_buffer {
				actual_max_byte_length := decoder.read_u64()!
				if actual_max_byte_length < u64(bytes.len) {
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
			buffer_value := decoder.decode_value()!
			buffer := structured_object_from_value(*buffer_value)!
			if buffer.kind != .array_buffer && buffer.kind != .shared_array_buffer {
				return error('DataCloneError: ArrayBuffer view references a non-buffer')
			}
			object.viewed_array_buffer = buffer
			object.string_data = decoder.read_string()!
			object.byte_length = decoder.read_byte_length()!.value
			object.byte_offset = decoder.read_u32()!
			if object.string_data != 'DataView' {
				object.array_length = decoder.read_byte_length()!.value
			}
			validate_array_buffer_view(object, buffer)!
			return decoder.register_object(object)
		}
		.serializable_object {
			interface_name := decoder.read_serializable_interface()!
			mut version := ?u64(none)
			if decoder.type_ == .storage { version = decoder.read_u64()! }
			is_exposed := decoder.context.is_exposed or { return error('DataCloneError: unsupported type in target realm') }
			if !is_exposed(interface_name) { return error('DataCloneError: unsupported type in target realm') }
			if interface_name !in [.dom_exception, .quota_exceeded_error, .crypto_key, .blob, .file, .file_list, .module] { return error('DataCloneError: source serializable payload is not yet translated for ${structured_serializable_interface_name(interface_name)}') }
			mut object := if interface_name == .blob {
				StructuredObject.create_blob(fileapi.Blob.create([], ''))
			} else if interface_name == .file {
				StructuredObject.create_file(fileapi.File.create([], '', '', 0))
			} else if interface_name == .file_list {
				StructuredObject.create_file_list(fileapi.FileList.create())
			} else if interface_name == .crypto_key {
				StructuredObject.create_crypto_key(webcrypto.CryptoKey.create_empty())
			} else if interface_name == .module {
				StructuredObject.create_webassembly_module(webassembly.Module.create_for_serialization())
			} else if interface_name == .dom_exception {
				StructuredObject.create_dom_exception(webidl.DOMException.create_utf16_record(libjs.utf16_string(''), libjs.utf16_string('')))
			} else {
				StructuredObject.create_quota_exceeded_error(&webidl.QuotaExceededError{})
			}
			if payload_version := version {
				if payload_version != structured_serializable_payload_version { return error('DataCloneError: unsupported serializable payload version') }
			}
			value := decoder.register_object(object)
			// Source creates/registers the target before its interface payload.
			if interface_name in [.blob, .file, .file_list] {
				decoder.read_fileapi_payload(mut object)!
				return value
			}
			if interface_name == .crypto_key {
				mut key := object.crypto_key_ or { return error('DataCloneError: missing CryptoKey target record') }
				decoder.read_crypto_key_payload(mut key)!
				return value
			}
			if interface_name == .module {
				// Register the target before decoding its payload, then compile
				// the retained bytes through the existing Wasm policy boundary.
				mut compiled := object.webassembly_module_ or { return error('DataCloneError: missing WebAssembly Module target record') }
				bytes := decoder.read_bytes()!
				compiled.deserialization_steps(webassembly.SerializedModule{bytes: bytes})!
				return value
			}
			name := decoder.read_utf16_string()!
			message := decoder.read_utf16_string()!
			if interface_name == .dom_exception {
				mut exception := object.dom_exception_ or { return error('DataCloneError: missing DOMException target record') }
				exception.deserialization_steps_utf16([name, message])!
			} else {
				quota := decoder.read_optional_f64()!.value
				requested := decoder.read_optional_f64()!.value
				mut exception := object.quota_exceeded_error_ or { return error('DataCloneError: missing QuotaExceededError target record') }
				exception.deserialization_steps_utf16(webidl.SerializedQuotaExceededErrorUTF16{name: name, message: message, quota: quota, requested: requested})
			}
			return value
		}
		.empty, .end_object {
			return error('DataCloneError: unsupported structured serialization tag')
		}
	}
}

fn (mut decoder StructuredDecoder) read_collection_count(minimum_value_bytes u64) !int {
	count := decoder.read_u64()!
	// Every serialized value has at least one tag. Bound the V vector/loop by
	// actual available record bytes before converting the source u64 count.
	if count > u64(decoder.data.len - decoder.offset) / minimum_value_bytes {
		return error('DataCloneError: truncated collection serialization record')
	}
	return int(count)
}

fn decode_object_properties(mut decoder StructuredDecoder, mut object StructuredObject) ! {
	for {
		tag := decoder.read_u8()!
		if tag == u8(StructuredSerializeValueTag.end_object) { return }
		value := decoder.decode_value_with_tag(tag)!
		key := decoder.read_utf16_string()!
		text := key.str()
		if object.kind == .array && text == object.values.len.str() && object.properties.len == 0 {
			object.values << value
		} else {
			object.properties << StructuredProperty{key: text, key_utf16_: key, value: value}
		}
	}
}

pub fn structured_deserialize(record SerializationRecord) !dom.JSValue {
	// Retain the standalone translation's fully-consumed convenience API.
	return structured_deserialize_record(record, true, StructuredDeserializationContext{})
}

pub fn structured_deserialize_with_context(record SerializationRecord, context StructuredDeserializationContext) !dom.JSValue {
	return structured_deserialize_record(record, true, context)
}

// Source IPC structured_deserialize has no full-consumption check; Storage
// always requires one. Keep it separate from the older strict convenience API.
pub fn structured_deserialize_ipc(record SerializationRecord) !dom.JSValue {
	if record.type_ != .ipc { return error('DataCloneError: expected IPC serialization record') }
	return structured_deserialize_record(record, false, StructuredDeserializationContext{})
}

pub fn structured_deserialize_ipc_with_context(record SerializationRecord, context StructuredDeserializationContext) !dom.JSValue {
	if record.type_ != .ipc { return error('DataCloneError: expected IPC serialization record') }
	return structured_deserialize_record(record, false, context)
}

fn structured_deserialize_record(record SerializationRecord, fully_consumed bool, context StructuredDeserializationContext) !dom.JSValue {
	if record.data.len == 0 {
		return error('DataCloneError: empty serialization record')
	}
	mut decoder := StructuredDecoder{
		data: record.data
		shared_array_buffers: record.shared_array_buffers
		type_: record.type_
		context: context
	}
	if record.type_ == .storage {
		for byte in [u8(76), 66, 83, 67] {
			if decoder.read_u8()! != byte { return error('DataCloneError: Invalid structured serialize storage magic') }
		}
		if decoder.read_u64()! != 1 { return error('DataCloneError: Unsupported structured serialize storage version') }
		if decoder.read_u64()! != 0 { return error('DataCloneError: Unsupported structured serialize storage flags') }
	}
	value := decoder.decode_value()!
	if (fully_consumed || record.type_ == .storage) && decoder.offset != decoder.data.len {
		return error('DataCloneError: trailing structured serialization data')
	}
	return *value
}

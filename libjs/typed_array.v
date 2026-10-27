module libjs

// Runtime/TypedArray.{h,cpp}: concrete template records use BufferElementType
// dispatch. Factories take an explicit prototype until the TypedArray intrinsic
// graph is installed. Cached caged views remain pending.
pub enum TypedArrayContentType {
	number
	bigint
}

@[heap]
pub struct TypedArray {
pub:
	object &Object
	kind   BufferElementType
pub mut:
	viewed_buffer &ArrayBufferObject
	array_length  ByteLength
	byte_length   ByteLength
	byte_offset   u32
}

pub fn (kind BufferElementType) typed_array_name() string {
	return match kind {
		.big_int64 { 'BigInt64Array' }
		.big_uint64 { 'BigUint64Array' }
		.float16 { 'Float16Array' }
		.float32 { 'Float32Array' }
		.float64 { 'Float64Array' }
		.int8 { 'Int8Array' }
		.int16 { 'Int16Array' }
		.int32 { 'Int32Array' }
		.uint8 { 'Uint8Array' }
		.uint16 { 'Uint16Array' }
		.uint32 { 'Uint32Array' }
		.uint8_clamped { 'Uint8ClampedArray' }
	}
}

pub fn TypedArray.create(realm &Realm, kind BufferElementType, length u32, buffer &ArrayBufferObject, prototype &Object) &TypedArray {
	assert length <= u32(0xffffffff) / u32(kind.size())
	assert length == 0 || (!buffer.is_detached() && buffer.byte_length() > 0)
	mut object := Object.create(realm, prototype)
	object.class_name = kind.typed_array_name()
	array := &TypedArray{
		object:        object
		kind:          kind
		viewed_buffer: buffer
		array_length:  ByteLength.from_u32(length)
		// The source constructor uses the whole buffer length here, even
		// for zero requested elements; view initialization replaces it.
		byte_length: ByteLength.from_u32(u32(buffer.byte_length()))
	}
	object.typed_array = array
	return array
}

pub fn (array &TypedArray) element_size() u32 {
	return u32(array.kind.size())
}

pub fn (array &TypedArray) content_type() TypedArrayContentType {
	return if array.kind.is_bigint() { .bigint } else { .number }
}

pub fn (array &TypedArray) is_bigint_element_type() bool {
	return array.kind.is_bigint()
}

pub fn (array &TypedArray) is_unclamped_integer_element_type() bool {
	return array.kind in [.int8, .int16, .int32, .uint8, .uint16, .uint32]
}

pub fn (array &TypedArray) get_value_from_buffer(mut vm VM, byte_index uint, order BufferOrder, little_endian bool) Value {
	return array.viewed_buffer.get_value(mut vm, byte_index, array.kind, true, order, little_endian)
}

pub fn (mut array TypedArray) set_value_in_buffer(mut vm VM, byte_index uint, value Value, order BufferOrder, little_endian bool) {
	mut buffer := array.viewed_buffer
	buffer.set_value(mut vm, byte_index, array.kind, value, true, order, little_endian)
}

pub fn (mut array TypedArray) get_modify_set_value_in_buffer(mut vm VM, byte_index uint, value Value, operation ReadWriteModifyFunction, little_endian bool) Value {
	mut buffer := array.viewed_buffer
	return buffer.get_modify_set_value(mut vm, byte_index, array.kind, value, operation,
		little_endian)
}

pub struct TypedArrayWithBufferWitness {
pub:
	object                    &TypedArray
	cached_buffer_byte_length ByteLength
}

pub fn make_typed_array_with_buffer_witness_record(array &TypedArray, order BufferOrder) TypedArrayWithBufferWitness {
	length := if array.viewed_buffer.is_detached() {
		ByteLength.detached()
	} else {
		ByteLength.from_u32(u32(array_buffer_byte_length(array.viewed_buffer, order)))
	}
	return TypedArrayWithBufferWitness{
		object:                    array
		cached_buffer_byte_length: length
	}
}

pub fn typed_array_byte_length(record TypedArrayWithBufferWitness) u32 {
	if is_typed_array_out_of_bounds(record) { return 0 }
	length := typed_array_length(record)
	if length == 0 { return 0 }
	if !record.object.byte_length.is_auto() { return record.object.byte_length.length() }
	return length * record.object.element_size()
}

pub fn typed_array_length(record TypedArrayWithBufferWitness) u32 {
	assert !is_typed_array_out_of_bounds(record)
	array := record.object
	if !array.array_length.is_auto() { return array.array_length.length() }
	assert !array.viewed_buffer.is_fixed_length()
	assert !record.cached_buffer_byte_length.is_detached()
	return (record.cached_buffer_byte_length.length() - array.byte_offset) / array.element_size()
}

pub fn is_typed_array_out_of_bounds(record TypedArrayWithBufferWitness) bool {
	array := record.object
	length := record.cached_buffer_byte_length
	assert array.viewed_buffer.is_detached() == length.is_detached()
	if length.is_detached() { return true }
	end := if array.array_length.is_auto() {
		length.length()
	} else {
		array.byte_offset + array.array_length.length() * array.element_size()
	}
	return array.byte_offset > length.length() || end > length.length()
}

pub fn is_typed_array_fixed_length(array &TypedArray) bool {
	if array.array_length.is_auto() { return false }
	buffer := array.viewed_buffer
	return buffer.is_fixed_length() || buffer.is_shared_array_buffer()
}

pub fn is_valid_integer_index(array &TypedArray, index CanonicalIndex) bool {
	if array.viewed_buffer.is_detached() || !index.is_index() { return false }
	if !array.array_length.is_auto() {
		length := array_buffer_byte_length(array.viewed_buffer, .unordered)
		end := array.byte_offset + array.array_length.length() * array.element_size()
		return uint(array.byte_offset) <= length && uint(end) <= length
			&& index.as_index() < array.array_length.length()
	}
	record := make_typed_array_with_buffer_witness_record(array, .unordered)
	if is_typed_array_out_of_bounds(record) { return false }
	return index.as_index() < typed_array_length(record)
}

// Retain the source's checked uint address arithmetic and overflow result.
fn (array &TypedArray) element_byte_index(index CanonicalIndex) ?uint {
	value := uint(index.as_index())
	maximum := ~uint(0)
	if value > maximum / uint(array.element_size()) { return none }
	product := value * uint(array.element_size())
	if product > maximum - uint(array.byte_offset) { return none }
	return product + uint(array.byte_offset)
}

pub fn typed_array_get_element(array &TypedArray, index CanonicalIndex) Value {
	if !is_valid_integer_index(array, index) { return js_undefined() }
	byte_index := array.element_byte_index(index) or { return js_undefined() }
	return array.viewed_buffer.read_numeric_value(byte_index, array.kind, true, .unordered, true)
}

pub fn typed_array_set_element(mut vm VM, mut array TypedArray, index CanonicalIndex, value Value) ! {
	assert !value.is_special_empty_value()
	numeric := if array.content_type() == .bigint {
		Value.from_bigint(value.to_bigint(mut vm)!)
	} else {
		value.to_number(mut vm)!
	}
	if !is_valid_integer_index(array, index) { return }
	byte_index := array.element_byte_index(index) or { return }
	array.set_value_in_buffer(mut vm, byte_index, numeric, .unordered, true)
}

pub fn validate_typed_array(mut vm VM, object &Object, order BufferOrder) !TypedArrayWithBufferWitness {
	array := object.typed_array or {
		return vm.throw_error_type(.type_error, .not_an_object_of_type, 'TypedArray')
	}
	record := make_typed_array_with_buffer_witness_record(array, order)
	if is_typed_array_out_of_bounds(record) {
		return vm.throw_error_type(.type_error, .buffer_out_of_bounds, 'TypedArray')
	}
	return record
}

fn typed_array_property_index(key PropertyName) ?CanonicalIndex {
	if key.is_symbol() { return none }
	index := canonical_numeric_index_string(key, .detect_numeric_roundtrip)
	if index.is_undefined() { return none }
	return index
}

fn (mut array TypedArray) internal_define_own_property(mut vm VM, key PropertyName, descriptor PropertyDescriptor) !bool {
	if index := typed_array_property_index(key) {
		if !is_valid_integer_index(array, index) { return false }
		if configurable := descriptor.configurable {
			if !configurable { return false }
		}
		if enumerable := descriptor.enumerable {
			if !enumerable { return false }
		}
		if descriptor.is_accessor_descriptor() { return false }
		if writable := descriptor.writable {
			if !writable { return false }
		}
		if value := descriptor.value { typed_array_set_element(mut vm, mut array, index, value)! }
		return true
	}
	mut object := array.object
	return object.ordinary_define_own_property(key, descriptor)
}

fn (array &TypedArray) own_property_keys() []PropertyName {
	record := make_typed_array_with_buffer_witness_record(array, .seq_cst)
	mut keys := []PropertyName{}
	if !is_typed_array_out_of_bounds(record) {
		for index in 0 .. typed_array_length(record) {
			keys << PropertyName.from_number(index)
		}
	}
	for property in array.object.properties {
		if property.key.is_string() { keys << property.key }
	}
	for property in array.object.properties {
		if property.key.is_symbol() && !property.key.as_symbol().is_private() {
			keys << property.key
		}
	}
	return keys
}

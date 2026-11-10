module libjs

// TypedArray.cpp::InitializeTypedArrayFromArrayBuffer. The caller supplies a
// concrete record; intrinsic installation is a separate dependency.
pub fn initialize_typed_array_from_array_buffer(mut vm VM, mut array TypedArray, buffer &ArrayBufferObject, byte_offset Value, length Value) ! {
	element_size := uint(array.element_size())
	offset := uint(byte_offset.to_index(mut vm)!)
	if offset % element_size != 0 {
		return vm.throw_error_type(.range_error, .typed_array_invalid_byte_offset,
			array.object.class_name, element_size.str(), offset.str())
	}
	buffer_is_fixed_length := buffer.is_fixed_length()
	new_length := if length.is_undefined() { uint(0) } else { uint(length.to_index(mut vm)!) }
	if buffer.is_detached() { return vm.throw_error_type(.type_error, .detached_array_buffer) }
	buffer_length := array_buffer_byte_length(buffer, .seq_cst)
	if length.is_undefined() && !buffer_is_fixed_length {
		if offset > buffer_length {
			return vm.throw_error_type(.range_error, .typed_array_out_of_range_byte_offset,
				offset.str(), buffer_length.str())
		}
		array.byte_length = ByteLength.auto_length()
		array.array_length = ByteLength.auto_length()
	} else {
		mut new_byte_length := uint(0)
		if length.is_undefined() {
			if buffer_length % element_size != 0 {
				return vm.throw_error_type(.range_error, .typed_array_invalid_buffer_length,
					array.object.class_name, element_size.str(), buffer_length.str())
			}
			if offset > buffer_length {
				return vm.throw_error_type(.range_error, .typed_array_out_of_range_byte_offset,
					offset.str(), buffer_length.str())
			}
			new_byte_length = buffer_length - offset
		} else {
			maximum := ~uint(0)
			if new_length > maximum / element_size {
				return vm.throw_error_type(.range_error, .invalid_length, 'typed array')
			}
			new_byte_length = new_length * element_size
			if offset > maximum - new_byte_length {
				return vm.throw_error_type(.range_error, .invalid_length, 'typed array')
			}
			end := offset + new_byte_length
			if end > buffer_length {
				return vm.throw_error_type(.range_error,
					.typed_array_out_of_range_byte_offset_or_length, offset.str(), end.str(),
					buffer_length.str())
			}
		}
		new_array_length := new_byte_length / element_size
		validate_typed_array_length(mut vm, new_array_length, element_size)!
		array.byte_length = ByteLength.from_u32(u32(new_byte_length))
		array.array_length = ByteLength.from_u32(u32(new_array_length))
	}
	array.viewed_buffer = buffer
	if offset > uint(0xffffffff) {
		return vm.throw_error_type(.range_error, .invalid_length, 'typed array')
	}
	array.byte_offset = u32(offset)
}

fn validate_typed_array_length(mut vm VM, length uint, element_size uint) ! {
	if length > uint(0x7fffffff) / element_size || length > (~uint(0)) / element_size {
		return vm.throw_error_type(.range_error, .invalid_length, 'typed array')
	}
}

// TypedArray.cpp::AllocateTypedArrayBuffer. Like the active source body this
// replaces the constructor's throwaway buffer without asserting its absence.
pub fn allocate_typed_array_buffer(mut vm VM, mut array TypedArray, length uint) ! {
	element_size := uint(array.element_size())
	validate_typed_array_length(mut vm, length, element_size)!
	byte_length := element_size * length
	buffer := allocate_array_buffer(mut vm, vm.realm().array_buffer_constructor_record(), byte_length, none)!
	array.viewed_buffer = buffer
	array.byte_length = ByteLength.from_u32(u32(byte_length))
	array.byte_offset = 0
	array.array_length = ByteLength.from_u32(u32(length))
}

// TypedArray.cpp::InitializeTypedArrayFromList. Values are already collected;
// element conversion and writes occur only after allocating the complete buffer.
pub fn initialize_typed_array_from_list(mut vm VM, mut array TypedArray, values []Value) ! {
	allocate_typed_array_buffer(mut vm, mut array, uint(values.len))!
	mut object := array.object
	for index, value in values {
		object.set(mut vm, PropertyName.from_number(u32(index)), value, .yes)!
	}
}

// TypedArray.cpp::InitializeTypedArrayFromArrayLike. Snapshot the observable
// length once; getters, inherited elements and value conversions remain live.
pub fn initialize_typed_array_from_array_like(mut vm VM, mut array TypedArray, source &Object) ! {
	length := length_of_array_like(mut vm, source)!
	allocate_typed_array_buffer(mut vm, mut array, uint(length))!
	mut object := array.object
	for index := u64(0); index < length; index++ {
		key := PropertyName.from_number(u32(index))
		value := source.get(mut vm, key)!
		object.set(mut vm, key, value, .yes)!
	}
}

// TypedArray.cpp::InitializeTypedArrayFromTypedArray. Same-type copies clone
// bytes (including NaN payloads); other types convert each numeric element.
pub fn initialize_typed_array_from_typed_array(mut vm VM, mut array TypedArray, source &TypedArray) ! {
	source_buffer := source.viewed_buffer
	element_size := uint(array.element_size())
	source_element_size := uint(source.element_size())
	source_offset := uint(source.byte_offset)
	record := make_typed_array_with_buffer_witness_record(source, .seq_cst)
	if is_typed_array_out_of_bounds(record) {
		return vm.throw_error_type(.type_error, .buffer_out_of_bounds, 'TypedArray')
	}
	length := typed_array_length(record)
	validate_typed_array_length(mut vm, uint(length), element_size)!
	byte_length := element_size * uint(length)
	buffer := if array.kind == source.kind {
		clone_array_buffer(mut vm, source_buffer, source_offset, byte_length)!
	} else {
		mut data := allocate_array_buffer(mut vm, vm.realm().array_buffer_constructor_record(), byte_length, none)!
		// The allocation, including its observable prototype lookup, precedes
		// the content-type check in the pinned source.
		if array.content_type() != source.content_type() {
			return vm.throw_error_type(.type_error, .typed_array_content_type_mismatch, array.object.class_name, source.object.class_name)
		}
		mut source_index := source_offset
		mut target_index := uint(0)
		for _ in 0 .. length {
			value := source.get_value_from_buffer(mut vm, source_index, .unordered, true)
			data.set_value(mut vm, target_index, array.kind, value, true, .unordered, true)
			source_index += source_element_size
			target_index += element_size
		}
		data
	}
	array.viewed_buffer = buffer
	array.byte_length = ByteLength.from_u32(u32(byte_length))
	array.byte_offset = 0
	array.array_length = ByteLength.from_u32(length)
}

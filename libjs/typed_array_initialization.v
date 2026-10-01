module libjs

// TypedArray.cpp::InitializeTypedArrayFromArrayBuffer. The caller supplies a
// concrete record; the constructor's iterable/array-like dispatch is separate.
pub fn initialize_typed_array_from_array_buffer(mut vm VM, mut array TypedArray, buffer &ArrayBufferObject, byte_offset Value, length Value) ! {
	element_size := usize(array.element_size())
	offset := usize(byte_offset.to_index(mut vm)!)
	if offset % element_size != 0 {
		return vm.throw_error_type(.range_error, .typed_array_invalid_byte_offset,
			array.object.class_name, element_size.str(), offset.str())
	}
	buffer_is_fixed_length := buffer.is_fixed_length()
	new_length := if length.is_undefined() { usize(0) } else { usize(length.to_index(mut vm)!) }
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
		mut new_byte_length := usize(0)
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
			maximum := ~usize(0)
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
	if offset > usize(0xffffffff) {
		return vm.throw_error_type(.range_error, .invalid_length, 'typed array')
	}
	array.byte_offset = u32(offset)
}

fn validate_typed_array_length(mut vm VM, length usize, element_size usize) ! {
	if length > usize(0x7fffffff) / element_size || length > (~usize(0)) / element_size {
		return vm.throw_error_type(.range_error, .invalid_length, 'typed array')
	}
}

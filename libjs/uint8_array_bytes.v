module libjs

// Runtime/Uint8Array.{h,cpp}. Intrinsics not yet installed in the realm are
// explicit inputs, as in the shared TypedArray native bodies.
pub struct Uint8ArrayDecodeResult {
pub:
	read  uint
	bytes []u8
	error ?Completion
}

pub fn validate_uint8_array(mut vm VM, prototypes PrimitiveObjectPrototypes) !&TypedArray {
	object := vm.this_value().to_object_with_prototypes(mut vm, prototypes)!
	array := object.typed_array or {
		return vm.throw_error_type(.type_error, .not_an_object_of_type, 'Uint8Array')
	}

	if array.kind != .uint8 {
		return vm.throw_error_type(.type_error, .not_an_object_of_type, 'Uint8Array')
	}
	return array
}

fn uint8_array_byte_length(mut vm VM, array &TypedArray) !uint {
	record := make_typed_array_with_buffer_witness_record(array, .seq_cst)
	if is_typed_array_out_of_bounds(record) {
		return vm.throw_error_type(.type_error, .buffer_out_of_bounds, 'TypedArray')
	}
	return uint(typed_array_length(record))
}

pub fn get_uint8_array_bytes(mut vm VM, array &TypedArray) ![]u8 {
	length := uint8_array_byte_length(mut vm, array)!
	return array.viewed_buffer.read_bytes(uint(array.byte_offset), length)
}

pub fn set_uint8_array_bytes(mut vm VM, mut array TypedArray, bytes []u8) {
	for index, byte in bytes {
		array.set_value_in_buffer(mut vm, uint(array.byte_offset) + uint(index),
			Value.from_i32(byte), .unordered, true)
	}
}

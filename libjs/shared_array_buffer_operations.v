module libjs

// Runtime/ArrayBuffer.cpp::AllocateSharedArrayBuffer, including reservation of
// the maximum capacity while exposing the initial byte length.
pub fn allocate_shared_array_buffer(mut vm VM, constructor &Object, byte_length uint, maximum ?uint) !&ArrayBufferObject {
	if limit := maximum {
		if byte_length > limit {
			return vm.throw_error_type(.range_error, .byte_length_exceeds_max_byte_length,
				byte_length.str(), limit.str())
		}
	}
	prototype := get_prototype_from_constructor(mut vm, constructor, fn (realm &Realm) &Object {
		return realm.shared_array_buffer_prototype_record()
	})!
	mut buffer := ArrayBufferObject.create_with_data_block(vm.realm(), DataBlock{ is_shared: true },
		prototype)
	buffer.set_data_block(create_shared_byte_data_block(mut vm, byte_length, maximum)!)
	buffer.maximum_byte_length = maximum
	return buffer
}

module libjs

// Runtime/ArrayBuffer.cpp: allocation, cloning, transfer, and option conversion.
pub enum PreserveResizability {
	fixed_length
	preserve_resizability
}

pub struct ArrayBufferMaxByteLengthOption {
pub:
	value ?uint
}

pub fn get_array_buffer_max_byte_length_option(mut vm VM, options Value) !ArrayBufferMaxByteLengthOption {
	if !options.is_object() { return ArrayBufferMaxByteLengthOption{} }
	maximum := options.as_object().get(mut vm, PropertyName.from_str('maxByteLength'))!
	if maximum.is_undefined() { return ArrayBufferMaxByteLengthOption{} }
	return ArrayBufferMaxByteLengthOption{
		value: uint(maximum.to_index(mut vm)!)
	}
}

pub fn allocate_array_buffer(mut vm VM, constructor &Object, byte_length uint, maximum ?uint) !&ArrayBufferObject {
	if limit := maximum {
		if byte_length > limit {
			return vm.throw_error_type(.range_error, .byte_length_exceeds_max_byte_length,
				byte_length.str(), limit.str())
		}
	}
	prototype := get_prototype_from_constructor(mut vm, constructor, fn (realm &Realm) &Object {
		return realm.array_buffer_prototype_record()
	})!
	block := create_byte_data_block(mut vm, byte_length, maximum)!
	mut buffer := ArrayBufferObject.create_with_data_block(vm.realm(), block, prototype)
	buffer.maximum_byte_length = maximum
	return buffer
}

pub fn clone_array_buffer(mut vm VM, source &ArrayBufferObject, source_offset uint, length uint) !&ArrayBufferObject {
	assert !source.is_detached()
	mut target := allocate_array_buffer(mut vm, vm.realm().array_buffer_constructor_record(),
		length, none)!
	source.copy_data_to(mut target, source_offset, 0, length)
	return target
}

pub fn array_buffer_copy_and_detach(mut vm VM, mut source ArrayBufferObject, new_length Value, preserve PreserveResizability) !&ArrayBufferObject {
	if source.is_shared_array_buffer() {
		return vm.throw_error_type(.type_error, .shared_array_buffer)
	}
	new_size := if new_length.is_undefined() {
		source.byte_length()
	} else {
		uint(new_length.to_index(mut vm)!)
	}
	if source.is_detached() { return vm.throw_error_type(.type_error, .detached_array_buffer) }
	maximum := if preserve == .preserve_resizability && !source.is_fixed_length() {
		?uint(source.max_byte_length())
	} else {
		?uint(none)
	}
	if !source.detach_key.is_undefined() {
		return vm.throw_error_type(.type_error, .detach_key_mismatch, source.detach_key.str(),
			js_undefined().str())
	}
	mut target := allocate_array_buffer(mut vm, vm.realm().array_buffer_constructor_record(),
		new_size, maximum)!
	count := if new_size < source.byte_length() { new_size } else { source.byte_length() }
	source.copy_data_to(mut target, 0, 0, count)
	detach_array_buffer(mut vm, mut source, none)!
	return target
}

module libjs

import math
import libgc

fn test_array_buffer_records_keep_slots_and_empty_storage_distinct_from_detachment() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	for size in [uint(0), 4] {
		mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), size, prototype)!
		assert voidptr(buffer.object.prototype?) == voidptr(prototype)
		assert voidptr(buffer.object.array_buffer?) == voidptr(buffer)
		assert buffer.object.class_name == 'ArrayBuffer'
		assert buffer.object.own_property_keys().len == 0
		assert buffer.byte_length() == size
		assert !buffer.is_detached() && !buffer.is_shared_array_buffer() && buffer.is_fixed_length()
		assert buffer.detach_key.is_undefined()
		assert array_buffer_byte_length(buffer, .seq_cst) == size
		assert array_buffer_byte_length(buffer, .unordered) == size
		assert buffer.read_bytes(0, size) == []u8{len: int(size)}
		detach_array_buffer(mut vm, mut buffer, none)!
		assert buffer.is_detached() && buffer.byte_length() == 0 && buffer.external_memory_size() == 0
		detach_array_buffer(mut vm, mut buffer, none)!
	}
}

fn test_array_buffer_host_resize_zero_fills_truncated_data_and_retains_maximum_slot() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2, 3, 4], false, prototype)
	buffer.maximum_byte_length = uint(32)
	assert !buffer.is_fixed_length() && buffer.max_byte_length() == 32
	assert vm.host_resize_array_buffer(mut buffer, 2)! == .handled
	assert vm.host_resize_array_buffer(mut buffer, 6)! == .handled
	assert buffer.read_bytes(0, 6) == [u8(1), 2, 0, 0, 0, 0]
	assert buffer.try_ensure_capacity(16)
	assert buffer.byte_length() == 6 && buffer.external_memory_size() >= 16
	if _ := vm.host_resize_array_buffer(mut buffer, libgc.primitive_storage_default_cage_size + 65536) { assert false } else {
		assert thrown_value(err).as_object().error_kind()? == .range_error
	}
	assert buffer.byte_length() == 6
	detach_array_buffer(mut vm, mut buffer, none)!
	assert buffer.is_detached() && !buffer.is_fixed_length() && buffer.max_byte_length() == 32
}

fn test_array_buffer_detach_key_uses_same_value_and_failed_take_leaves_bytes_attached() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	for key in [Value.from_f64(math.nan()), Value.from_f64(-0.0),
		Value.from_symbol(Symbol.create(utf16_string('key'), .unique))] {
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(42)], false, prototype)
		buffer.detach_key = key
		if _ := buffer.detach_and_take_data_block(mut vm) { assert false } else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
		assert !buffer.is_detached() && buffer.read_bytes(0, 1) == [u8(42)]
		wrong := if key.is_symbol() {
			Value.from_symbol(Symbol.create(utf16_string('key'), .unique))
		} else { Value.from_i32(0) }
		if _ := detach_array_buffer(mut vm, mut buffer, wrong) { assert false } else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
		assert !buffer.is_detached()
		detach_array_buffer(mut vm, mut buffer, key)!
		assert buffer.is_detached() && same_value(buffer.detach_key, key)
	}
	mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2], false, prototype)
	block := buffer.detach_and_take_data_block(mut vm)!
	assert block.read_bytes(0, 2) == [u8(1), 2]
	assert buffer.is_detached() && buffer.byte_length() == 0
}

fn test_array_buffer_host_alias_detachment_preserves_other_clients_and_owned_copies() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	storage := &ByteBufferStorage{bytes: [u8(1), 2, 3]}
	mut first := ArrayBufferObject.create_from_host_buffer(vm.realm(), storage, false, prototype)
	second := ArrayBufferObject.create_from_host_buffer(vm.realm(), storage, true, prototype)
	mut copy := ArrayBufferObject.create(mut vm, vm.realm(), 3, prototype)!
	assert first.shares_storage_with(second) && second.is_shared_array_buffer()
	first.copy_data_to(mut copy, 0, 0, 3)
	assert !copy.shares_storage_with(first) && copy.read_bytes(0, 3) == [u8(1), 2, 3]
	first.overwrite(0, [u8(42)])
	assert second.read_bytes(0, 3) == [u8(42), 2, 3]
	assert copy.read_bytes(0, 3) == [u8(1), 2, 3]
	detach_array_buffer(mut vm, mut first, none)!
	assert !first.shares_storage_with(second)
	assert !second.is_detached() && second.read_bytes(0, 3) == [u8(42), 2, 3]
}

module libjs

import libgc

fn test_shared_byte_data_block_preserves_zero_length_attachment_and_reserved_capacity() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for size in [uint(0), 4] {
		for capacity in [?uint(none), ?uint(12)] {
			mut block := create_shared_byte_data_block(mut vm, size, capacity)!
			assert block.is_shared && !block.is_empty()
			assert block.size() == size && block.capacity() >= capacity or { size }
			assert block.read_bytes(0, size) == []u8{len: int(size)}
			if size > 0 { block.overwrite(0, [u8(42)]) }
			assert block.try_resize(8, true)
			assert block.is_shared && block.size() == 8
			assert block.read_bytes(size, 8 - size) == []u8{len: int(8 - size)}
			if size > 0 { assert block.read_bytes(0, 1) == [u8(42)]
			 }
		}
	}
}

fn test_shared_byte_data_block_allocation_errors_use_the_requested_capacity() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	for capacity in [?uint(none), ?uint(9007199254740992)] {
		size := if capacity == none { libgc.primitive_storage_default_cage_size + 65536 } else { uint(0) }
		if _ := create_shared_byte_data_block(mut vm, size, capacity) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
			assert thrown_value(err).as_object().error_message()?.str() == 'Not enough memory to allocate ' + capacity or {
				size
			}.str() + ' bytes'
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

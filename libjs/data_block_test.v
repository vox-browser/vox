module libjs

import libgc

fn test_data_blocks_zero_initial_allocation_and_resized_bytes_with_retained_capacity() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut block := create_byte_data_block(mut vm, 4, uint(12))!
	assert !block.is_empty() && !block.is_shared
	assert block.size() == 4 && block.capacity() >= 12
	assert block.external_memory_size() == block.capacity()
	assert block.read_bytes(0, 4) == [u8(0), 0, 0, 0]
	block.overwrite(0, [u8(1), 2, 3, 4])
	assert block.try_resize(2, true)
	assert block.try_resize(5, true)
	assert block.read_bytes(0, 5) == [u8(1), 2, 0, 0, 0]
	assert block.try_ensure_capacity(32)
	assert block.size() == 5 && block.capacity() >= 32
	assert block.try_resize(0, true) && !block.is_empty()
	assert block.read_bytes(0, 0).len == 0
	assert block.try_resize(5, true)
	assert block.read_bytes(0, 5) == [u8(0), 0, 0, 0, 0]
	unallocatable := libgc.primitive_storage_default_cage_size + 65536
	assert !block.try_resize(unallocatable, true)
	assert !block.try_ensure_capacity(unallocatable)
	assert block.size() == 5
	for size in [unallocatable, uint(9007199254740992)] {
		if _ := create_byte_data_block(mut vm, size, none) { assert false } else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
			message := thrown_value(err).as_object().error_message()?.str()
			assert message.contains(if size == unallocatable { 'Not enough memory' } else { 'Invalid array buffer length' })
		}
	}
	if _ := create_byte_data_block(mut vm, 0, uint(9007199254740992)) { assert false } else {
		assert thrown_value(err).as_object().error_kind()? == .range_error
	}
}

fn test_data_block_host_aliases_keep_captured_size_and_owned_bytes_copy_input() {
	mut input := [u8(1), 2, 3]
	mut owned := DataBlock.from_bytes(input, false)
	input[0] = 9
	assert owned.read_bytes(0, 3) == [u8(1), 2, 3]
	mut host := &ByteBufferStorage{bytes: input.clone()}
	mut first := DataBlock.from_host_buffer(host, false)
	second := DataBlock.from_host_buffer(host, true)
	assert first.shares_storage_with(second) && second.is_shared
	assert !first.shares_storage_with(owned)
	assert first.external_memory_size() == 0
	first.overwrite(1, [u8(42)])
	assert host.bytes == [u8(9), 42, 3]
	assert second.read_bytes(0, 3) == host.bytes
	assert first.try_resize(5, true)
	assert first.size() == 3 && first.capacity() == 3
	assert second.size() == 3 && host.bytes == [u8(9), 42, 3, 0, 0]
	first.overwrite(0, [u8(17)])
	assert second.read_bytes(0, 1) == [u8(17)]
	empty := DataBlock{}
	assert empty.is_empty() && empty.size() == 0 && empty.capacity() == 0
	assert !empty.shares_storage_with(first) && !empty.shares_storage_with(empty)
}

fn test_data_block_copies_and_memmove_preserve_both_overlap_directions() {
	mut destination := DataBlock.from_bytes([u8(0), 0, 0, 0, 0], false)
	mut source := DataBlock.from_bytes([u8(1), 2, 3, 4], false)
	copy_data_block_bytes(mut destination, 1, source, 1, 3)
	assert destination.read_bytes(0, 5) == [u8(0), 2, 3, 4, 0]
	source.overwrite(1, [u8(42)])
	assert destination.read_bytes(0, 5) == [u8(0), 2, 3, 4, 0]
	mut right := DataBlock.from_bytes([u8(1), 2, 3, 4, 5], false)
	right.move_data(1, 0, 4)
	assert right.read_bytes(0, 5) == [u8(1), 1, 2, 3, 4]
	right.move_data(0, 1, 4)
	assert right.read_bytes(0, 5) == [u8(1), 2, 3, 4, 4]
	right.move_data(2, 2, 3)
	right.move_data(5, 5, 0)
	assert right.read_bytes(0, 5) == [u8(1), 2, 3, 4, 4]
	mut empty := DataBlock{}
	copy_data_block_bytes(mut empty, 0, empty, 0, 0)
	assert empty.is_empty()
}

module webassembly

import libgc

fn test_machine_memory_buffer_reserves_real_cage_storage_and_zeroes_grown_tail() {
	mut buffer := BinaryMachineMemoryBuffer.create()
	defer { buffer.destroy() }
	assert buffer.size() == 0 && buffer.capacity() == 0 && !buffer.primitive_storage_handle().is_valid()
	assert buffer.data() == unsafe { nil } && buffer.offset_pointer(0) == unsafe { nil }
	buffer.try_resize(0)!
	assert !buffer.primitive_storage_handle().is_valid()
	buffer.try_reserve(65536, 65536)!
	handle := buffer.primitive_storage_handle()
	base := buffer.data()
	assert handle.is_valid() && buffer.size() == 0 && buffer.capacity() == 65536
	buffer.try_resize(16)!
	unsafe {
		buffer.data()[0] = 71
		buffer.data()[15] = 83
	}
	buffer.try_resize_with_capacity(65536, 65536)!
	assert buffer.primitive_storage_handle() == handle && voidptr(buffer.data()) == voidptr(base)
	assert unsafe { buffer.data()[0] } == 71 && unsafe { buffer.data()[15] } == 83
	assert unsafe { buffer.data()[16] } == 0 && unsafe { buffer.data()[65535] } == 0
	assert buffer.contains_virtual_address(unsafe { base + 65536 })
	assert !buffer.contains_virtual_address(unsafe { base + 131072 })
	buffer.try_reserve(200000, 0)!
	assert buffer.size() == 65536 && buffer.capacity() == 200000 && buffer.primitive_storage_handle() == handle
	assert unsafe { buffer.data()[15] } == 83
	offset_address := unsafe { &uint(uint(buffer) + BinaryMachineMemoryBuffer.storage_offset_offset()) }
	assert unsafe { *offset_address } == buffer.storage_offset()
}

fn test_machine_memory_buffer_move_releases_previous_handle_and_clears_source() {
	mut destination := BinaryMachineMemoryBuffer.create()
	mut source := BinaryMachineMemoryBuffer.create()
	defer {
		destination.destroy()
		source.destroy()
	}
	destination.try_resize(17)!
	source.try_resize(29)!
	unsafe { source.data()[0] = 41 }
	old_destination := destination.primitive_storage_handle()
	source_handle := source.primitive_storage_handle()
	source_data := source.data()
	destination.move_from(mut source)
	assert !libgc.PrimitiveStorage.the().is_valid(old_destination)
	assert destination.primitive_storage_handle() == source_handle && destination.size() == 29
	assert voidptr(destination.data()) == voidptr(source_data) && unsafe { destination.data()[0] } == 41
	assert source.size() == 0 && source.capacity() == 0 && !source.primitive_storage_handle().is_valid()
	assert source.storage_offset() == libgc.primitive_storage_invalid_offset
	destination.move_from(mut destination)
	assert destination.primitive_storage_handle() == source_handle && destination.size() == 29
	destination.destroy()
	assert !libgc.PrimitiveStorage.the().is_valid(source_handle)
	assert !destination.contains_virtual_address(source_data)
}

fn test_machine_memory_buffer_bulk_copy_fill_overwrite_and_overlap_use_owned_bytes() {
	mut source := BinaryMachineMemoryBuffer.create()
	mut destination := BinaryMachineMemoryBuffer.create()
	defer {
		source.destroy()
		destination.destroy()
	}
	source.try_resize(16)!
	destination.try_resize(16)!
	for i in 0 .. 16 {
		unsafe { source.data()[i] = u8(i) }
	}
	destination.copy_from(source, 2, 0, 10)
	destination.fill(2, 9, 3)
	input := [u8(71), 73]
	destination.overwrite(6, input.data, 2)
	mut result := []u8{len: 10}
	destination.copy_to(0, BinaryMachineBytes{ data: result.data, size: uint(result.len) })
	assert result == [u8(2), 3, 9, 9, 9, 7, 71, 73, 10, 11]
	source.copy_from(source, 0, 2, 8)
	source.copy_to(0, BinaryMachineBytes{ data: result.data, size: 10 })
	assert result == [u8(0), 1, 0, 1, 2, 3, 4, 5, 6, 7]
	source.move_data(0, 2, 8)
	source.copy_to(0, BinaryMachineBytes{ data: result.data, size: 10 })
	assert result == [u8(0), 1, 2, 3, 4, 5, 6, 7, 6, 7]
	assert source.bytes().size == 16 && voidptr(source.span().at(3)) == voidptr(source.offset_pointer(3))
}

fn test_machine_memory_buffer_contiguous_chunks_follow_cage_mask_in_both_directions() {
	buffer := BinaryMachineMemoryBuffer{ storage_offset_: libgc.primitive_storage_default_cage_size - 4 }
	assert buffer.contiguous_bytes_from(0, 8) == 4
	assert buffer.contiguous_bytes_from(4, 8) == 8
	assert buffer.contiguous_bytes_before(5, 8) == 1
	assert buffer.contiguous_bytes_before(4, 8) == 8
	assert buffer.contiguous_bytes_from(0, 0) == 0 && buffer.contiguous_bytes_before(0, 0) == 0
	empty := BinaryMachineMemoryBuffer{}
	assert empty.contiguous_bytes_from(0, 8) == 8 && empty.contiguous_bytes_before(0, 8) == 8
}

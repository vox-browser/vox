module webassembly

import libgc

fn test_source_offset_pointer_empty_shortcut_precedes_cage_access_and_offset_arithmetic() {
	mut buffer := BinaryMachineMemoryBuffer.create()
	defer { buffer.destroy() }
	assert buffer.storage_offset() == libgc.primitive_storage_invalid_offset
	assert buffer.offset_pointer(0) == unsafe { nil }
	assert buffer.offset_pointer(uint(-1)) == unsafe { nil }
	buffer.try_resize(16)!
	assert buffer.primitive_storage_handle().is_valid()
	assert voidptr(buffer.offset_pointer(0)) == voidptr(buffer.data())
	buffer.destroy()
	assert buffer.storage_offset() == libgc.primitive_storage_invalid_offset
	assert buffer.offset_pointer(0) == unsafe { nil }
	assert buffer.offset_pointer(uint(-1)) == unsafe { nil }
}

fn test_source_offset_pointer_masks_actual_cage_offsets_and_refreshes_after_real_growth() {
	mut buffer := BinaryMachineMemoryBuffer.create()
	defer { buffer.destroy() }
	buffer.try_resize(16)!
	for index in [uint(0), 3, 15, 16] {
		assert voidptr(buffer.offset_pointer(index)) == unsafe { voidptr(buffer.data() + index) }
		assert voidptr(buffer.offset_pointer(libgc.primitive_storage_default_cage_size + index)) == voidptr(buffer.offset_pointer(index))
	}
	cell := buffer.offset_pointer(3)
	unsafe { *cell = u8(0x79) }
	buffer.try_resize(200000)!
	assert voidptr(buffer.offset_pointer(3)) == unsafe { voidptr(buffer.data() + 3) }
	assert unsafe { *buffer.offset_pointer(3) } == 0x79
	assert unsafe { *buffer.offset_pointer(199999) } == 0
	assert voidptr(buffer.offset_pointer(libgc.primitive_storage_default_cage_size + 3)) == voidptr(buffer.offset_pointer(3))
}

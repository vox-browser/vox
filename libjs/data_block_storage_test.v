module libjs

import libgc

fn test_data_block_native_storage_retains_large_reservations_without_narrowing() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	capacity := uint(u64(1) << 31) + 65536
	mut block := create_byte_data_block(mut vm, 0, capacity)!
	defer { block.destroy() }
	assert block.size() == 0 && block.capacity() == capacity && !block.is_empty()
	assert block.is_caged() && !block.is_external()
	owner := block.owned or { panic('missing actual owner') }
	assert owner.handle().is_valid()
	assert block.offset() == libgc.PrimitiveStorage.the().offset(owner.handle())
	assert block.data_at(0) == owner.data()
	grew := block.try_resize(4, true)
	assert grew && block.size() == 4 && block.capacity() == capacity
	assert block.read_bytes(0, 4) == [u8(0), 0, 0, 0]
	block.overwrite(0, [u8(19), 37, 71, 129])
	assert block.read_bytes(0, 4) == [u8(19), 37, 71, 129]
}

fn test_data_block_external_handles_alias_current_storage_and_keep_fixed_lengths() {
	mut owner := OwnedPrimitiveBackingStore.create_zeroed_with_capacity(4, 8)!
	defer { owner.destroy() }
	handle := owner.handle()
	mut dynamic := DataBlock.from_external_primitive_storage(voidptr(owner), handle, none, true)
	mut fixed := DataBlock.from_external_primitive_storage(voidptr(owner), handle, uint(4), true)
	assert dynamic.is_external() && dynamic.is_caged() && dynamic.is_shared
	assert dynamic.external.owner == voidptr(owner) && dynamic.external_memory_size() == 0
	assert dynamic.shares_storage_with(fixed) && dynamic.size() == 4
	dynamic.overwrite(0, [u8(1), 2, 3, 4])
	assert fixed.read_bytes(0, 4) == [u8(1), 2, 3, 4]
	owner.try_resize(65537, .yes)!
	assert dynamic.size() == 65537 && fixed.size() == 4
	assert dynamic.capacity() == owner.capacity() && dynamic.offset() == owner.offset()
	assert dynamic.data_at(0) == owner.data() && fixed.data_at(0) == owner.data()
	assert dynamic.read_bytes(0, 5) == [u8(1), 2, 3, 4, 0]
	fixed.destroy()
	assert fixed.is_empty() && libgc.PrimitiveStorage.the().is_valid(handle)
	assert dynamic.read_bytes(0, 4) == [u8(1), 2, 3, 4]
}

fn test_data_block_cage_wrap_chunks_and_readonly_callbacks_use_actual_pointers() {
	mut block := DataBlock.from_bytes([u8(4), 8, 15, 16], false)
	defer { block.destroy() }
	cage := libgc.primitive_storage_default_cage_size
	assert block.contiguous_bytes_from(cage - block.offset() - 2, 8) == 2
	assert block.contiguous_bytes_before(cage - block.offset() + 2, 8) == 2
	assert block.data_at(cage + 1) == unsafe { block.data_at(0) + 1 }
	observed := block.with_readonly_bytes[uint](1, 2, fn (bytes DataBlockBytes) uint {
		assert bytes.size == 2
		assert unsafe { bytes.data[0] } == 8 && unsafe { bytes.data[1] } == 15
		return uint(bytes.data)
	})
	assert observed == uint(block.data_at(1))
	empty := block.with_readonly_bytes[bool](4, 0, fn (bytes DataBlockBytes) bool {
		return bytes.size == 0 && bytes.data == unsafe { nil }
	})
	assert empty
	zero_owner := OwnedPrimitiveBackingStore.create_zeroed(0)!
	mut zero := DataBlock.from_owned_store(zero_owner, false)
	assert zero.is_caged() && !zero.is_empty() && zero.data_at(0) == unsafe { nil }
	assert zero.contiguous_bytes_from(uint(-1), 8) == 8
	zero.destroy()
}

fn test_array_buffer_detach_releases_owned_storage_but_take_transfers_it() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	mut detached := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(42)], false, prototype)
	old_owner := detached.block.owned or { panic('missing owner') }
	old_handle := old_owner.handle()
	detach_array_buffer(mut vm, mut detached, none)!
	assert detached.is_detached() && !libgc.PrimitiveStorage.the().is_valid(old_handle)
	mut transferred := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(77)], false, prototype)
	taken_owner := transferred.block.owned or { panic('missing owner') }
	taken_handle := taken_owner.handle()
	mut block := transferred.detach_and_take_data_block(mut vm)!
	assert transferred.is_detached() && libgc.PrimitiveStorage.the().is_valid(taken_handle)
	assert block.read_bytes(0, 1) == [u8(77)]
	block.destroy()
	assert !libgc.PrimitiveStorage.the().is_valid(taken_handle)
}

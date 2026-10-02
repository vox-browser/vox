module libjs

import libgc

fn test_owned_primitive_backing_store_uses_source_slab_zero_fill_and_move_ownership() {
	mut buffer := OwnedPrimitiveBackingStore.create_zeroed(17)!
	defer { buffer.destroy() }
	assert buffer.size() == 17 && buffer.capacity() == 32 && buffer.handle().is_valid()
	for i in 0 .. 17 {
		assert unsafe { buffer.data()[i] } == 0
	}
	base := buffer.data()
	unsafe {
		base[0] = 101
		base[16] = 103
	}
	buffer.set_size(8, .no)
	assert buffer.size() == 8 && voidptr(buffer.data()) == voidptr(base)
	buffer.try_resize(17, .yes)!
	assert unsafe { buffer.data()[0] } == 101 && unsafe { buffer.data()[16] } == 0
	mut replacement := OwnedPrimitiveBackingStore.create_zeroed(19)!
	defer { replacement.destroy() }
	old_handle := replacement.handle()
	retained_handle := buffer.handle()
	replacement.move_from(mut buffer)
	assert !libgc.PrimitiveStorage.the().is_valid(old_handle)
	assert replacement.handle() == retained_handle && replacement.size() == 17
	assert !buffer.handle().is_valid() && buffer.size() == 0 && buffer.data() == unsafe { nil }
	replacement.move_from(mut replacement)
	assert replacement.handle() == retained_handle
	replacement.destroy()
	assert !libgc.PrimitiveStorage.the().is_valid(retained_handle)
}

fn test_owned_primitive_backing_store_reserve_resize_and_uninitialized_reuse_follow_source_handles() {
	mut empty := OwnedPrimitiveBackingStore.create_zeroed(0)!
	defer { empty.destroy() }
	empty.try_resize(0, .yes)!
	empty.try_ensure_capacity(0)!
	assert !empty.handle().is_valid() && empty.offset() == libgc.primitive_storage_invalid_offset
	empty.try_ensure_capacity(131072)!
	handle := empty.handle()
	base := empty.data()
	assert handle.is_valid() && empty.size() == 0 && empty.capacity() == 131072
	empty.try_resize(65536, .yes)!
	unsafe { base[0] = 107 }
	empty.try_ensure_capacity(262144)!
	assert empty.handle() == handle && empty.size() == 65536 && empty.capacity() == 262144
	assert unsafe { empty.data()[0] } == 107
	empty.try_resize(131073, .yes)!
	assert unsafe { empty.data()[65536] } == 0 && unsafe { empty.data()[131072] } == 0
	mut initial := OwnedPrimitiveBackingStore.create_uninitialized(29)!
	old_base := initial.data()
	unsafe { old_base[0] = 109 }
	initial.destroy()
	mut reused := OwnedPrimitiveBackingStore.create_uninitialized(29)!
	defer { reused.destroy() }
	assert voidptr(reused.data()) == voidptr(old_base) && unsafe { reused.data()[0] } == 109
	mut capacity_only := OwnedPrimitiveBackingStore.create_zeroed_with_capacity(0, 8192)!
	defer { capacity_only.destroy() }
	assert capacity_only.size() == 0 && capacity_only.capacity() == 8192
	// Pinned constructor only allocates when capacity is nonzero.
	mut zero_capacity := OwnedPrimitiveBackingStore.create_zeroed_with_capacity(7, 0)!
	defer { zero_capacity.destroy() }
	assert zero_capacity.size() == 0 && !zero_capacity.handle().is_valid()
}

module libgc

fn test_primitive_storage_handle_growth_preserves_identity_and_real_owned_bytes() {
	mut storage := PrimitiveStorage.the()
	assert voidptr(storage) == voidptr(PrimitiveStorage.the())
	handle := storage.try_allocate(12, .yes)!
	defer { storage.free_handle(handle) }
	assert storage.is_valid(handle) && storage.size(handle) == 12 && storage.capacity(handle) == 16
	unsafe {
		storage.data(handle)[0] = 31
		storage.data(handle)[11] = 37
	}
	small_offset := storage.offset(handle)
	storage.try_resize(handle, 16, .yes)!
	assert storage.offset(handle) == small_offset
	assert unsafe { storage.data(handle)[11] } == 37 && unsafe { storage.data(handle)[15] } == 0
	storage.try_resize(handle, 31, .yes)!
	assert storage.is_valid(handle) && storage.size(handle) == 31 && storage.capacity(handle) == 32
	assert storage.offset(handle) != small_offset
	assert unsafe { storage.data(handle)[0] } == 31 && unsafe { storage.data(handle)[30] } == 0
	storage.try_reserve_handle(handle, 100000)!
	assert storage.size(handle) == 31 && storage.capacity(handle) == 100000
	large_base := storage.data(handle)
	assert unsafe { large_base[11] } == 37
	storage.try_resize_and_reserve(handle, 70000, 80000, .yes)!
	// Capacity is not shrunk when the existing allocation already contains it.
	assert storage.capacity(handle) == 100000 && storage.size(handle) == 70000
	assert voidptr(storage.data(handle)) == voidptr(large_base)
	assert unsafe { large_base[31] } == 0 && unsafe { large_base[69999] } == 0
	assert storage.committed_size(handle) == round_storage_up_to_page(70000)
	assert storage.contains(large_base, 70000) && storage.contains_handle(handle, large_base, 70000)
	assert uint(storage.data_at(handle, primitive_storage_default_cage_size + 7)) == uint(large_base) + 7
	assert primitive_storage_cage_base() == uint(storage.cage_base()) && storage.cage_size() == primitive_storage_default_cage_size
}

fn test_primitive_storage_stale_handles_invalid_results_and_source_error_precedence() {
	mut storage := PrimitiveStorage.the()
	handle := storage.try_reserve(1, storage_page_size(), .yes, 0)!
	storage.free_handle(handle)
	storage.free_handle(handle)
	assert !storage.is_valid(handle)
	assert storage.offset(handle) == primitive_storage_invalid_offset
	assert storage.size(handle) == 0 && storage.capacity(handle) == 0 && storage.committed_size(handle) == 0
	assert storage.data(handle) == unsafe { nil } && storage.data_at(handle, 1) == unsafe { nil }
	assert !storage.contains_handle(handle, storage.cage_base(), 0)
	reused := storage.try_allocate(1, .yes)!
	defer { storage.free_handle(reused) }
	assert reused.index == handle.index && reused.generation == handle.generation + 1
	assert !storage.is_valid(handle) && storage.is_valid(reused)
	if _ := storage.try_resize(handle, 1, .yes) {
		assert false
	} else {
		assert err.code() == C.EINVAL
	}
	if _ := storage.try_reserve_handle(handle, 1) {
		assert false
	} else {
		assert err.code() == C.EINVAL
	}
	// Size/capacity rejection precedes handle validation in the pinned source.
	if _ := storage.try_resize_and_reserve(handle, 2, 1, .yes) {
		assert false
	} else {
		assert err.code() == C.ENOMEM
	}
	if _ := storage.try_resize_and_reserve(handle, 1, 1, .yes) {
		assert false
	} else {
		assert err.code() == C.EINVAL
	}
	if _ := storage.try_reserve(2, 1, .yes, 0) {
		assert false
	} else {
		assert err.code() == C.ENOMEM
	}
}

fn test_primitive_storage_reservations_keep_guard_range_and_empty_handle_semantics() {
	mut storage := PrimitiveStorage.the()
	page := storage_page_size()
	handle := storage.try_reserve(1, page, .yes, page)!
	defer { storage.free_handle(handle) }
	assert storage.capacity(handle) == page && storage.committed_size(handle) == page
	base := storage.data(handle)
	assert storage.contains_handle(handle, unsafe { base + page }, page)
	assert storage.contains_handle(handle, unsafe { base + page * 2 }, 0)
	assert !storage.contains_handle(handle, unsafe { base + page * 2 }, 1)
	empty := storage.try_reserve(0, 0, .yes, 0)!
	defer { storage.free_handle(empty) }
	assert storage.is_valid(empty) && storage.size(empty) == 0 && storage.capacity(empty) == 0
	assert storage.data(empty) != unsafe { nil }
	assert storage.contains_handle(empty, storage.data(empty), 0)
	assert !storage.contains_handle(empty, storage.data(empty), 1)
}

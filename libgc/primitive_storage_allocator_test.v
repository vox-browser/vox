module libgc

fn release_test_storage_cage(allocator &PrimitiveStorageAllocator) {
	if allocator.cage_base != unsafe { nil } {
		release_storage_address_space(allocator.cage_base, allocator.cage_size + storage_page_size()) or { panic(err) }
	}
}

fn test_primitive_storage_small_size_classes_slot_order_and_zero_fill_reuse() {
	assert primitive_small_size_class_index(0) == ?u16(0)
	assert primitive_small_size_class_index(16) == ?u16(0)
	assert primitive_small_size_class_index(17) == ?u16(1)
	assert primitive_small_size_class_index(65536) == ?u16(12)
	assert primitive_small_size_class_index(65537) == none
	mut allocator := PrimitiveStorageAllocator{}
	defer { release_test_storage_cage(&allocator) }
	mut first := allocator.allocate(31, 31, .yes, 0, false)!
	mut second := allocator.allocate(31, 31, .yes, 0, false)!
	assert first.capacity == 32 && first.reservation_size == 32 && first.committed_size == 32
	first_small := first.small_allocation or { panic('not small') }
	second_small := second.small_allocation or { panic('not small') }
	assert first_small.slot_index == 0 && second_small.slot_index == 1
	assert first_small.slab_index == second_small.slab_index && second.offset == first.offset + 32
	pointer := allocator.data(first, 0)
	unsafe {
		pointer[0] = 83
		pointer[30] = 71
		pointer[31] = 97
	}
	old_offset := first.offset
	allocator.deallocate(mut first)
	mut reused := allocator.allocate(31, 31, .no, 0, false)!
	assert reused.offset == old_offset && unsafe { allocator.data(reused, 0)[0] } == 83
	allocator.deallocate(mut reused)
	mut cleared := allocator.allocate(31, 31, .yes, 0, false)!
	assert cleared.offset == old_offset
	assert unsafe { allocator.data(cleared, 0)[0] } == 0
	assert unsafe { allocator.data(cleared, 0)[30] } == 0
	// Source zeroes the requested bytes, leaving the unused slot padding alone.
	assert unsafe { allocator.data(cleared, 0)[31] } == 97
	allocator.resize(mut cleared, 31, 32, .yes)!
	assert unsafe { allocator.data(cleared, 0)[31] } == 0
	allocator.deallocate(mut cleared)
	allocator.deallocate(mut second)
	assert allocator.small_slabs[1][0].used_slot_count == 0
	// Empty small slabs stay committed and are reused; they are not free ranges.
	assert allocator.next_offset == primitive_small_slab_size && allocator.free_ranges.len == 0
}

fn test_primitive_storage_large_commit_growth_preserves_bytes_and_guard_extent() {
	mut allocator := PrimitiveStorageAllocator{}
	defer { release_test_storage_cage(&allocator) }
	page := storage_page_size()
	mut allocation := allocator.allocate(3, page * 4 + 1, .yes, page + 1, true)!
	assert allocation.small_allocation == none && allocation.capacity == page * 4 + 1
	assert allocation.reservation_size == page * 7 && allocation.committed_size == page
	base := allocator.data(allocation, 0)
	unsafe {
		base[0] = 41
		base[2] = 53
	}
	allocator.resize(mut allocation, 3, page + 2, .yes)!
	assert allocation.committed_size == page * 2 && voidptr(allocator.data(allocation, 0)) == voidptr(base)
	assert unsafe { base[0] } == 41 && unsafe { base[2] } == 53
	assert unsafe { base[3] } == 0 && unsafe { base[page + 1] } == 0
	allocator.resize(mut allocation, page + 2, 1, .no)!
	assert allocation.committed_size == page * 2
	assert allocator.contains_address(base, 1)
	assert allocator.contains_allocation(allocation, unsafe { base + page * 6 }, 1)
	assert allocator.contains_allocation(allocation, unsafe { base + page * 7 }, 0)
	assert !allocator.contains_allocation(allocation, unsafe { base + page * 7 }, 1)
	assert uint(allocator.data(allocation, primitive_storage_default_cage_size + 19)) == uint(base) + 19
	assert primitive_storage_cage_base() == uint(allocator.cage_base)
	assert allocator.contains_address(unsafe { allocator.cage_base + allocator.cage_size }, 0)
	assert !allocator.contains_address(unsafe { allocator.cage_base + allocator.cage_size }, 1)
	assert !allocator.contains_address(unsafe { nil }, 0)
	allocator.deallocate(mut allocation)
	assert allocation.offset == primitive_storage_invalid_offset
	assert allocator.next_offset == 0 && allocator.free_ranges.len == 0
}

fn test_primitive_storage_free_range_coalescing_first_fit_and_top_reclamation() {
	mut allocator := PrimitiveStorageAllocator{}
	defer { release_test_storage_cage(&allocator) }
	page := storage_page_size()
	mut a := allocator.allocate(1, page, .yes, 0, true)!
	mut b := allocator.allocate(1, page, .yes, 0, true)!
	mut c := allocator.allocate(1, page, .yes, 0, true)!
	mut d := allocator.allocate(1, page, .yes, 0, true)!
	allocator.deallocate(mut b)
	allocator.deallocate(mut c)
	assert allocator.free_ranges.len == 1 && allocator.free_ranges[0].offset == page && allocator.free_ranges[0].size == page * 2
	mut reused := allocator.allocate(1, page, .yes, 0, true)!
	assert reused.offset == page
	assert allocator.free_ranges[0].offset == page * 2 && allocator.free_ranges[0].size == page
	allocator.deallocate(mut reused)
	allocator.deallocate(mut d)
	assert allocator.next_offset == page && allocator.free_ranges.len == 0
	allocator.deallocate(mut a)
	assert allocator.next_offset == 0
	// Source supports an empty large reservation at the current top without
	// consuming a free range or advancing the cage offset.
	mut empty := allocator.allocate(0, 0, .yes, 0, true)!
	assert empty.offset == 0 && empty.capacity == 0 && empty.reservation_size == 0
	allocator.deallocate(mut empty)
	if _ := allocator.allocate_cage_range(primitive_storage_default_cage_size + page) {
		assert false
	} else {
		assert err.code() == C.ENOMEM && allocator.next_offset == 0
	}
}

fn test_primitive_storage_reallocation_copies_old_bytes_and_zeroes_only_new_tail() {
	mut allocator := PrimitiveStorageAllocator{}
	defer { release_test_storage_cage(&allocator) }
	mut initial := allocator.allocate(12, 12, .yes, 0, false)!
	unsafe {
		allocator.data(initial, 0)[0] = 19
		allocator.data(initial, 0)[11] = 23
	}
	mut replacement := allocator.reallocate(initial, 12, 33, 100000, .yes, true)!
	assert replacement.small_allocation == none && replacement.capacity == 100000
	assert replacement.offset != initial.offset
	assert unsafe { allocator.data(replacement, 0)[0] } == 19
	assert unsafe { allocator.data(replacement, 0)[11] } == 23
	assert unsafe { allocator.data(replacement, 0)[12] } == 0
	assert unsafe { allocator.data(replacement, 0)[32] } == 0
	allocator.deallocate(mut initial)
	allocator.deallocate(mut replacement)
}

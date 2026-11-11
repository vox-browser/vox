// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// LibGC/PrimitiveStorage.{h,cpp}: complete private Allocator.
module libgc

import math

pub const primitive_storage_default_cage_size = uint(u64(4) * 1024 * 1024 * 1024 * 1024)
pub const primitive_storage_invalid_offset = uint(-1)
const primitive_small_slab_size = uint(64 * 1024)
const primitive_minimum_small_slot_size = uint(16)
const primitive_maximum_small_slot_size = uint(64 * 1024)

pub enum ZeroFillNewBytes {
	no
	yes
}

pub fn mask_primitive_storage_offset(offset uint) uint {
	return offset & (primitive_storage_default_cage_size - 1)
}

fn align_storage_up(value uint, alignment uint) uint {
	return (value + alignment - 1) & ~(alignment - 1)
}

fn round_storage_up_to_page(value uint) uint {
	return align_storage_up(value, storage_page_size())
}

fn primitive_small_size_class_index(size uint) ?u16 {
	slot_size := math.max(size, primitive_minimum_small_slot_size)
	if slot_size > primitive_maximum_small_slot_size { return none }
	mut class_size := primitive_minimum_small_slot_size
	mut index := u16(0)
	for class_size < slot_size {
		class_size <<= 1
		index++
	}
	return index
}

fn primitive_small_slot_size_for_class(index u16) uint {
	return primitive_minimum_small_slot_size << index
}

struct PrimitiveStorageSmallAllocation {
	size_class_index u16
	slab_index       u16
	slot_index       u32
}

struct PrimitiveStorageAllocation {
mut:
	offset           uint = primitive_storage_invalid_offset
	capacity         uint
	reservation_size uint
	committed_size   uint
	small_allocation ?PrimitiveStorageSmallAllocation
}

struct PrimitiveStorageFreeRange {
mut:
	offset uint
	size   uint
}

struct PrimitiveStorageSlab {
mut:
	offset          uint
	slot_size       uint
	slot_count      u32
	used_slot_count u32
	free_slots      []u32
}

struct PrimitiveStorageAllocator {
mut:
	cage_base   &u8 = unsafe { nil }
	cage_size   uint
	next_offset uint
	free_ranges []PrimitiveStorageFreeRange
	small_slabs [13][]PrimitiveStorageSlab
}

fn (mut allocator PrimitiveStorageAllocator) ensure_cage() ! {
	if allocator.cage_base != unsafe { nil } { return }
	if sizeof(voidptr) < sizeof(u64) { return storage_errno_error(C.ENOMEM) }
	allocator.cage_size = primitive_storage_default_cage_size
	if allocator.cage_size > uint(-1) - storage_page_size() {
		return storage_errno_error(C.ENOMEM)
	}
	allocator.cage_base = reserve_storage_address_space(allocator.cage_size + storage_page_size())!
	C.vox_gc_set_primitive_storage_cage_base(allocator.cage_base)
}

fn (mut allocator PrimitiveStorageAllocator) allocate(size uint, capacity uint, zero_fill ZeroFillNewBytes, guard_size uint, force_large bool) !PrimitiveStorageAllocation {
	assert size <= capacity
	if !force_large && guard_size == 0 && size == capacity {
		if _ := primitive_small_size_class_index(size) {
			return allocator.allocate_small_storage(size, zero_fill)
		}
	}
	return allocator.allocate_large_storage(size, capacity, guard_size)
}

fn (mut allocator PrimitiveStorageAllocator) allocate_small_storage(size uint, zero_fill ZeroFillNewBytes) !PrimitiveStorageAllocation {
	class_index := primitive_small_size_class_index(size) or { panic('Invalid source small size class') }
	allocator.ensure_cage()!
	slot_size := primitive_small_slot_size_for_class(class_index)
	for slab_index in 0 .. allocator.small_slabs[class_index].len {
		mut slab := unsafe { &allocator.small_slabs[class_index][slab_index] }
		if slab.free_slots.len == 0 { continue }
		slot_index := slab.free_slots.pop()
		slab.used_slot_count++
		offset := slab.offset + uint(slot_index) * slot_size
		if zero_fill == .yes { unsafe { C.memset(allocator.cage_base + offset, 0, size) } }
		return PrimitiveStorageAllocation{ offset: offset, capacity: slot_size, reservation_size: slot_size, committed_size: slot_size, small_allocation: PrimitiveStorageSmallAllocation{ size_class_index: class_index, slab_index: u16(slab_index), slot_index: slot_index } }
	}
	return allocator.allocate_from_new_slab(class_index, slot_size, zero_fill, size)
}

fn (mut allocator PrimitiveStorageAllocator) allocate_from_new_slab(class_index u16, slot_size uint, zero_fill ZeroFillNewBytes, requested_size uint) !PrimitiveStorageAllocation {
	if allocator.small_slabs[class_index].len >= 0xffff { return storage_errno_error(C.ENOMEM) }
	slab_offset := allocator.allocate_cage_range(primitive_small_slab_size)!
	commit_storage_memory(unsafe { allocator.cage_base + slab_offset }, primitive_small_slab_size) or {
		allocator.release_cage_range(slab_offset, primitive_small_slab_size)
		return err
	}
	mut slab := PrimitiveStorageSlab{ offset: slab_offset, slot_size: slot_size, slot_count: u32(primitive_small_slab_size / slot_size), used_slot_count: 1 }
	for slot := slab.slot_count - 1; slot > 0; slot-- { slab.free_slots << slot }
	slab_index := u16(allocator.small_slabs[class_index].len)
	allocator.small_slabs[class_index] << slab
	if zero_fill == .yes {
		unsafe { C.memset(allocator.cage_base + slab_offset, 0, requested_size) }
	}
	return PrimitiveStorageAllocation{ offset: slab_offset, capacity: slot_size, reservation_size: slot_size, committed_size: slot_size, small_allocation: PrimitiveStorageSmallAllocation{ size_class_index: class_index, slab_index: slab_index, slot_index: 0 } }
}

fn (mut allocator PrimitiveStorageAllocator) allocate_large_storage(size uint, capacity uint, guard_size uint) !PrimitiveStorageAllocation {
	allocator.ensure_cage()!
	rounded_capacity := round_storage_up_to_page(capacity)
	rounded_guard_size := round_storage_up_to_page(guard_size)
	if rounded_capacity > uint(-1) - rounded_guard_size { return storage_errno_error(C.ENOMEM) }
	reservation_size := rounded_capacity + rounded_guard_size
	offset := allocator.allocate_cage_range(reservation_size)!
	committed_size := round_storage_up_to_page(size)
	if committed_size > 0 {
		commit_storage_memory(unsafe { allocator.cage_base + offset }, committed_size) or {
			allocator.release_cage_range(offset, reservation_size)
			return err
		}
	}
	// Freshly committed anonymous pages are zeroed lazily by the operating system.
	return PrimitiveStorageAllocation{ offset: offset, capacity: capacity, reservation_size: reservation_size, committed_size: committed_size }
}

fn (mut allocator PrimitiveStorageAllocator) allocate_cage_range(requested_size uint) !uint {
	assert allocator.cage_base != unsafe { nil }
	reservation_size := round_storage_up_to_page(requested_size)
	if reservation_size == 0 { return allocator.next_offset }
	for i in 0 .. allocator.free_ranges.len {
		range := allocator.free_ranges[i]
		if range.size < reservation_size { continue }
		offset := range.offset
		allocator.free_ranges[i].offset += reservation_size
		allocator.free_ranges[i].size -= reservation_size
		if allocator.free_ranges[i].size == 0 { allocator.free_ranges.delete(i) }
		return offset
	}
	next_offset := align_storage_up(allocator.next_offset, storage_page_size())
	if next_offset > uint(-1) - reservation_size { return storage_errno_error(C.ENOMEM) }
	new_next_offset := next_offset + reservation_size
	if new_next_offset > allocator.cage_size { return storage_errno_error(C.ENOMEM) }
	allocator.next_offset = new_next_offset
	return next_offset
}

fn (mut allocator PrimitiveStorageAllocator) resize(mut allocation PrimitiveStorageAllocation, old_size uint, new_size uint, zero_fill ZeroFillNewBytes) ! {
	assert new_size <= allocation.capacity
	old_committed_size := allocation.committed_size
	if allocation.small_allocation == none {
		allocator.commit_large_storage(mut allocation, new_size)!
	}
	// Only the previously committed tail can still contain old data.
	zero_fill_end := math.min(new_size, old_committed_size)
	if zero_fill == .yes && zero_fill_end > old_size {
		unsafe { C.memset(allocator.data(allocation, old_size), 0, zero_fill_end - old_size) }
	}
}

fn (mut allocator PrimitiveStorageAllocator) commit_large_storage(mut allocation PrimitiveStorageAllocation, new_size uint) ! {
	assert allocation.small_allocation == none && new_size <= allocation.capacity
	new_committed_size := round_storage_up_to_page(new_size)
	if new_committed_size > allocation.committed_size {
		commit_storage_memory(unsafe { allocator.cage_base + allocation.offset + allocation.committed_size }, new_committed_size - allocation.committed_size)!
		allocation.committed_size = new_committed_size
	}
}

fn (allocator &PrimitiveStorageAllocator) decommit_large_storage(allocation PrimitiveStorageAllocation) {
	assert allocation.small_allocation == none
	if allocation.committed_size == 0 { return }
	decommit_storage_memory(unsafe { allocator.cage_base + allocation.offset }, allocation.committed_size) or { panic(err) }
}

fn (mut allocator PrimitiveStorageAllocator) reallocate(old_allocation PrimitiveStorageAllocation, old_size uint, new_size uint, new_capacity uint, zero_fill ZeroFillNewBytes, force_large bool) !PrimitiveStorageAllocation {
	assert new_size <= new_capacity
	allocation := allocator.allocate(new_size, new_capacity, .no, 0, force_large)!
	bytes_to_copy := math.min(old_size, new_size)
	if bytes_to_copy > 0 {
		unsafe { C.memcpy(allocator.cage_base + allocation.offset, allocator.cage_base + old_allocation.offset, bytes_to_copy) }
	}
	if zero_fill == .yes && new_size > old_size && allocation.small_allocation != none {
		unsafe { C.memset(allocator.cage_base + allocation.offset + old_size, 0, new_size - old_size) }
	}
	return allocation
}

fn (mut allocator PrimitiveStorageAllocator) deallocate(mut allocation PrimitiveStorageAllocation) {
	if small := allocation.small_allocation {
		assert int(small.slab_index) < allocator.small_slabs[small.size_class_index].len
		mut slab := unsafe { &allocator.small_slabs[small.size_class_index][small.slab_index] }
		assert u64(slab.free_slots.len) < u64(slab.slot_count)
		slab.free_slots << small.slot_index
		assert slab.used_slot_count > 0
		slab.used_slot_count--
		allocation = PrimitiveStorageAllocation{}
		return
	}
	if allocation.reservation_size > 0 {
		allocator.decommit_large_storage(allocation)
		allocator.release_cage_range(allocation.offset, allocation.reservation_size)
	}
	allocation = PrimitiveStorageAllocation{}
}

fn (mut allocator PrimitiveStorageAllocator) release_cage_range(offset uint, requested_size uint) {
	size := round_storage_up_to_page(requested_size)
	if size == 0 { return }
	if offset <= allocator.next_offset && size == allocator.next_offset - offset {
		allocator.next_offset = offset
		allocator.reclaim_free_ranges_at_top()
		return
	}
	allocator.free_cage_range(offset, size)
}

fn (mut allocator PrimitiveStorageAllocator) free_cage_range(offset uint, requested_size uint) {
	size := round_storage_up_to_page(requested_size)
	if size == 0 { return }
	mut insert_before := 0
	for insert_before < allocator.free_ranges.len && allocator.free_ranges[insert_before].offset < offset {
		insert_before++
	}
	allocator.free_ranges.insert(insert_before, PrimitiveStorageFreeRange{ offset: offset, size: size })
	if insert_before > 0 {
		if allocator.free_ranges[insert_before - 1].offset + allocator.free_ranges[insert_before - 1].size == allocator.free_ranges[insert_before].offset {
			allocator.free_ranges[insert_before - 1].size += allocator.free_ranges[insert_before].size
			allocator.free_ranges.delete(insert_before)
			insert_before--
		}
	}
	if insert_before + 1 < allocator.free_ranges.len {
		if allocator.free_ranges[insert_before].offset + allocator.free_ranges[insert_before].size == allocator.free_ranges[insert_before + 1].offset {
			allocator.free_ranges[insert_before].size += allocator.free_ranges[insert_before + 1].size
			allocator.free_ranges.delete(insert_before + 1)
		}
	}
	allocator.reclaim_free_ranges_at_top()
}

fn (mut allocator PrimitiveStorageAllocator) reclaim_free_ranges_at_top() {
	for allocator.free_ranges.len > 0 {
		range := allocator.free_ranges.last()
		if range.offset > allocator.next_offset || range.size != allocator.next_offset - range.offset {
			return
		}
		allocator.next_offset = range.offset
		allocator.free_ranges.pop()
	}
}

fn (allocator &PrimitiveStorageAllocator) contains_address(address voidptr, size uint) bool {
	if allocator.cage_base == unsafe { nil } || address == unsafe { nil } { return false }
	base := uint(allocator.cage_base)
	if uint(address) < base { return false }
	offset := uint(address) - base
	return offset <= allocator.cage_size && size <= allocator.cage_size - offset
}

fn (allocator &PrimitiveStorageAllocator) contains_allocation(allocation PrimitiveStorageAllocation, address voidptr, size uint) bool {
	if address == unsafe { nil } || allocation.offset == primitive_storage_invalid_offset {
		return false
	}
	base := uint(allocator.cage_base)
	if allocator.cage_base == unsafe { nil } || uint(address) < base { return false }
	offset := uint(address) - base
	if offset < allocation.offset { return false }
	allocation_offset := offset - allocation.offset
	return allocation_offset <= allocation.reservation_size && size <= allocation.reservation_size - allocation_offset
}

fn (allocator &PrimitiveStorageAllocator) data(allocation PrimitiveStorageAllocation, byte_offset uint) &u8 {
	assert allocator.cage_base != unsafe { nil } && allocation.offset != primitive_storage_invalid_offset
	return unsafe { allocator.cage_base + mask_primitive_storage_offset(allocation.offset + byte_offset) }
}

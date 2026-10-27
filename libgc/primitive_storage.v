// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// LibGC/PrimitiveStorage.{h,cpp}: handle ownership and public storage operations.
@[has_globals]
module libgc

const primitive_storage_tag = ExternalEntityTableTag{ value: 0x00ff }

struct PrimitiveStorageEntry {
mut:
	size       uint
	allocation PrimitiveStorageAllocation
}

@[heap]
pub struct PrimitiveStorage {
mut:
	table     ExternalEntityTable
	allocator PrimitiveStorageAllocator
	entries   []PrimitiveStorageEntry
}

// Source NeverDestroyed singleton: the process retains its cage and slab pools.
__global primitive_storage_instance_ = &PrimitiveStorage{}

pub fn PrimitiveStorage.the() &PrimitiveStorage { return primitive_storage_instance_ }

pub fn (mut storage PrimitiveStorage) ensure_cage() ! { storage.allocator.ensure_cage()! }

pub fn (storage &PrimitiveStorage) cage_base() &u8 { return storage.allocator.cage_base }

pub fn (storage &PrimitiveStorage) cage_size() uint { return storage.allocator.cage_size }

pub fn (mut storage PrimitiveStorage) try_allocate(size uint, zero_fill ZeroFillNewBytes) !ExternalEntityTableHandle {
	allocation := storage.allocator.allocate(size, size, zero_fill, 0, false)!
	return storage.install_allocation(allocation, size)
}

pub fn (mut storage PrimitiveStorage) try_reserve(size uint, capacity uint, zero_fill ZeroFillNewBytes, guard_size uint) !ExternalEntityTableHandle {
	if size > capacity { return storage_errno_error(C.ENOMEM) }
	allocation := storage.allocator.allocate(size, capacity, zero_fill, guard_size, true)!
	return storage.install_allocation(allocation, size)
}

fn (mut storage PrimitiveStorage) install_allocation(allocation PrimitiveStorageAllocation, size uint) ExternalEntityTableHandle {
	handle := storage.table.allocate_entry(primitive_storage_tag)
	if int(handle.index) == storage.entries.len { storage.entries << PrimitiveStorageEntry{} }
	storage.entries[int(handle.index)].size = size
	storage.entries[int(handle.index)].allocation = allocation
	return handle
}

pub fn (storage &PrimitiveStorage) is_valid(handle ExternalEntityTableHandle) bool {
	return storage.table.is_valid(handle, primitive_storage_tag)
}

pub fn (storage &PrimitiveStorage) contains(address voidptr, size uint) bool {
	return storage.allocator.contains_address(address, size)
}

pub fn (storage &PrimitiveStorage) contains_handle(handle ExternalEntityTableHandle, address voidptr, size uint) bool {
	entry := storage.entry_for(handle)
	return entry != unsafe { nil } && storage.allocator.contains_allocation(entry.allocation, address, size)
}

pub fn (storage &PrimitiveStorage) offset(handle ExternalEntityTableHandle) uint {
	entry := storage.entry_for(handle)
	if entry == unsafe { nil } { return primitive_storage_invalid_offset }
	return entry.allocation.offset
}

pub fn (storage &PrimitiveStorage) size(handle ExternalEntityTableHandle) uint {
	entry := storage.entry_for(handle)
	if entry == unsafe { nil } { return 0 }
	return entry.size
}

pub fn (storage &PrimitiveStorage) capacity(handle ExternalEntityTableHandle) uint {
	entry := storage.entry_for(handle)
	if entry == unsafe { nil } { return 0 }
	return entry.allocation.capacity
}

pub fn (storage &PrimitiveStorage) committed_size(handle ExternalEntityTableHandle) uint {
	entry := storage.entry_for(handle)
	if entry == unsafe { nil } { return 0 }
	return entry.allocation.committed_size
}

pub fn (storage &PrimitiveStorage) data(handle ExternalEntityTableHandle) &u8 {
	entry := storage.entry_for(handle)
	if entry == unsafe { nil } { return unsafe { nil } }
	return storage.data_unchecked(entry)
}

pub fn (storage &PrimitiveStorage) data_at(handle ExternalEntityTableHandle, byte_offset uint) &u8 {
	entry := storage.entry_for(handle)
	if entry == unsafe { nil } { return unsafe { nil } }
	return storage.allocator.data(entry.allocation, byte_offset)
}

pub fn (mut storage PrimitiveStorage) try_resize(handle ExternalEntityTableHandle, new_size uint, zero_fill ZeroFillNewBytes) ! {
	mut entry := storage.entry_for(handle)
	if entry == unsafe { nil } { return storage_errno_error(C.EINVAL) }
	if new_size <= entry.allocation.capacity {
		storage.allocator.resize(mut entry.allocation, entry.size, new_size, zero_fill)!
		entry.size = new_size
		return
	}
	storage.reallocate_entry(mut entry, new_size, new_size, zero_fill, false)!
}

pub fn (mut storage PrimitiveStorage) try_reserve_handle(handle ExternalEntityTableHandle, new_capacity uint) ! {
	mut entry := storage.entry_for(handle)
	if entry == unsafe { nil } { return storage_errno_error(C.EINVAL) }
	if new_capacity <= entry.allocation.capacity { return }
	storage.reallocate_entry(mut entry, entry.size, new_capacity, .no, true)!
}

pub fn (mut storage PrimitiveStorage) try_resize_and_reserve(handle ExternalEntityTableHandle, new_size uint, new_capacity uint, zero_fill ZeroFillNewBytes) ! {
	if new_size > new_capacity { return storage_errno_error(C.ENOMEM) }
	mut entry := storage.entry_for(handle)
	if entry == unsafe { nil } { return storage_errno_error(C.EINVAL) }
	if new_capacity <= entry.allocation.capacity {
		storage.allocator.resize(mut entry.allocation, entry.size, new_size, zero_fill)!
		entry.size = new_size
		return
	}
	storage.reallocate_entry(mut entry, new_size, new_capacity, zero_fill, true)!
}

fn (mut storage PrimitiveStorage) reallocate_entry(mut entry PrimitiveStorageEntry, new_size uint, new_capacity uint, zero_fill ZeroFillNewBytes, force_large bool) ! {
	assert new_size <= new_capacity
	allocation := storage.allocator.reallocate(entry.allocation, entry.size, new_size, new_capacity, zero_fill, force_large)!
	storage.allocator.deallocate(mut entry.allocation)
	entry.allocation = allocation
	entry.size = new_size
}

pub fn (mut storage PrimitiveStorage) free_handle(handle ExternalEntityTableHandle) {
	mut entry := storage.entry_for(handle)
	if entry == unsafe { nil } { return }
	storage.allocator.deallocate(mut entry.allocation)
	entry.size = 0
	storage.table.free_entry(handle, primitive_storage_tag)
}

fn (storage &PrimitiveStorage) entry_for(handle ExternalEntityTableHandle) &PrimitiveStorageEntry {
	if !storage.table.is_valid(handle, primitive_storage_tag) { return unsafe { nil } }
	assert u64(handle.index) < u64(storage.entries.len)
	return unsafe { &storage.entries[int(handle.index)] }
}

fn (storage &PrimitiveStorage) data_unchecked(entry &PrimitiveStorageEntry) &u8 {
	return storage.allocator.data(entry.allocation, 0)
}

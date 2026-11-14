// Copyright (c) 2020-2022, Linus Groh <linusg@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Runtime/ArrayBuffer.h::DataBlock and ArrayBuffer.cpp::CreateByteDataBlock.
module libjs

import libgc
import math

@[heap]
pub struct ByteBufferStorage {
pub mut:
	bytes []u8
}

pub enum DataBlockKind {
	empty
	owned
	unowned_fixed
	external_primitive
}

// Source GC::Ref<Cell> at the pending LibGC cell boundary: owner is the actual
// retained owner address, never a serialized ID or replacement host record.
pub struct ExternalPrimitiveBackingStore {
pub:
	owner      voidptr
	handle     libgc.ExternalEntityTableHandle
	fixed_size ?uint
}

pub fn (storage ExternalPrimitiveBackingStore) data() &u8 {
	return libgc.PrimitiveStorage.the().data(storage.handle)
}

pub fn (storage ExternalPrimitiveBackingStore) byte_length() uint {
	return storage.fixed_size or { libgc.PrimitiveStorage.the().size(storage.handle) }
}

pub fn (storage ExternalPrimitiveBackingStore) capacity() uint {
	return libgc.PrimitiveStorage.the().capacity(storage.handle)
}

pub fn (storage ExternalPrimitiveBackingStore) offset() uint {
	return libgc.PrimitiveStorage.the().offset(storage.handle)
}

pub struct DataBlockBytes {
pub:
	data &u8 = unsafe { nil }
	size uint
}

pub struct DataBlock {
	kind         DataBlockKind
	owned        ?&OwnedPrimitiveBackingStore
	storage      ?&ByteBufferStorage
	fixed_length uint
	external     ExternalPrimitiveBackingStore
pub:
	is_shared bool
}

pub fn DataBlock.from_owned_store(storage &OwnedPrimitiveBackingStore, is_shared bool) DataBlock {
	return DataBlock{ kind: .owned, owned: storage, is_shared: is_shared }
}

pub fn DataBlock.from_bytes(bytes []u8, is_shared bool) DataBlock {
	owner := OwnedPrimitiveBackingStore.create_uninitialized(uint(bytes.len)) or { panic(err) }
	mut block := DataBlock.from_owned_store(owner, is_shared)
	block.overwrite(0, bytes)
	return block
}

pub fn DataBlock.from_host_buffer(storage &ByteBufferStorage, is_shared bool) DataBlock {
	return DataBlock{ kind: .unowned_fixed, storage: storage, fixed_length: uint(storage.bytes.len), is_shared: is_shared }
}

pub fn DataBlock.from_external_primitive_storage(owner voidptr, handle libgc.ExternalEntityTableHandle, fixed_size ?uint, is_shared bool) DataBlock {
	assert owner != unsafe { nil }
	return DataBlock{
		kind:      .external_primitive
		external:  ExternalPrimitiveBackingStore{
			owner:      owner
			handle:     handle
			fixed_size: fixed_size
		}
		is_shared: is_shared
	}
}

pub fn (block DataBlock) is_empty() bool { return block.kind == .empty }

pub fn (block DataBlock) is_external() bool { return block.kind == .external_primitive }

pub fn (block DataBlock) size() uint {
	return match block.kind {
		.empty { 0 }
		.owned { (block.owned or { panic('data block without owner') }).size() }
		.unowned_fixed { block.fixed_length }
		.external_primitive { block.external.byte_length() }
	}
}

pub fn (block DataBlock) capacity() uint {
	return match block.kind {
		.empty { 0 }
		.owned { (block.owned or { panic('data block without owner') }).capacity() }
		.unowned_fixed { block.fixed_length }
		.external_primitive { block.external.capacity() }
	}
}

pub fn (block DataBlock) offset() uint {
	return match block.kind {
		.empty, .unowned_fixed { libgc.primitive_storage_invalid_offset }
		.owned { (block.owned or { panic('data block without owner') }).offset() }
		.external_primitive { block.external.offset() }
	}
}

pub fn (block DataBlock) is_caged() bool {
	return match block.kind {
		.empty, .unowned_fixed { false }
		.owned {
			owner := block.owned or { panic('data block without owner') }
			owner.handle().is_valid() || owner.size() == 0
		}
		.external_primitive { block.external.handle.is_valid() }
	}
}

pub fn (block DataBlock) external_memory_size() uint {
	return if block.kind == .owned { block.capacity() } else { 0 }
}

fn (block DataBlock) data() &u8 {
	return match block.kind {
		.empty { panic('empty data block has no data') }
		.owned { (block.owned or { panic('data block without owner') }).data() }
		.unowned_fixed {
			unsafe { &u8((block.storage or { panic('data block without host storage') }).bytes.data) }
		}
		.external_primitive { block.external.data() }
	}
}

pub fn (block DataBlock) data_at(byte_offset uint) &u8 {
	match block.kind {
		.empty { panic('empty data block has no data') }
		.owned {
			owner := block.owned or { panic('data block without owner') }
			if !owner.handle().is_valid() {
				assert byte_offset == 0
				return unsafe { nil }
			}
			return libgc.PrimitiveStorage.the().data_at(owner.handle(), byte_offset)
		}
		.unowned_fixed { return unsafe { block.data() + byte_offset } }
		.external_primitive {
			return libgc.PrimitiveStorage.the().data_at(block.external.handle, byte_offset)
		}
	}
}

pub fn (block DataBlock) contiguous_bytes_from(byte_offset uint, count uint) uint {
	if !block.is_caged() || count == 0 { return count }
	data_offset := block.offset()
	if data_offset == libgc.primitive_storage_invalid_offset { return count }
	caged_offset := libgc.mask_primitive_storage_offset(data_offset + byte_offset)
	return math.min(count, libgc.primitive_storage_default_cage_size - caged_offset)
}

pub fn (block DataBlock) contiguous_bytes_before(byte_offset uint, count uint) uint {
	if !block.is_caged() || count == 0 { return count }
	assert byte_offset > 0
	data_offset := block.offset()
	if data_offset == libgc.primitive_storage_invalid_offset { return count }
	caged_offset := libgc.mask_primitive_storage_offset(data_offset + byte_offset - 1)
	return math.min(count, caged_offset + 1)
}

fn (block DataBlock) check_range(offset uint, count uint) {
	assert offset <= block.size() && count <= block.size() - offset
}

pub fn (block DataBlock) copy_to_bytes(offset uint, destination DataBlockBytes) {
	block.check_range(offset, destination.size)
	mut copied := uint(0)
	for copied < destination.size {
		chunk_size := block.contiguous_bytes_from(offset + copied, destination.size - copied)
		unsafe { C.memcpy(destination.data + copied, block.data_at(offset + copied), chunk_size) }
		copied += chunk_size
	}
}

// The V vector result has signed-int length; the native DataBlock itself does
// not narrow its size/capacity or byte offsets to the vector representation.
pub fn (block DataBlock) read_bytes(offset uint, count uint) []u8 {
	block.check_range(offset, count)
	assert count <= uint(0x7fffffff)
	mut result := []u8{len: int(count)}
	block.copy_to_bytes(offset, DataBlockBytes{ data: unsafe { &u8(result.data) }, size: count })
	return result
}

pub fn (block DataBlock) with_readonly_bytes[T](offset uint, count uint, callback fn (DataBlockBytes) T) T {
	block.check_range(offset, count)
	if count == 0 { return callback(DataBlockBytes{}) }
	// A shared block may change while the callback is reading. Give it a
	// snapshot even when the requested bytes are contiguous in the backing store.
	if !block.is_shared && block.contiguous_bytes_from(offset, count) == count {
		return callback(DataBlockBytes{ data: block.data_at(offset), size: count })
	}
	storage := block.read_bytes(offset, count)
	return callback(DataBlockBytes{ data: unsafe { &u8(storage.data) }, size: count })
}

pub fn (mut block DataBlock) overwrite_from(offset uint, source &u8, count uint) {
	block.check_range(offset, count)
	mut copied := uint(0)
	for copied < count {
		chunk_size := block.contiguous_bytes_from(offset + copied, count - copied)
		unsafe { C.memcpy(block.data_at(offset + copied), source + copied, chunk_size) }
		copied += chunk_size
	}
}

pub fn (mut block DataBlock) overwrite(offset uint, bytes []u8) {
	block.overwrite_from(offset, unsafe { &u8(bytes.data) }, uint(bytes.len))
}

pub fn (block DataBlock) shares_storage_with(other DataBlock) bool {
	if block.is_empty() || other.is_empty() { return false }
	return block.data() == other.data()
}

pub fn (block DataBlock) copy_to(mut destination DataBlock, source_offset uint, destination_offset uint, count uint) {
	block.check_range(source_offset, count)
	destination.check_range(destination_offset, count)
	mut copied := uint(0)
	for copied < count {
		source_chunk := block.contiguous_bytes_from(source_offset + copied, count - copied)
		destination_chunk := destination.contiguous_bytes_from(destination_offset + copied, count - copied)
		chunk_size := math.min(source_chunk, destination_chunk)
		unsafe { C.memcpy(destination.data_at(destination_offset + copied), block.data_at(source_offset + copied), chunk_size) }
		copied += chunk_size
	}
}

pub fn (mut block DataBlock) move_data(destination_offset uint, source_offset uint, count uint) {
	block.check_range(destination_offset, count)
	block.check_range(source_offset, count)
	if count == 0 || destination_offset == source_offset { return }
	if !block.is_caged() {
		unsafe { C.memmove(block.data_at(destination_offset), block.data_at(source_offset), count) }
		return
	}
	if source_offset < destination_offset && destination_offset < source_offset + count {
		mut remaining := count
		for remaining > 0 {
			source_chunk := block.contiguous_bytes_before(source_offset + remaining, remaining)
			destination_chunk := block.contiguous_bytes_before(destination_offset + remaining, remaining)
			chunk_size := math.min(source_chunk, destination_chunk)
			remaining -= chunk_size
			unsafe { C.memmove(block.data_at(destination_offset + remaining), block.data_at(source_offset + remaining), chunk_size) }
		}
		return
	}
	mut copied := uint(0)
	for copied < count {
		source_chunk := block.contiguous_bytes_from(source_offset + copied, count - copied)
		destination_chunk := block.contiguous_bytes_from(destination_offset + copied, count - copied)
		chunk_size := math.min(source_chunk, destination_chunk)
		unsafe { C.memmove(block.data_at(destination_offset + copied), block.data_at(source_offset + copied), chunk_size) }
		copied += chunk_size
	}
}

pub fn (mut block DataBlock) set_size(new_size uint, zero_fill_new_bytes bool) {
	match block.kind {
		.empty, .external_primitive { panic('this data block cannot resize') }
		.owned {
			mut owner := block.owned or { panic('data block without owner') }
			owner.set_size(new_size, if zero_fill_new_bytes { .yes } else { .no })
		}
		.unowned_fixed {
			storage := block.storage or { panic('data block without host storage') }
			assert new_size <= uint(storage.bytes.cap)
			if !block.try_resize(new_size, zero_fill_new_bytes) {
				panic('host buffer resize failed')
			}
		}
	}
}

pub fn (mut block DataBlock) try_resize(size uint, zero_fill_new_bytes bool) bool {
	match block.kind {
		.empty, .external_primitive { panic('this data block cannot resize') }
		.owned {
			mut owner := block.owned or { panic('data block without owner') }
			owner.try_resize(size, if zero_fill_new_bytes { .yes } else { .no }) or { return false }
			return true
		}
		.unowned_fixed {
			if size > 0x7fffffff { return false }
			mut storage := block.storage or { panic('data block without host storage') }
			old_size := storage.bytes.len
			if int(size) <= old_size {
				storage.bytes.trim(int(size))
			} else {
				unsafe { storage.bytes.grow_len(int(size) - old_size) }
				if zero_fill_new_bytes {
					for index in old_size .. int(size) { storage.bytes[index] = 0 }
				}
			}
			return true
		}
	}
}

pub fn copy_data_block_bytes(mut destination DataBlock, destination_offset uint, source DataBlock, source_offset uint, count uint) {
	if count > 0 {
		assert !destination.shares_storage_with(source)
	}
	source.copy_to(mut destination, source_offset, destination_offset, count)
}

pub fn (mut block DataBlock) try_ensure_capacity(capacity uint) bool {
	match block.kind {
		.empty, .external_primitive { panic('this data block cannot reserve capacity') }
		.owned {
			mut owner := block.owned or { panic('data block without owner') }
			owner.try_ensure_capacity(capacity) or { return false }
			return true
		}
		.unowned_fixed {
			if capacity > 0x7fffffff { return false }
			mut storage := block.storage or { panic('data block without host storage') }
			storage.bytes.ensure_cap(int(capacity))
			return true
		}
	}
}

// Explicit native-owner destruction until the source LibGC heap finalizes
// ArrayBuffer cells. External and unowned variants do not free their owner.
pub fn (mut block DataBlock) destroy() {
	if block.kind == .owned {
		mut owner := block.owned or { panic('data block without owner') }
		owner.destroy()
	}
	block = DataBlock{ is_shared: block.is_shared }
}

pub fn create_byte_data_block(mut vm VM, size uint, capacity ?uint) !DataBlock {
	if size > 9007199254740991 || (capacity or { uint(0) }) > 9007199254740991 {
		return vm.throw_error_type(.range_error, .invalid_length, 'array buffer')
	}
	mut owner := &OwnedPrimitiveBackingStore{}
	if limit := capacity {
		owner = OwnedPrimitiveBackingStore.create_zeroed_with_capacity(size, limit) or {
			return vm.throw_error_type(.range_error, .not_enough_memory_to_allocate, limit.str())
		}
	} else {
		owner = OwnedPrimitiveBackingStore.create_zeroed(size) or {
			return vm.throw_error_type(.range_error, .not_enough_memory_to_allocate, size.str())
		}
	}
	return DataBlock.from_owned_store(owner, false)
}

fn create_zeroed_owned_data_block(mut vm VM, size uint, requested_capacity uint) !DataBlock {
	owner := OwnedPrimitiveBackingStore.create_zeroed_with_capacity(size, requested_capacity) or {
		return vm.throw_error_type(.range_error, .not_enough_memory_to_allocate, requested_capacity.str())
	}
	return DataBlock.from_owned_store(owner, false)
}

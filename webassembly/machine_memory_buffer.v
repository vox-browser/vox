// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm/AbstractMachine/AbstractMachine.{h,cpp}: MemoryBuffer.
module webassembly

import libgc
import math

pub struct BinaryMachineBytes {
pub:
	data &u8 = unsafe { nil }
	size uint
}

pub fn (bytes BinaryMachineBytes) at(index uint) &u8 {
	if index >= bytes.size {
		panic('Source VERIFY: Span::at index < m_size')
	}
	return unsafe { bytes.data + index }
}

@[heap]
pub struct BinaryMachineMemoryBuffer {
mut:
	size_              uint
	reserved_capacity_ uint
	handle_            libgc.ExternalEntityTableHandle
	storage_offset_    uint = libgc.primitive_storage_invalid_offset
}

pub fn BinaryMachineMemoryBuffer.create() &BinaryMachineMemoryBuffer {
	return &BinaryMachineMemoryBuffer{}
}

pub fn (mut buffer BinaryMachineMemoryBuffer) destroy() { buffer.clear() }

pub fn (mut buffer BinaryMachineMemoryBuffer) move_from(mut other BinaryMachineMemoryBuffer) {
	if voidptr(&buffer) == voidptr(&other) { return }
	buffer.clear()
	buffer.size_ = other.size_
	buffer.reserved_capacity_ = other.reserved_capacity_
	buffer.handle_ = other.handle_
	buffer.storage_offset_ = other.storage_offset_
	other.size_ = 0
	other.reserved_capacity_ = 0
	other.handle_ = libgc.ExternalEntityTableHandle{}
	other.storage_offset_ = libgc.primitive_storage_invalid_offset
}

fn (mut buffer BinaryMachineMemoryBuffer) clear() {
	if buffer.handle_.is_valid() {
		mut storage := libgc.PrimitiveStorage.the()
		storage.free_handle(buffer.handle_)
	}
	buffer.reserved_capacity_ = 0
	buffer.size_ = 0
	buffer.handle_ = libgc.ExternalEntityTableHandle{}
	buffer.storage_offset_ = libgc.primitive_storage_invalid_offset
}

fn (mut buffer BinaryMachineMemoryBuffer) update_storage_offset() {
	buffer.storage_offset_ = libgc.PrimitiveStorage.the().offset(buffer.handle_)
}

pub fn (mut buffer BinaryMachineMemoryBuffer) try_reserve(capacity uint, guard_size uint) ! {
	mut storage := libgc.PrimitiveStorage.the()
	if buffer.handle_.is_valid() {
		if capacity <= buffer.reserved_capacity_ { return }
		storage.try_reserve_handle(buffer.handle_, capacity)!
		buffer.reserved_capacity_ = storage.capacity(buffer.handle_)
		buffer.update_storage_offset()
		return
	}
	buffer.handle_ = storage.try_reserve(0, capacity, .yes, guard_size)!
	buffer.reserved_capacity_ = capacity
	buffer.update_storage_offset()
}

pub fn (mut buffer BinaryMachineMemoryBuffer) try_resize(new_size uint) ! {
	if new_size < buffer.size_ {
		panic('Source VERIFY: MemoryBuffer::try_resize new_size >= m_size')
	}
	mut storage := libgc.PrimitiveStorage.the()
	if buffer.handle_.is_valid() {
		storage.try_resize(buffer.handle_, new_size, .yes)!
		buffer.reserved_capacity_ = storage.capacity(buffer.handle_)
		buffer.size_ = new_size
		buffer.update_storage_offset()
		return
	}
	if new_size == 0 { return }
	capacity := math.max(new_size, buffer.reserved_capacity_)
	buffer.handle_ = storage.try_reserve(new_size, capacity, .yes, 0)!
	buffer.reserved_capacity_ = capacity
	buffer.size_ = new_size
	buffer.update_storage_offset()
}

pub fn (mut buffer BinaryMachineMemoryBuffer) try_resize_with_capacity(new_size uint, reserved_capacity uint) ! {
	if new_size < buffer.size_ {
		panic('Source VERIFY: MemoryBuffer::try_resize(new_size, reserved_capacity) new_size >= m_size')
	}
	if new_size > reserved_capacity {
		panic('Source VERIFY: MemoryBuffer::try_resize(new_size, reserved_capacity) new_size <= reserved_capacity')
	}
	mut storage := libgc.PrimitiveStorage.the()
	if buffer.handle_.is_valid() {
		storage.try_resize_and_reserve(buffer.handle_, new_size, reserved_capacity, .yes)!
		buffer.reserved_capacity_ = storage.capacity(buffer.handle_)
		buffer.size_ = new_size
		buffer.update_storage_offset()
		return
	}
	if reserved_capacity == 0 { return }
	buffer.handle_ = storage.try_reserve(new_size, reserved_capacity, .yes, 0)!
	buffer.reserved_capacity_ = reserved_capacity
	buffer.size_ = new_size
	buffer.update_storage_offset()
}

pub fn (buffer &BinaryMachineMemoryBuffer) size() uint { return buffer.size_ }

pub fn (buffer &BinaryMachineMemoryBuffer) capacity() uint { return buffer.reserved_capacity_ }

pub fn (buffer &BinaryMachineMemoryBuffer) data() &u8 {
	return libgc.PrimitiveStorage.the().data(buffer.handle_)
}

pub fn (buffer &BinaryMachineMemoryBuffer) storage_offset() uint { return buffer.storage_offset_ }

pub fn (buffer &BinaryMachineMemoryBuffer) primitive_storage_handle() libgc.ExternalEntityTableHandle {
	return buffer.handle_
}

pub fn (buffer &BinaryMachineMemoryBuffer) bytes() BinaryMachineBytes {
	return BinaryMachineBytes{ data: buffer.data(), size: buffer.size() }
}

pub fn (buffer &BinaryMachineMemoryBuffer) span() BinaryMachineBytes { return buffer.bytes() }

pub fn (buffer &BinaryMachineMemoryBuffer) offset_pointer(offset uint) &u8 {
	if buffer.storage_offset_ == libgc.primitive_storage_invalid_offset { return unsafe { nil } }
	cage_base := libgc.PrimitiveStorage.the().cage_base()
	if cage_base == unsafe { nil } {
		panic('Source VERIFY: MemoryBuffer::offset_pointer cage_base')
	}
	return unsafe { cage_base + libgc.mask_primitive_storage_offset(buffer.storage_offset_ + offset) }
}

pub fn (buffer &BinaryMachineMemoryBuffer) at(index uint) &u8 {
	return buffer.offset_pointer(index)
}

pub fn (buffer &BinaryMachineMemoryBuffer) contiguous_bytes_from(offset uint, count uint) uint {
	if count == 0 || buffer.storage_offset_ == libgc.primitive_storage_invalid_offset {
		return count
	}
	caged_offset := libgc.mask_primitive_storage_offset(buffer.storage_offset_ + offset)
	return math.min(count, libgc.primitive_storage_default_cage_size - caged_offset)
}

pub fn (buffer &BinaryMachineMemoryBuffer) contiguous_bytes_before(offset uint, count uint) uint {
	if count == 0 || buffer.storage_offset_ == libgc.primitive_storage_invalid_offset {
		return count
	}
	if offset == 0 {
		panic('Source VERIFY: MemoryBuffer::contiguous_bytes_before offset > 0')
	}
	caged_offset := libgc.mask_primitive_storage_offset(buffer.storage_offset_ + offset - 1)
	return math.min(count, caged_offset + 1)
}

pub fn (buffer &BinaryMachineMemoryBuffer) copy_to(offset uint, destination BinaryMachineBytes) {
	// Source VERIFY remains active when ordinary V asserts are stripped.
	if offset > buffer.size() {
		panic('Source VERIFY: MemoryBuffer::copy_to offset <= size()')
	}
	if destination.size > buffer.size() - offset {
		panic('Source VERIFY: MemoryBuffer::copy_to destination.size() <= size() - offset')
	}
	mut copied := uint(0)
	for copied < destination.size {
		chunk_size := buffer.contiguous_bytes_from(offset + copied, destination.size - copied)
		unsafe { C.memcpy(destination.data + copied, buffer.offset_pointer(offset + copied), chunk_size) }
		copied += chunk_size
	}
}

pub fn (mut buffer BinaryMachineMemoryBuffer) copy_from(source &BinaryMachineMemoryBuffer, source_offset uint, destination_offset uint, count uint) {
	if source_offset > source.size() {
		panic('Source VERIFY: MemoryBuffer::copy_from source_offset <= source.size()')
	}
	if count > source.size() - source_offset {
		panic('Source VERIFY: MemoryBuffer::copy_from count <= source.size() - source_offset')
	}
	if destination_offset > buffer.size() {
		panic('Source VERIFY: MemoryBuffer::copy_from destination_offset <= size()')
	}
	if count > buffer.size() - destination_offset {
		panic('Source VERIFY: MemoryBuffer::copy_from count <= size() - destination_offset')
	}
	if voidptr(source) == voidptr(&buffer) {
		buffer.move_data(destination_offset, source_offset, count)
		return
	}
	mut copied := uint(0)
	for copied < count {
		chunk_size := math.min(source.contiguous_bytes_from(source_offset + copied, count - copied), buffer.contiguous_bytes_from(destination_offset + copied, count - copied))
		unsafe { C.memcpy(buffer.offset_pointer(destination_offset + copied), source.offset_pointer(source_offset + copied), chunk_size) }
		copied += chunk_size
	}
}

pub fn (mut buffer BinaryMachineMemoryBuffer) fill(offset uint, value u8, count uint) {
	if offset > buffer.size() {
		panic('Source VERIFY: MemoryBuffer::fill offset <= size()')
	}
	if count > buffer.size() - offset {
		panic('Source VERIFY: MemoryBuffer::fill count <= size() - offset')
	}
	mut filled := uint(0)
	for filled < count {
		chunk_size := buffer.contiguous_bytes_from(offset + filled, count - filled)
		unsafe { C.memset(buffer.offset_pointer(offset + filled), value, chunk_size) }
		filled += chunk_size
	}
}

pub fn (mut buffer BinaryMachineMemoryBuffer) overwrite(offset uint, source voidptr, count uint) {
	if offset > buffer.size() {
		panic('Source VERIFY: MemoryBuffer::overwrite offset <= size()')
	}
	if count > buffer.size() - offset {
		panic('Source VERIFY: MemoryBuffer::overwrite count <= size() - offset')
	}
	source_bytes := unsafe { &u8(source) }
	mut copied := uint(0)
	for copied < count {
		chunk_size := buffer.contiguous_bytes_from(offset + copied, count - copied)
		unsafe { C.memcpy(buffer.offset_pointer(offset + copied), source_bytes + copied, chunk_size) }
		copied += chunk_size
	}
}

pub fn (mut buffer BinaryMachineMemoryBuffer) move_data(destination_offset uint, source_offset uint, count uint) {
	if destination_offset > buffer.size() {
		panic('Source VERIFY: MemoryBuffer::move_data destination_offset <= size()')
	}
	if count > buffer.size() - destination_offset {
		panic('Source VERIFY: MemoryBuffer::move_data count <= size() - destination_offset')
	}
	if source_offset > buffer.size() {
		panic('Source VERIFY: MemoryBuffer::move_data source_offset <= size()')
	}
	if count > buffer.size() - source_offset {
		panic('Source VERIFY: MemoryBuffer::move_data count <= size() - source_offset')
	}
	if count == 0 || destination_offset == source_offset { return }
	if source_offset < destination_offset && destination_offset < source_offset + count {
		mut remaining := count
		for remaining > 0 {
			chunk_size := math.min(buffer.contiguous_bytes_before(source_offset + remaining, remaining), buffer.contiguous_bytes_before(destination_offset + remaining, remaining))
			remaining -= chunk_size
			unsafe { C.memmove(buffer.offset_pointer(destination_offset + remaining), buffer.offset_pointer(source_offset + remaining), chunk_size) }
		}
		return
	}
	mut copied := uint(0)
	for copied < count {
		chunk_size := math.min(buffer.contiguous_bytes_from(source_offset + copied, count - copied), buffer.contiguous_bytes_from(destination_offset + copied, count - copied))
		unsafe { C.memmove(buffer.offset_pointer(destination_offset + copied), buffer.offset_pointer(source_offset + copied), chunk_size) }
		copied += chunk_size
	}
}

pub fn (buffer &BinaryMachineMemoryBuffer) contains_virtual_address(address voidptr) bool {
	if !buffer.handle_.is_valid() { return false }
	return libgc.PrimitiveStorage.the().contains_handle(buffer.handle_, address, 1)
}

pub fn BinaryMachineMemoryBuffer.storage_offset_offset() uint {
	return __offsetof(BinaryMachineMemoryBuffer, storage_offset_)
}

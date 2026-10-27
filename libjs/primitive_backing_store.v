// Copyright (c) 2020-2022, Linus Groh <linusg@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Runtime/ArrayBuffer.h: DataBlock::OwnedBackingStore.
module libjs

import libgc

// The source move-only owner keeps one actual PrimitiveStorage handle. V
// owners call destroy at their native-storage lifetime boundary. DataBlock's
// owned variant and ArrayBuffer allocations use this actual store.
@[heap]
pub struct OwnedPrimitiveBackingStore {
mut:
	handle_ libgc.ExternalEntityTableHandle
}

pub fn OwnedPrimitiveBackingStore.create_zeroed(size uint) !&OwnedPrimitiveBackingStore {
	mut buffer := &OwnedPrimitiveBackingStore{}
	if size > 0 {
		mut storage := libgc.PrimitiveStorage.the()
		buffer.handle_ = storage.try_allocate(size, .yes)!
	}
	return buffer
}

pub fn OwnedPrimitiveBackingStore.create_uninitialized(size uint) !&OwnedPrimitiveBackingStore {
	mut buffer := &OwnedPrimitiveBackingStore{}
	if size > 0 {
		mut storage := libgc.PrimitiveStorage.the()
		buffer.handle_ = storage.try_allocate(size, .no)!
	}
	return buffer
}

pub fn OwnedPrimitiveBackingStore.create_zeroed_with_capacity(size uint, capacity uint) !&OwnedPrimitiveBackingStore {
	mut buffer := &OwnedPrimitiveBackingStore{}
	if capacity > 0 {
		mut storage := libgc.PrimitiveStorage.the()
		buffer.handle_ = storage.try_reserve(size, capacity, .yes, 0)!
	}
	return buffer
}

pub fn (mut buffer OwnedPrimitiveBackingStore) destroy() {
	if buffer.handle_.is_valid() {
		mut storage := libgc.PrimitiveStorage.the()
		storage.free_handle(buffer.handle_)
	}
	buffer.handle_ = libgc.ExternalEntityTableHandle{}
}

pub fn (mut buffer OwnedPrimitiveBackingStore) move_from(mut other OwnedPrimitiveBackingStore) {
	if voidptr(&buffer) == voidptr(&other) { return }
	buffer.destroy()
	buffer.handle_ = other.handle_
	other.handle_ = libgc.ExternalEntityTableHandle{}
}

pub fn (buffer &OwnedPrimitiveBackingStore) data() &u8 {
	return libgc.PrimitiveStorage.the().data(buffer.handle_)
}

pub fn (buffer &OwnedPrimitiveBackingStore) size() uint {
	return libgc.PrimitiveStorage.the().size(buffer.handle_)
}

pub fn (buffer &OwnedPrimitiveBackingStore) capacity() uint {
	return libgc.PrimitiveStorage.the().capacity(buffer.handle_)
}

pub fn (buffer &OwnedPrimitiveBackingStore) offset() uint {
	return libgc.PrimitiveStorage.the().offset(buffer.handle_)
}

pub fn (buffer &OwnedPrimitiveBackingStore) handle() libgc.ExternalEntityTableHandle {
	return buffer.handle_
}

pub fn (mut buffer OwnedPrimitiveBackingStore) set_size(new_size uint, zero_fill_new_bytes libgc.ZeroFillNewBytes) {
	assert new_size <= buffer.capacity()
	buffer.try_resize(new_size, zero_fill_new_bytes) or { panic(err) }
}

pub fn (mut buffer OwnedPrimitiveBackingStore) try_resize(new_size uint, zero_fill_new_bytes libgc.ZeroFillNewBytes) ! {
	mut storage := libgc.PrimitiveStorage.the()
	if !buffer.handle_.is_valid() {
		if new_size == 0 { return }
		buffer.handle_ = storage.try_allocate(new_size, zero_fill_new_bytes)!
		return
	}
	storage.try_resize(buffer.handle_, new_size, zero_fill_new_bytes)!
}

pub fn (mut buffer OwnedPrimitiveBackingStore) try_ensure_capacity(new_capacity uint) ! {
	if new_capacity <= buffer.capacity() { return }
	mut storage := libgc.PrimitiveStorage.the()
	if !buffer.handle_.is_valid() {
		buffer.handle_ = storage.try_reserve(0, new_capacity, .no, 0)!
		return
	}
	storage.try_reserve_handle(buffer.handle_, new_capacity)!
}

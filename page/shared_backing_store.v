// Copyright (c) 2026, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Page/SharedBackingStore.{h,cpp}. The platform IPC attachment
// is represented by owned bytes; transfer consumes the sender exactly once.
module page

@[heap]
pub struct SharedBackingStore {
mut:
	bytes_    []u8
	released_ bool
}

pub fn SharedBackingStore.create(bytes []u8) &SharedBackingStore {
	return &SharedBackingStore{
		bytes_: bytes.clone()
	}
}

pub fn (store &SharedBackingStore) bytes() []u8 {
	return if store.released_ { []u8{} } else { store.bytes_.clone() }
}

pub fn (mut store SharedBackingStore) release() ![]u8 {
	if store.released_ {
		return error('backing store was already released')
	}
	store.released_ = true
	result := store.bytes_.clone()
	store.bytes_.clear()
	return result
}

pub fn decode_shared_backing_store(bytes []u8) &SharedBackingStore {
	return SharedBackingStore.create(bytes)
}

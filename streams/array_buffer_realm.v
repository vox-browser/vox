// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// ArrayBuffer/Uint8Array allocation and raw ArrayBuffer data belong to the
// relevant JS Realm. An installed native engine supplies actual records.
module streams

import webidl

pub fn (realm StreamRealm) array_buffer_value(bytes []u8) !webidl.Value {
	if create := realm.array_buffer_create { return create(bytes) }
	return webidl.buffer_source_value(webidl.BufferSource.array_buffer(bytes))
}

pub fn (realm StreamRealm) array_buffer_bytes(value webidl.Value) ![]u8 {
	if read_bytes := realm.array_buffer_copy { return read_bytes(value) }
	buffer := value.buffer_value or { panic('Source VERIFY: expected an ArrayBuffer') }
	assert buffer.kind == .array_buffer, 'Source VERIFY: expected an ArrayBuffer'
	return webidl.get_buffer_source_copy(buffer)
}

pub fn (realm StreamRealm) uint8_array_value(buffer webidl.Value) !webidl.Value {
	create := realm.uint8_array_create or { panic('Source Uint8Array creation requires its actual engine Realm') }
	return create(buffer)
}

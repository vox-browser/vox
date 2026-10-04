// Copyright (c) 2025-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// AK/Utf16String.cpp::from_ascii_without_validation and Utf16View projections.
module libjs

// Source copies short bytes inline or long bytes into Utf16StringData's ASCII
// allocation without validating them. Keep that owned byte sequence, including
// non-ASCII bytes and NUL; do not run the UTF8 decoder here.
pub fn utf16_string_from_ascii_without_validation(input []u8) Utf16String {
	bytes := input.clone()
	mut units := []u16{cap: bytes.len}
	for byte in bytes {
		// Utf16View.h::code_unit_at returns its plain char to char16_t.
		// V char uses the same native C char signedness as this Source ABI.
		units << u16(char(byte))
	}
	return Utf16String{
		data:           units
		ascii_storage_: true
		ascii_bytes_:   bytes
	}
}

// Existing standalone package code can edit code-unit storage internally.
// Such edits must not retain a stale unchecked-ASCII byte projection.
fn (text Utf16String) retained_ascii_bytes() ?[]u8 {
	if bytes := text.ascii_bytes_ {
		if bytes.len != text.data.len { return none }
		for index, byte in bytes {
			if text.data[index] != u16(char(byte)) { return none }
		}
		return bytes
	}
	return none
}

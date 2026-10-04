// Copyright (c) 2019-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// AK/Utf16String{,Data} and Utf8View's unvalidated byte boundary.
module libjs

fn utf8_view_leading_byte(byte u8) (int, u32, bool) {
	// Utf8View.h::utf8_encoded_byte_data/decode_leading_byte.
	for record in [[u8(1), 0x00, 0x80], [u8(2), 0xc0, 0xe0], [u8(3), 0xe0, 0xf0], [u8(4), 0xf0,
		0xf8]] {
		if byte & record[2] == record[1] {
			return int(record[0]), u32(byte & ~record[2]), true
		}
	}
	return 0, 0, false
}

// Utf16String::from_utf8_without_validation / Utf16StringData::from_utf8.
// Unlike the existing generic utf16() adapter, the Source fallback retains
// surrogate and overlong code points and advances by Utf8View's actual rules.
pub fn utf16_string_from_utf8_without_validation(text string) Utf16String {
	bytes := text.bytes()
	mut units := []u16{cap: bytes.len}
	mut ascii_storage := true
	mut index := 0
	for index < bytes.len {
		byte := bytes[index]
		if byte <= 0x7f {
			units << u16(byte)
			index++
			continue
		}
		ascii_storage = false
		length, initial, leading_valid := utf8_view_leading_byte(byte)
		mut length_valid := leading_valid && length <= bytes.len - index
		mut code_point := initial
		if length_valid {
			for offset in 1 .. length {
				if bytes[index + offset] >> 6 != 2 {
					length_valid = false
					break
				}
				code_point = (code_point << 6) | u32(bytes[index + offset] & 63)
			}
		}
		// operator* replaces an invalid value, while operator++ independently
		// uses the structurally valid byte length, even for > U+10FFFF.
		if !length_valid || code_point > 0x10ffff {
			code_point = 0xfffd
		}
		if code_point < 0x10000 {
			units << u16(code_point)
		} else {
			value := code_point - 0x10000
			units << u16(0xd800 | (value >> 10))
			units << u16(0xdc00 | (value & 0x3ff))
		}
		index += if length_valid { length } else { 1 }
	}
	return Utf16String{
		data:           units
		ascii_storage_: ascii_storage
	}
}

// AK/Utf16View.cpp::to_ascii_lowercase changes ASCII code units only.
pub fn (text Utf16String) to_ascii_lowercase() Utf16String {
	mut units := text.code_units()
	for index, unit in units {
		if unit >= 0x41 && unit <= 0x5a {
			units[index] = unit + 0x20
		}
	}
	return utf16_string_from_code_units(units)
}

// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// LibTextCodec/Encoder.cpp:221–258 and AK/Utf16View.h's code-point iterator.
module encoding

import libjs

// Source iterates code points, logs values above U+00FF and still casts each
// to a byte. Its range VERIFY is commented out, so preserve that behavior.
pub fn isomorphic_encode_utf16(input libjs.Utf16String) []u8 {
	units := input.code_units()
	mut output := []u8{cap: units.len}
	mut index := 0
	for index < units.len {
		mut code_point := u32(units[index])
		index++
		if code_point >= 0xd800 && code_point <= 0xdbff && index < units.len {
			trail := u32(units[index])
			if trail >= 0xdc00 && trail <= 0xdfff {
				code_point = 0x10000 + ((code_point - 0xd800) << 10) + trail - 0xdc00
				index++
			}
		}
		if code_point > 0xff {
			eprintln('FIXME: Trying to isomorphic encode a string with code points > U+00FF.')
		}
		output << u8(code_point)
	}
	return output
}

// The existing Source Utf8View boundary retains lonely/overlong code points
// and substitutes U+FFFD for invalid sequences before this same byte cast.
pub fn isomorphic_encode_utf8(input string) []u8 {
	return isomorphic_encode_utf16(libjs.utf16_string_from_utf8_without_validation(input))
}

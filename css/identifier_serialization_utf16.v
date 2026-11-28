// SPDX-License-Identifier: BSD-2-Clause
module css

// Serialize.cpp::serialize_an_identifier_to_utf16. All escape decisions concern
// ASCII; copying the remaining code units preserves astral pairs and lone
// surrogates at the CSSOMString boundary without a UTF-8 conversion.
pub fn serialize_an_identifier_utf16(units []u16) []u16 {
	mut result := []u16{cap: units.len}
	for index, unit in units {
		if unit == 0 { result << u16(0xfffd); continue }
		if (unit >= 1 && unit <= 0x1f) || unit == 0x7f || (index == 0 && unit >= `0` && unit <= `9`) || (index == 1 && units[0] == `-` && unit >= `0` && unit <= `9`) {
			result << u16(`\\`)
			for byte in '${unit:x}'.bytes() { result << u16(byte) }
			result << u16(` `)
			continue
		}
		if index == 0 && unit == `-` && units.len == 1 {
			result << [u16(`\\`), unit]
			continue
		}
		if unit >= 0x80 || unit == `-` || unit == `_` || (unit >= `0` && unit <= `9`) || (unit >= `a` && unit <= `z`) || (unit >= `A` && unit <= `Z`) {
			result << unit
			continue
		}
		result << [u16(`\\`), unit]
	}
	return result
}

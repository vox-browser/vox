// Copyright (c) 2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the BOM sniff of LibTextCodec/Decoder.cpp (bom_sniff_to_decoder) — the Encoding spec's
// "BOM sniff": inspect the leading bytes for a byte-order mark and return the encoding it indicates, or
// none. Upstream returns the corresponding decoder; here the encoding name is returned.
//
// Byte Order Mark | Encoding
// 0xEF 0xBB 0xBF  | UTF-8
// 0xFE 0xFF       | UTF-16BE
// 0xFF 0xFE       | UTF-16LE
// https://encoding.spec.whatwg.org/#bom-sniff
module encoding

pub fn bom_sniff(input []u8) ?string {
	if input.len < 2 {
		return none
	}
	first_byte := input[0]
	// UTF-8: EF BB BF (needs all three bytes).
	if first_byte == 0xEF {
		if input.len >= 3 && input[1] == 0xBB && input[2] == 0xBF {
			return 'UTF-8'
		}
		return none
	}
	// UTF-16BE: FE FF.
	if first_byte == 0xFE {
		if input[1] == 0xFF {
			return 'UTF-16BE'
		}
		return none
	}
	// UTF-16LE: FF FE.
	if first_byte == 0xFF {
		if input[1] == 0xFE {
			return 'UTF-16LE'
		}
		return none
	}
	return none
}

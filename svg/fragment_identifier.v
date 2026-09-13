// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

module svg

import url

// decode_fragment_identifier is the common SVG URL-fragment boundary. URL
// percent decoding produces bytes; SVG then decodes them as UTF-8 with
// replacement and deliberately does not treat a leading BOM specially.
pub fn decode_fragment_identifier(fragment string) string {
	return svg_utf8_with_replacement(url.percent_decode(fragment))
}

pub fn local_fragment_identifier(reference string) ?string {
	if !reference.starts_with('#') {
		return none
	}
	return decode_fragment_identifier(reference[1..])
}

fn append_svg_utf8_code_point(mut output []u8, code_point u32) {
	if code_point <= 0x7f {
		output << u8(code_point)
	} else if code_point <= 0x7ff {
		output << u8(0xc0 | (code_point >> 6))
		output << u8(0x80 | (code_point & 0x3f))
	} else if code_point <= 0xffff {
		output << u8(0xe0 | (code_point >> 12))
		output << u8(0x80 | ((code_point >> 6) & 0x3f))
		output << u8(0x80 | (code_point & 0x3f))
	} else {
		output << u8(0xf0 | (code_point >> 18))
		output << u8(0x80 | ((code_point >> 12) & 0x3f))
		output << u8(0x80 | ((code_point >> 6) & 0x3f))
		output << u8(0x80 | (code_point & 0x3f))
	}
}

fn append_svg_replacement_character(mut output []u8) {
	output << [u8(0xef), 0xbf, 0xbd]
}

fn svg_utf8_with_replacement(input []u8) string {
	mut output := []u8{cap: input.len}
	mut index := 0
	for index < input.len {
		first := input[index]
		if first <= 0x7f {
			output << first
			index++
			continue
		}
		mut continuation_count := 0
		mut code_point := u32(0)
		mut minimum := u32(0)
		if first >= 0xc2 && first <= 0xdf {
			continuation_count = 1
			code_point = u32(first & 0x1f)
			minimum = 0x80
		} else if first >= 0xe0 && first <= 0xef {
			continuation_count = 2
			code_point = u32(first & 0x0f)
			minimum = 0x800
		} else if first >= 0xf0 && first <= 0xf4 {
			continuation_count = 3
			code_point = u32(first & 0x07)
			minimum = 0x10000
		} else {
			append_svg_replacement_character(mut output)
			index++
			continue
		}
		if index + continuation_count >= input.len {
			append_svg_replacement_character(mut output)
			break
		}
		mut valid := true
		for offset in 1 .. continuation_count + 1 {
			continuation := input[index + offset]
			if continuation & 0xc0 != 0x80 {
				valid = false
				break
			}
			code_point = (code_point << 6) | u32(continuation & 0x3f)
		}
		if !valid || code_point < minimum || code_point > 0x10ffff
			|| (code_point >= 0xd800 && code_point <= 0xdfff) {
			append_svg_replacement_character(mut output)
			index++
			continue
		}
		append_svg_utf8_code_point(mut output, code_point)
		index += continuation_count + 1
	}
	return output.bytestr()
}

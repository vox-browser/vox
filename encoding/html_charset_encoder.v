// SPDX-License-Identifier: BSD-2-Clause
// Encoding Standard encoders with HTML numeric-reference error handling.
// Input is a scalar value string, as supplied by the FormData entry list.
module encoding

import encoding.iconv as viconv

pub struct HTMLCharsetEncoder {
	name string
	single_byte map[u32]u8
	jis0208 map[u32]u16
}

pub fn HTMLCharsetEncoder.create(label string) !HTMLCharsetEncoder {
	canonical := get_an_encoding(label) or { return error('Unsupported form encoding: ${label}') }
	name := if canonical.to_lower() in ['utf-16be', 'utf-16le', 'replacement'] { 'utf-8' } else { canonical.to_lower() }
	mut single := map[u32]u8{}
	mut jis := map[u32]u16{}
	if table := source_single_byte_table(name) {
		for index, value in table {
			if value != 0 && u32(value) !in single { single[u32(value)] = u8(index + 128) }
		}
	}
	if name == 'iso-2022-jp' {
		// The existing WHATWG JIS0208 decoder owns the index tables. Invert
		// its first 94 rows, retaining the first pointer for duplicate values.
		for pointer in 0 .. 8836 {
			trail := pointer % 188
			if value := source_shift_jis_trail_decode(u8(pointer / 188), u8(trail + if trail < 63 { 0x40 } else { 0x41 })) {
				if value != 0 && u32(value) !in jis { jis[u32(value)] = u16(pointer) }
			}
		}
	}
	return HTMLCharsetEncoder{name: name, single_byte: single, jis0208: jis}
}

// WHATWG index-iso-2022-jp-katakana, identifier
// 6ffc12c11f6eab1ccb3dada740d9b0db096ef0b0783c3bd5ec951dcb4a44b95e.
// https://encoding.spec.whatwg.org/index-iso-2022-jp-katakana.txt
const html_iso_2022_jp_katakana = [u32(0x3002), 0x300c, 0x300d, 0x3001, 0x30fb,
	0x30f2, 0x30a1, 0x30a3, 0x30a5, 0x30a7, 0x30a9, 0x30e3, 0x30e5, 0x30e7, 0x30c3,
	0x30fc, 0x30a2, 0x30a4, 0x30a6, 0x30a8, 0x30aa, 0x30ab, 0x30ad, 0x30af, 0x30b1,
	0x30b3, 0x30b5, 0x30b7, 0x30b9, 0x30bb, 0x30bd, 0x30bf, 0x30c1, 0x30c4, 0x30c6,
	0x30c8, 0x30ca, 0x30cb, 0x30cc, 0x30cd, 0x30ce, 0x30cf, 0x30d2, 0x30d5, 0x30d8,
	0x30db, 0x30de, 0x30df, 0x30e0, 0x30e1, 0x30e2, 0x30e4, 0x30e6, 0x30e8, 0x30e9,
	0x30ea, 0x30eb, 0x30ec, 0x30ed, 0x30ef, 0x30f3, 0x309b, 0x309c]

fn (encoder &HTMLCharsetEncoder) encode_iso_2022_jp(input string) []u8 {
	// 0 = ASCII, 1 = Roman, 2 = JIS0208. Every independently encoded string
	// finishes in ASCII; numeric references preserve Roman's safe ASCII bytes.
	mut state := 0
	mut output := []u8{}
	for scalar in input.runes() {
		mut point := u32(scalar)
		if point in [u32(0x0e), 0x0f, 0x1b] {
			if state == 2 { output << [u8(0x1b), 0x28, 0x42]; state = 0 }
			output << '&#65533;'.bytes()
			continue
		}
		if state == 1 && ((point < 128 && point !in [u32(0x5c), 0x7e]) || point in [u32(0xa5), 0x203e]) {
			output << u8(if point == 0xa5 { 0x5c } else if point == 0x203e { 0x7e } else { point })
			continue
		}
		if point < 128 {
			if state != 0 { output << [u8(0x1b), 0x28, 0x42]; state = 0 }
			output << u8(point)
			continue
		}
		if point in [u32(0xa5), 0x203e] {
			if state != 1 { output << [u8(0x1b), 0x28, 0x4a]; state = 1 }
			output << u8(if point == 0xa5 { 0x5c } else { 0x7e })
			continue
		}
		if point == 0x2212 { point = 0xff0d }
		if point >= 0xff61 && point <= 0xff9f { point = html_iso_2022_jp_katakana[int(point - 0xff61)] }
		if pointer := encoder.jis0208[point] {
			if state != 2 { output << [u8(0x1b), 0x24, 0x42]; state = 2 }
			output << [u8(pointer / 94 + 0x21), u8(pointer % 94 + 0x21)]
		} else {
			if state == 2 { output << [u8(0x1b), 0x28, 0x42]; state = 0 }
			output << '&#${point};'.bytes()
		}
	}
	if state != 0 { output << [u8(0x1b), 0x28, 0x42] }
	return output
}

pub fn (encoder &HTMLCharsetEncoder) encode(input string) ![]u8 {
	if encoder.name == 'utf-8' { return input.bytes() }
	if encoder.name == 'iso-2022-jp' { return encoder.encode_iso_2022_jp(input) }
	mut output := []u8{}
	if encoder.single_byte.len > 0 || encoder.name == 'x-user-defined' {
		for scalar in input.runes() {
			point := u32(scalar)
			if point < 128 { output << u8(point); continue }
			if encoder.name == 'x-user-defined' && point >= 0xf780 && point <= 0xf7ff {
				output << u8(point - 0xf780 + 128)
			} else if byte := encoder.single_byte[point] { output << byte }
			else { output << '&#${point};'.bytes() }
		}
		return output
	}
	// Other stateless legacy encoders retain the platform converter. Replace
	// unrepresentable scalars first, then encode the entire resulting string.
	mut representable := ''
	for scalar in input.runes() {
		text := scalar.str()
		if _ := viconv.vstring_to_encoding(text, encoder.name) { representable += text }
		else { representable += '&#${u32(scalar)};' }
	}
	return viconv.vstring_to_encoding(representable, encoder.name)
}

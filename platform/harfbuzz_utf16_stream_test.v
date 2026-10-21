module platform

fn test_harfbuzz_utf16_stream_matches_scalar_units_and_repairs() {
	texts := ['', 'ASCII \t\r\n\u0000', '字Á\u00a0\u2003', '😀𝄞', 'עברית العربية',
		'\ufeffa', [u8(0xff), 0x80, 0x20, 0x09].bytestr(),
		[u8(0xf0), 0x9f, 0x98].bytestr(), [u8(0xed), 0xa0, 0x80].bytestr()]
	expected := [ []u16{}, [u16(65), 83, 67, 73, 73, 32, 9, 13, 10, 0],
		[u16(0x5b57), 65, 0x301, 0xa0, 0x2003],
		[u16(0xd83d), 0xde00, 0xd834, 0xdd1e],
		[u16(0x5e2), 0x5d1, 0x5e8, 0x5d9, 0x5ea, 32, 0x627, 0x644, 0x639, 0x631, 0x628, 0x64a, 0x629],
		[u16(0xfeff), 97], [u16(0xfffd), 0xfffd, 32, 9],
		[u16(0xfffd), 0xfffd, 0xfffd], [u16(0xfffd), 0xfffd, 0xfffd] ]
	for index, text in texts {
		assert utf16_code_units(text) == expected[index]
		assert utf16_code_units(text) == utf16_units_for_shaping(text)
	}
	// The unchanged materializing decoder is an oracle for arbitrary byte strings.
	for first in 0 .. 256 {
		assert utf16_code_units([u8(first)].bytestr()) == utf16_units_for_shaping([u8(first)].bytestr())
		for second in 0 .. 256 {
			text := [u8(first), u8(second)].bytestr()
			assert utf16_code_units(text) == utf16_units_for_shaping(text)
		}
	}
	mut state := u32(169)
	for _ in 0 .. 1024 {
		mut bytes := []u8{}
		for _ in 0 .. 7 {
			state = state * 1664525 + 1013904223
			bytes << u8(state >> 24)
		}
		text := bytes.bytestr()
		assert utf16_code_units(text) == utf16_units_for_shaping(text)
	}
}

fn test_harfbuzz_utf16_stream_retains_bmp_and_surrogate_boundaries() {
	for code_point in [u32(0), 0x7f, 0x80, 0x7ff, 0x800, 0xd7ff, 0xe000, 0xffff,
		0x10000, 0x1f600, 0x10ffff] {
		text := rune(code_point).str()
		units := utf16_code_units(text)
		assert units == utf16_units_for_shaping(text)
		if code_point <= 0xffff {
			assert units == [u16(code_point)]
		} else {
			value := code_point - 0x10000
			assert units == [u16(0xd800 + (value >> 10)), u16(0xdc00 + (value & 0x3ff))]
		}
		assert code_point_at_utf16_offset(text, units, false, 0) == code_point
	}
}

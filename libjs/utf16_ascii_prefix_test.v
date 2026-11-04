module libjs

fn utf16_prefix_oracle(units []u16, lossy bool) []u8 {
	mut bytes := []u8{}
	mut i := 0
	for i < units.len {
		unit := units[i]
		mut code := u32(unit)
		if unit >= 0xd800 && unit <= 0xdbff && i + 1 < units.len
			&& units[i + 1] >= 0xdc00 && units[i + 1] <= 0xdfff {
			code = 0x10000 + ((u32(unit) - 0xd800) * 1024) + u32(units[i + 1]) - 0xdc00
			i++
		} else if unit >= 0xd800 && unit <= 0xdfff {
			code = if lossy { u32(0xfffd) } else { u32(unit) }
		}
		if code >= 0xd800 && code <= 0xdfff {
			// A scalar UTF-8 encoder rejects lone surrogates; WTF-8 preserves them.
			bytes << [u8(0xed), u8(0x80 + ((code >> 6) & 63)), u8(0x80 + (code & 63))]
		} else {
			bytes << rune(code).str().bytes()
		}
		i++
	}
	return bytes
}

fn test_utf16_ascii_prefix_preserves_every_single_code_unit_in_both_modes() {
	for value in 0 .. 0x10000 {
		units := [u16(value)]
		for lossy in [false, true] {
			assert encode_utf16(units, lossy).bytes() == utf16_prefix_oracle(units, lossy)
		}
	}
}

fn test_utf16_ascii_prefix_preserves_every_surrogate_pair_in_both_modes() {
	for high in 0xd800 .. 0xdc00 {
		for low in 0xdc00 .. 0xe000 {
			units := [u16(high), u16(low)]
			expected := utf16_prefix_oracle(units, false)
			assert encode_utf16(units, false).bytes() == expected
			assert encode_utf16(units, true).bytes() == expected
		}
	}
}

fn test_utf16_ascii_prefix_boundaries_nulls_and_unicode_tails() {
	for length in [0, 1, 7, 8, 15, 16, 31, 32, 63, 64, 127, 128, 4095, 4096] {
		prefix := []u16{len: length, init: u16(index % 128)}
		for tail in [ []u16{}, [u16(0x80)], [u16(0x7ff)], [u16(0x800)],
			[u16(0xd800)], [u16(0xdc00)], [u16(0xd83d), 0xde00],
			[u16(0xd800), 0xd800, 0xdc00, 0xdc00], [u16(0xffff), 0, 0x41] ] {
			mut units := prefix.clone()
			units << tail
			for lossy in [false, true] {
				assert encode_utf16(units, lossy).bytes() == utf16_prefix_oracle(units, lossy)
			}
		}
	}
}

fn test_utf16_ascii_prefix_reads_current_units_and_returns_owned_bytes() {
	mut text := utf16_string_from_code_units([u16(`A`), 0, `Z`])
	first := text.str()
	text.data[1] = 0xd800
	assert first.bytes() == [u8(`A`), 0, `Z`]
	assert text.str().bytes() == [u8(`A`), 0xed, 0xa0, 0x80, `Z`]
	text.data[1] = 0x80
	assert text.str().bytes() == [u8(`A`), 0xc2, 0x80, `Z`]
	text.data[1] = u16(`B`)
	assert text.str() == 'ABZ'
}

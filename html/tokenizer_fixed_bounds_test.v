module html

import strings

fn fixed_bound_rune_oracle(values []rune) string {
	mut builder := strings.new_builder(values.len)
	for value in values { builder.write_rune(value) }
	return builder.str()
}

fn test_fixed_rune_bounds_ignore_non_ascii_outside_borrowed_slices() {
	for offset in 0 .. 16 {
		for length in [0, 1, 2, 3, 4, 7, 8, 15, 16, 31, 32, 63, 64, 127, 128, 255, 256, 511, 512, 513] {
			mut backing := []rune{len: offset + length + 17, init: rune(-1)}
			mut expected := []u8{}
			for index in 0 .. length {
				value := u8((index * 37 + offset) % 128)
				backing[offset + index] = rune(value)
				expected << value
			}
			before := backing.clone()
			actual := runes_to_string(backing[offset..offset + length])
			assert actual.bytes() == expected
			assert actual.len == length
			assert unsafe { actual.str[actual.len] } == 0
			assert backing == before
		}
	}
}

fn test_fixed_rune_bounds_preserve_fallbacks_and_retained_slice_owners() {
	mut retained := []string{}
	mut expected := []string{}
	for offset in 0 .. 16 {
		for length in [1, 7, 16, 33, 129] {
			for position in [0, length / 2, length - 1] {
				for value in [0, 127, 128, 0x7ff, 0xd800, 0x10ffff, -1] {
					mut backing := []rune{len: offset + length + 17, init: rune(0x110000)}
					for index in 0 .. length { backing[offset + index] = `A` }
					backing[offset + position] = rune(value)
					view := backing[offset..offset + length]
					oracle := fixed_bound_rune_oracle(view)
					actual := runes_to_string(view)
					assert actual == oracle
					assert unsafe { actual.str[actual.len] } == 0
					backing[offset + position] = `Z`
					assert actual == oracle
					if position == 0 && length == 33 {
						retained << actual
						expected << oracle
					}
				}
			}
		}
	}
	gc_collect()
	assert retained == expected
}

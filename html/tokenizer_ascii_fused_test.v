module html

import strings

fn fused_rune_output_oracle(values []rune) string {
	mut output := strings.new_builder(values.len)
	for value in values { output.write_rune(value) }
	return output.str()
}

fn test_fused_ascii_output_preserves_controls_at_vector_boundaries() {
	for length in [0, 1, 2, 3, 4, 7, 8, 15, 16, 31, 32, 63, 64, 127, 128, 255, 256, 511, 512, 1024] {
		for pattern in [0, 1, 127] {
			mut values := []rune{}
			mut expected := []u8{}
			for index in 0 .. length {
				value := if pattern == 1 { index % 128 } else { pattern }
				values << rune(value)
				expected << u8(value)
			}
			before := values.clone()
			actual := runes_to_string(values)
			assert actual.bytes() == expected
			assert actual.len == length
			assert unsafe { actual.str[actual.len] } == 0
			assert values == before
		}
	}
}

fn test_fused_ascii_output_falls_back_for_high_bits_at_every_boundary() {
	for length in [1, 2, 3, 4, 7, 8, 15, 16, 31, 32, 63, 64, 127, 128, 255, 256] {
		for position in [0, length / 2, length - 1] {
			for code_point in [0, 127, 128, 255, 0x100, 0x7ff, 0x800, 0xd800, 0xdfff, 0x10000, 0x10ffff, 0x110000, -1] {
				mut values := []rune{len: length, init: `A`}
				values[position] = rune(code_point)
				before := values.clone()
				actual := runes_to_string(values)
				assert actual == fused_rune_output_oracle(before)
				assert unsafe { actual.str[actual.len] } == 0
				assert values == before
			}
		}
	}
}

fn test_fused_ascii_output_keeps_explicit_unicode_and_retained_owners() {
	expected := ['Alpha\u0000Beta', 'AβZ', '\u0000β😀\u0000', 'é中😀', 'last ASCII\u007f']
	mut retained := []string{}
	for text in expected {
		mut source := text.runes()
		retained << runes_to_string(source)
		source[0] = `X`
		assert retained.last() == text
	}
	for round in 0 .. 3 {
		for index in 0 .. 64 {
			_ = runes_to_string('replacement β ${round} ${index}'.runes())
		}
		gc_collect()
		for index, text in expected {
			assert retained[index] == text
			assert unsafe { retained[index].str[retained[index].len] } == 0
		}
	}
}

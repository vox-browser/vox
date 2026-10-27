module libjs

fn test_regex_input_search_and_literal_bounds_match_both_upstream_storage_paths() {
	for input in [
		RegexInput(RegexUtf16Input{
			units: [u16(0x61), 0, 0x7f, 0x62, 0x61]
		}),
		RegexAsciiInput{
			bytes: [u8(0x61), 0, 0x7f, 0x62, 0x61]
		},
	] {
		assert input.len() == 5 && !input.is_empty()
		assert input.code_unit(1) == 0
		assert input.find_code_unit(0, 5, 0x61)? == 0
		assert input.next_literal_start(1, 0x61)? == 4
		for bounds in [[uint(0), 0], [uint(5), 5], [uint(6), 6],
			[uint(4), 3], [uint(0), 6]] {
			assert input.find_code_unit(bounds[0], bounds[1], 0x61) == none
		}
		assert input.matches_u16_at(1, [u16(0), 0x7f, 0x62])
		assert !input.matches_u16_at(3, [u16(0x62), 0x62])
		assert input.matches_u16_at(5, []u16{})
		assert !input.matches_u16_at(6, []u16{})
		assert input.ends_with_u16([u16(0x62), 0x61]) && input.ends_with_u16([]u16{})
		assert !input.ends_with_u16([u16(1), 2, 3, 4, 5, 6])
		assert input.ranges_equal(0, 4, 1)
		assert !input.ranges_equal(0, 3, 1)
		assert input.ranges_equal(5, 5, 0)
	}
	for input in [RegexInput(RegexUtf16Input{}), RegexAsciiInput{}] {
		assert input.is_empty() && input.next_literal_start(0, 0) == none
		assert input.matches_u16_at(0, []u16{}) && input.ends_with_u16([]u16{})
	}
}

fn test_regex_input_retains_ascii_search_restriction_and_u16_optional_range_equality() {
	utf16_input := RegexInput(RegexUtf16Input{
		units: [u16(0x80), 0x80]
	})
	byte_input := RegexInput(RegexAsciiInput{
		bytes: [u8(0x80), 0x80]
	})
	assert utf16_input.code_unit(0) == byte_input.code_unit(0)
	assert utf16_input.find_code_unit(0, 2, 0x80)? == 0
	assert byte_input.find_code_unit(0, 2, 0x80) == none
	assert byte_input.find_code_unit(0, 2, 0x100) == none
	assert utf16_input.matches_u16_at(0, [u16(0x80)])
	assert !byte_input.matches_u16_at(0, [u16(0x80)]) && !byte_input.ends_with_u16([u16(0x80)])
	assert byte_input.ranges_equal(0, 1, 1)
	assert utf16_input.ranges_equal(3, 4, 1)
	assert !byte_input.ranges_equal(3, 4, 1)
	assert !utf16_input.ranges_equal(0, 4, 1)
	assert utf16_input.ranges_equal(2, 2, 1)
	assert !byte_input.ranges_equal(2, 2, 1)
}

fn test_regex_input_decodes_only_complete_forward_pairs_in_unicode_mode() {
	input := RegexInput(RegexUtf16Input{
		units: [u16(0xd800), 0x61, 0xdc00, 0xd83d, 0xde00, 0xdbff]
	})
	for position, expected in [u32(0xd800), 0x61, 0xdc00, 0x1f600, 0xde00, 0xdbff] {
		assert regex_decode_code_point(true, input, uint(position)) == expected
		width := if position == 3 { uint(2) } else { uint(1) }
		assert regex_code_point_len(true, input, uint(position)) == width
		assert regex_decode_code_point(false, input, uint(position)) == u32(input.code_unit(uint(position)))
		assert regex_code_point_len(false, input, uint(position)) == 1
	}
	byte_input := RegexInput(RegexAsciiInput{
		bytes: [u8(0), 0x7f, 0x80, 0xff]
	})
	for position in 0 .. 4 {
		assert regex_decode_code_point(true, byte_input, uint(position)) == u32(byte_input.code_unit(uint(position)))
		assert regex_code_point_len(true, byte_input, uint(position)) == 1
	}
}

fn test_regex_capture_copy_clips_both_buffers_and_search_advances_empty_matches_one_unit() {
	registers := [i32(0), 5, -1, -1, 2, 3]
	for count in [u32(0), 1, 2, 0xffffffff] {
		for length in 0 .. 9 {
			mut output := []i32{len: length, init: 99}
			regex_copy_captures_to_out(registers, count, mut output)
			for index, value in output {
				if index < registers.len && uint(index) < (uint(count) + 1) * 2 {
					assert value == registers[index]
				} else {
					assert value == 99
				}
			}
		}
	}
	assert regex_next_search_position(0, 0) == 1
	assert regex_next_search_position(3, 3) == 4
	assert regex_next_search_position(3, 7) == 7
	assert regex_next_search_position(0x7fffffff, 0x7fffffff) == uint(0x80000000)
	assert regex_match_limit == 10_000_000
}

fn test_regex_input_line_and_whitespace_classification_uses_exact_ecmascript_sets() {
	for point in [u32(0x9), 0xa, 0xb, 0xc, 0xd, 0x20, 0xa0, 0x1680, 0x2000, 0x2001, 0x200a, 0x2028,
		0x2029, 0x202f, 0x205f, 0x3000, 0xfeff] {
		assert regex_is_whitespace(point)
	}
	for point in [u32(0), 0x8, 0xe, 0x1f, 0x21, 0x85, 0x180e, 0x200b, 0x2060, 0xfffe, 0xd800,
		0x10ffff, 0x110000, 0xffffffff] {
		assert !regex_is_whitespace(point)
	}
	for point in [u32(0xa), 0xd, 0x2028, 0x2029] {
		assert regex_is_line_terminator(point)
	}
	for point in [u32(0x9), 0xb, 0xc, 0x85, 0x20, 0xfeff] {
		assert !regex_is_line_terminator(point)
	}
}

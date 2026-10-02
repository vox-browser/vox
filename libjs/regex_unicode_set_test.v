module libjs

fn test_regex_case_closure_preserves_order_capacity_and_unused_output() {
	for point, expected in {
		u32(0x6b):    [u32(0x4b), 0x6b, 0x212a]
		u32(0x73):    [u32(0x53), 0x73, 0x17f]
		u32(0x3c2):   [u32(0x3a3), 0x3c2, 0x3c3]
		u32(0xdf):    [u32(0xdf), 0x1e9e]
		u32(0xd800):  [u32(0xd800)]
		u32(0x10400): [u32(0x10400), 0x10428]
	} {
		for capacity in [0, 1, 2, 3, 16] {
			mut output := []u32{len: capacity, init: 0xffffffff}
			count := int(regex_get_case_closure(point, mut output))
			assert count == if capacity < expected.len {
				capacity
			} else {
				expected.len
			}
			assert output[..count] == expected[..count]
			assert output[count..].all(it == 0xffffffff)
		}
	}
	// ICU clamps an out-of-range UnicodeSet endpoint to its supported boundary.
	mut output := []u32{len: 16, init: 42}
	assert regex_get_case_closure(0x110000, mut output) == 1
	assert output[0] == 0x10ffff
	assert output[1..].all(it == 42)
}

fn test_regex_case_expansion_returns_sorted_ranges_and_owns_result_storage() {
	expected := [RegexCharRange{ start: 0x41, end: 0x5a }, RegexCharRange{ start: 0x61, end: 0x7a },
		RegexCharRange{ start: 0x17f, end: 0x17f }, RegexCharRange{ start: 0x212a, end: 0x212a }]
	mut ranges := regex_expand_range_case_insensitive(0x41, 0x5a)
	assert ranges == expected
	ranges[0].start = 0
	assert regex_expand_range_case_insensitive(0x41, 0x5a) == expected
	assert regex_expand_range_case_insensitive(0xdf, 0xdf) == [
		RegexCharRange{
			start: 0xdf
			end:   0xdf
		},
		RegexCharRange{
			start: 0x1e9e
			end:   0x1e9e
		},
	]
	assert regex_expand_range_case_insensitive(0x5a, 0x41).len == 0
}

fn test_regex_inverse_range_matching_keeps_legacy_canonicalization_filters() {
	for unicode in [false, true] {
		assert regex_code_point_matches_range_ignoring_case(0x61, 0x41, 0x5a, unicode)
		assert regex_code_point_matches_range_ignoring_case(0x41, 0x61, 0x7a, unicode)
		assert regex_code_point_matches_range_ignoring_case(0x3c2, 0x3a3, 0x3a3, unicode)
		assert !regex_code_point_matches_range_ignoring_case(0x30, 0x41, 0x5a, unicode)
		assert regex_code_point_matches_range_ignoring_case(0x17f, 0x73, 0x73, unicode) == unicode
		assert regex_code_point_matches_range_ignoring_case(0x73, 0x17f, 0x17f, unicode) == unicode
		assert regex_code_point_matches_range_ignoring_case(0x212a, 0x4b, 0x4b, unicode) == unicode
		assert regex_code_point_matches_range_ignoring_case(0xdf, 0x1e9e, 0x1e9e, unicode) == unicode
		assert regex_code_point_matches_range_ignoring_case(0xd800, 0xd800, 0xd800, unicode)
	}
}

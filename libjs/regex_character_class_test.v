module libjs

fn test_regex_range_membership_retains_inclusive_edges_and_large_set_search() {
	assert !regex_char_in_ranges(0, [])
	for count in [1, 8, 9, 16, 31] {
		mut ranges := []RegexCharRange{}
		for index in 0 .. count {
			ranges << RegexCharRange{
				start: u32(index * 4)
				end:   u32(index * 4 + 2)
			}
		}
		for point in 0 .. count * 4 + 2 {
			assert regex_char_in_ranges(u32(point), ranges) == (point < count * 4 && point % 4 != 3)
		}
	}
	assert regex_char_in_ranges(0xffffffff, [
		RegexCharRange{ start: 0xffffffff, end: 0xffffffff },
	])
	assert !regex_char_in_ranges(5, [RegexCharRange{ start: 9, end: 3 }])
}

fn test_regex_character_classes_use_inverse_folding_without_folding_range_endpoints() {
	upper := [RegexCharRange{ start: 0x41, end: 0x5a }]
	for unicode in [false, true] {
		assert !regex_match_char_class(0x61, upper, false, unicode, false)
		assert regex_match_char_class(0x61, upper, true, unicode, false)
		assert regex_match_char_class(0x17f, upper, true, unicode, false) == unicode
		assert regex_match_char_class(0x212a, upper, true, unicode, false) == unicode
		assert regex_match_char_class(0x73, [
			RegexCharRange{ start: 0x17f, end: 0x17f },
		], true, unicode, false) == unicode
		assert regex_match_char_class(0x3c3, [
			RegexCharRange{ start: 0x3c2, end: 0x3c2 },
		], true, unicode, false)
		// The fold of these endpoints reverses their order (Z..a -> z..a).
		mixed := [RegexCharRange{ start: 0x5a, end: 0x61 }]
		assert regex_match_char_class(0x7a, mixed, true, unicode, false)
		assert regex_match_char_class(0x41, mixed, true, unicode, false)
		assert !regex_match_char_class(0x62, mixed, true, unicode, false)
	}
}

fn test_regex_v_character_classes_use_case_closure_and_exclude_full_fold_strings() {
	for unicode in [false, true] {
		for pair in [[u32(0x73), 0x17f], [u32(0x6b), 0x212a],
			[u32(0xdf), 0x1e9e], [u32(0x10400), 0x10428]] {
			ranges := [RegexCharRange{ start: pair[1], end: pair[1] }]
			assert regex_match_char_class(pair[0], ranges, true, unicode, true)
			assert !regex_match_char_class(pair[0], ranges, false, unicode, true)
		}
		assert !regex_match_char_class(0xdf, [
			RegexCharRange{ start: 0x73, end: 0x73 },
		], true, unicode, true)
		assert regex_match_char_class(0xd800, [
			RegexCharRange{ start: 0xd800, end: 0xd800 },
		], true, unicode, true)
	}
}

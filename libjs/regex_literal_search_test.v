module libjs

fn test_regex_literal_search_retains_empty_bounds_overlapping_candidates_and_surrogates() {
	input := RegexInput(RegexUtf16Input{
		units: [u16(0x61), 0x61, 0x61, 0x62, 0xd800, 0xdc00]
	})
	assert regex_contains_u16_from(input, 1, [u16(0x61), 0x61, 0x62])
	assert !regex_contains_u16_from(input, 2, [u16(0x61), 0x61, 0x62])
	assert regex_contains_u16_from(input, 4, [u16(0xd800), 0xdc00])
	assert regex_contains_u16_from(input, 5, [u16(0xdc00)])
	assert !regex_contains_u16_from(input, 6, [u16(0xdc00)])
	assert regex_contains_u16_from(input, 100, [])
	assert !regex_contains_u16_from(input, 100, [u16(0x61)])
	assert !regex_contains_u16_from(input, 100, [u16(0x61), 0x62])
	bytes := RegexInput(RegexAsciiInput{
		bytes: [u8(0x61), 0x62, 0x80, 0x61, 0x62]
	})
	assert regex_contains_u16_from(bytes, 1, [u16(0x61), 0x62])
	assert !regex_contains_u16_from(bytes, 0, [u16(0x80)])
	assert !regex_contains_u16_from(bytes, 0, [u16(0x62), 0x80])
}

fn test_regex_ascii_case_insensitive_search_does_not_fold_non_ascii_or_utf16_surrogates() {
	input := RegexInput(RegexUtf16Input{
		units: [u16(0x80), 0x41, 0x61, 0x42, 0x212a, 0xd800]
	})
	assert regex_contains_ascii_case_insensitive_u16_from(input, 0, [u16(0x61), 0x42])
	assert regex_matches_ascii_case_insensitive_u16_at(input, 2, [u16(0x41), 0x62])
	assert !regex_matches_ascii_case_insensitive_u16_at(input, 0, [u16(0x80)])
	assert !regex_contains_ascii_case_insensitive_u16_from(input, 0, [u16(0x212a)])
	assert !regex_contains_ascii_case_insensitive_u16_from(input, 0, [u16(0xd800)])
	assert !regex_contains_ascii_case_insensitive_u16_from(input, 3, [u16(0x61), 0x62])
	assert regex_contains_ascii_case_insensitive_u16_from(input, 100, [])
	assert !regex_matches_ascii_case_insensitive_u16_at(input, 100, [])
	assert regex_matches_ascii_case_insensitive_u16_at(input, input.len(), [])
	assert regex_fold_ascii_for_compare(0x40) == 0x40 && regex_fold_ascii_for_compare(0x41) == 0x61
	assert regex_fold_ascii_for_compare(0x5a) == 0x7a && regex_fold_ascii_for_compare(0x5b) == 0x5b
	bytes := RegexInput(RegexAsciiInput{
		bytes: [u8(0x80), 0x41, 0x62]
	})
	assert regex_contains_ascii_case_insensitive_u16_from(bytes, 0, [u16(0x61), 0x42])
	assert !regex_matches_ascii_case_insensitive_u16_at(bytes, 0, [u16(0x80)])
}

fn test_regex_literal_prechecks_retain_optional_hints_and_search_start() {
	input := RegexInput(RegexUtf16Input{
		units: [u16(0x41), 0x62, 0x61, 0x62]
	})
	assert !regex_fails_trailing_literal_hint(input, RegexPatternHints{})
	assert !regex_fails_required_literal_hint(input, 0, RegexPatternHints{})
	mut hints := RegexPatternHints{
		trailing_literal: [u16(0x61), 0x62]
		required_literal: RegexRequiredLiteralHint{
			literal: [u16(0x61), 0x62]
		}
	}
	assert !regex_fails_trailing_literal_hint(input, hints)
	assert !regex_fails_required_literal_hint(input, 1, hints)
	assert regex_fails_required_literal_hint(input, 3, hints)
	hints.trailing_literal = [u16(0x41), 0x62]
	assert regex_fails_trailing_literal_hint(input, hints)
	hints.required_literal = RegexRequiredLiteralHint{
		literal:                [u16(0x41), 0x42]
		ascii_case_insensitive: true
	}
	assert !regex_fails_required_literal_hint(input, 1, hints)
	hints.required_literal = RegexRequiredLiteralHint{
		literal: []u16{}
	}
	assert !regex_fails_required_literal_hint(input, 100, hints)
}

fn test_regex_literal_start_hint_scans_one_or_two_units_with_input_start_priority() {
	input := RegexInput(RegexAsciiInput{
		bytes: [u8(0x78), 0x62, 0x61, 0x80]
	})
	mut hint := RegexStartPositionHint{
		includes_input_start: true
		literal_code_units:   [u16(0x61), 0x62]
	}
	assert regex_next_literal_start_from_hint(input, 0, hint)? == 0
	assert regex_next_literal_start_from_hint(input, 1, hint)? == 1
	assert regex_next_literal_start_from_hint(input, 2, hint)? == 2
	assert regex_next_literal_start_from_hint(input, 3, hint) == none
	hint.includes_input_start = false
	assert regex_next_literal_start_from_hint(input, 0, hint)? == 1
	hint.literal_code_units = [u16(0x80)]
	assert regex_next_literal_start_from_hint(input, 0, hint) == none
	// The two-unit scan compares raw units, unlike the one-unit ASCII search.
	hint.literal_code_units << u16(0x7f)
	assert regex_next_literal_start_from_hint(input, 0, hint)? == 3
	hint.literal_code_units.clear()
	assert regex_next_literal_start_from_hint(input, 0, hint) == none
	hint.literal_code_units = [u16(0x61), 0x62, 0x78]
	assert regex_next_literal_start_from_hint(input, 0, hint) == none
	hint.includes_input_start = true
	assert regex_next_literal_start_from_hint(input, 0, hint)? == 0
	assert regex_next_literal_start_from_hint(input, 100, hint) == none
}

module libjs

fn test_regex_candidate_first_character_uses_explicit_case_flag_and_utf16_pair_decoding() {
	input := RegexInput(RegexUtf16Input{
		units: [u16(0xd801), 0xdc00, 0x17f, 0x61, 0xd800]
	})
	for unicode in [false, true] {
		program := RegexProgram{
			unicode:     unicode
			ignore_case: true
		}
		assert regex_first_char_matches(program, input, 0, 0x10400, false) == unicode
		assert regex_first_char_matches(program, input, 0, 0xd801, false) == !unicode
		assert regex_first_char_matches(program, input, 0, 0x10428, true) == unicode
		assert regex_first_char_matches(program, input, 1, 0xdc00, false)
		assert regex_first_char_matches(program, input, 2, 0x53, true) == unicode
		assert !regex_first_char_matches(program, input, 3, 0x41, false)
		assert regex_first_char_matches(program, input, 3, 0x41, true)
		assert regex_first_char_matches(program, input, 4, 0xd800, false)
		assert !regex_first_char_matches(program, input, 5, 0, false)
		assert !regex_first_char_matches(program, input, 6, 0, true)
	}
	assert regex_first_char_matches(RegexProgram{}, RegexAsciiInput{ bytes: [u8(0x61)] }, 0, 0x41,
		true)
}

fn test_regex_candidate_first_filter_keeps_raw_literals_ranges_properties_and_source_dot_flag() {
	program := RegexProgram{
		unicode:      true
		unicode_sets: true
		ignore_case:  true
		dot_all:      true
	}
	input := RegexInput(RegexUtf16Input{
		units: [u16(0x61), 0x212a, 0xa, 0xd801, 0xdc00, 0x41]
	})
	assert !regex_first_filter_matches(program, input, 0, RegexLiteral{ code_point: 0x41 })
	assert regex_first_filter_matches(program, input, 0, RegexCharNoCase{ first: 0x41, second: 0x100 })
	assert !regex_first_filter_matches(program, input, 0, RegexBytecodeCharClass{
		ranges: [RegexCharRange{ start: 0x41, end: 0x5a }]
	})
	assert regex_first_filter_matches(program, input, 1, RegexBuiltinCharacterClass.word)
	assert !regex_first_filter_matches(program, input, 2, RegexAnyChar{})
	assert regex_first_filter_matches(program, input, 2, RegexAnyChar{ dot_all: true })
	assert regex_first_filter_matches(program, input, 3, RegexLiteral{ code_point: 0x10400 })
	assert !regex_first_filter_matches(program, input, 4, RegexLiteral{ code_point: 0x10400 })
	assert !regex_first_filter_matches(program, input, 5, RegexUnicodePropertyData{
		name: 'Lowercase'
	})
	assert regex_first_filter_matches(program, input, 5, RegexUnicodePropertyData{
		name:    'Lowercase'
		negated: true
	})
	assert regex_first_filter_matches(program, input, 5, RegexUnicodePropertyData{
		name:     'unknown'
		resolved: RegexResolvedProperty{
			kind: .binary_property
			id:   78
		}
	})
	left := RegexSimpleMatch(RegexLiteral{
		code_point: 0xa
	})
	right := RegexSimpleMatch(RegexBuiltinCharacterClass.word)
	assert regex_first_filter_matches(program, input, 2, RegexSimpleUnion{
		left:  &left
		right: &right
	})
}

fn test_regex_candidate_start_skips_surrogate_interiors_for_all_unicode_patterns() {
	input := RegexInput(RegexUtf16Input{
		units: [u16(0xd801), 0xdc00, 0xdc00]
	})
	for unicode in [false, true] {
		for can_match_empty in [false, true] {
			program := RegexProgram{
				unicode: unicode
			}
			hints := RegexPatternHints{
				can_match_empty: can_match_empty
			}
			expected := if unicode { uint(2) } else { uint(1) }
			assert regex_next_candidate_start(program, input, hints, 1)? == expected
			assert regex_next_candidate_start(program, input, hints, 2)? == 2
			assert regex_next_candidate_start(program, input, hints, 3)? == 3
			assert regex_next_candidate_start(program, input, hints, 4) == none
		}
	}
	assert regex_next_candidate_start(RegexProgram{}, RegexUtf16Input{}, RegexPatternHints{}, 0)? == 0
}

fn test_empty_regex_vm_searches_keep_unicode_surrogate_pairs_whole() {
	input := RegexInput(RegexUtf16Input{ units: [u16(0xd83d), 0xde00] })
	for mode in 0 .. 3 {
		mut engine := RegexEngine.compile('(?:)'.runes(), RegexAstFlags{
			unicode: mode == 1
			unicode_sets: mode == 2
		})!
		mut output := []i32{len: 6, init: -1}
		count := engine.find_all(input, 0, mut output)
		assert count == if mode == 0 { 3 } else { 2 }
		if mode == 0 {
			assert output == [i32(0), 0, 1, 1, 2, 2]
		} else {
			assert output[..4] == [i32(0), 0, 2, 2]
		}
	}
}

fn test_regex_candidate_anchor_hints_test_previous_code_unit_including_the_end_position() {
	input := RegexInput(RegexUtf16Input{
		units: [u16(0x61), 0xa, 0x62, 0xd, 0x2028, 0x2029]
	})
	for multiline in [false, true] {
		hints := RegexPatternHints{
			starts_with_anchor: true
			anchor_multiline:   multiline
		}
		assert regex_next_candidate_start(RegexProgram{}, input, hints, 0)? == 0
		assert regex_next_candidate_start(RegexProgram{}, input, hints, 1)? == 2
		assert regex_next_candidate_start(RegexProgram{}, input, hints, 3)? == 4
		assert regex_next_candidate_start(RegexProgram{}, input, hints, 5)? == 5
		assert regex_next_candidate_start(RegexProgram{}, input, hints, 6)? == 6
	}
	assert regex_next_candidate_start(RegexProgram{}, RegexAsciiInput{
		bytes: [
			u8(0x61),
		]
	}, RegexPatternHints{
		starts_with_anchor: true
	}, 1) == none
}

fn test_regex_candidate_filters_enforce_both_hints_and_never_filter_the_end_position() {
	input := RegexInput(RegexAsciiInput{
		bytes: [u8(0x61), 0x0a, 0x41, 0x35, 0x61]
	})
	hints := RegexPatternHints{
		first_char:   RegexFirstChar{
			code_point:       0x41
			case_insensitive: true
		}
		first_filter: RegexSimpleMatch(RegexBuiltinCharacterClass.word)
	}
	assert regex_next_candidate_start(RegexProgram{}, input, hints, 0)? == 0
	assert regex_next_candidate_start(RegexProgram{}, input, hints, 1)? == 2
	assert regex_next_candidate_start(RegexProgram{}, input, hints, 3)? == 4
	assert regex_next_candidate_start(RegexProgram{}, input, hints, 5) == none
	assert regex_next_candidate_start(RegexProgram{}, input, RegexPatternHints{
		first_filter:    RegexSimpleMatch(RegexBuiltinCharacterClass.digit)
		can_match_empty: true
	}, 0)? == 3
	assert regex_next_candidate_start(RegexProgram{}, input, RegexPatternHints{
		first_filter:    RegexSimpleMatch(RegexAnyChar{
			dot_all: true
		})
		can_match_empty: true
	}, 5) == none
	assert regex_next_candidate_start(RegexProgram{}, input, RegexPatternHints{
		first_char:   RegexFirstChar{
			code_point: 0x41
		}
		first_filter: RegexSimpleMatch(RegexBuiltinCharacterClass.digit)
	}, 0) == none
	assert regex_next_candidate_start(RegexProgram{}, input, RegexPatternHints{
		starts_with_anchor: true
		first_char:         RegexFirstChar{
			code_point: 0x41
		}
	}, 1)? == 2
}

module libjs

fn test_regex_greedy_consume_dot_flags_limits_and_end_positions() {
	input := RegexInput(RegexUtf16Input{
		units: [u16(65), 10, 66, 0x2028, 67]
	})
	count, pos := regex_greedy_consume_fast(input, 0, RegexAnyChar{}, RegexActiveModifiers{}, none)
	assert count == 1 && pos == 1
	limited, end := regex_greedy_consume_fast(input, 1, RegexAnyChar{}, RegexActiveModifiers{
		dot_all: true
	}, u32(3))
	assert limited == 3 && end == 4
	all, final_pos :=
		regex_greedy_consume_fast(input, 1, RegexAnyChar{ dot_all: true }, RegexActiveModifiers{}, none)
	assert all == 4 && final_pos == 5
	zero, unchanged := regex_greedy_consume_fast(input, 0, RegexAnyChar{ dot_all: true }, RegexActiveModifiers{},
		u32(0))
	assert zero == 0 && unchanged == 0
	empty, same_end :=
		regex_greedy_consume_fast(input, 5, RegexAnyChar{ dot_all: true }, RegexActiveModifiers{}, none)
	assert empty == 0 && same_end == 5
}

fn test_regex_greedy_consume_narrows_literals_but_retains_full_nocase_and_union_operands() {
	input := RegexInput(RegexAsciiInput{
		bytes: [u8(65), 65, 97, 32]
	})
	literal := RegexSimpleMatch(RegexLiteral{
		code_point: 0x10041
	})
	count, pos := regex_greedy_consume_fast(input, 0, literal, RegexActiveModifiers{}, none)
	assert count == 2 && pos == 2
	folded, folded_pos := regex_greedy_consume_fast(input, 0, literal, RegexActiveModifiers{
		ignore_case: true
	}, none)
	assert folded == 3 && folded_pos == 3
	nocase, unchanged := regex_greedy_consume_fast(input, 0, RegexCharNoCase{
		first:  0x10041
		second: 65
	}, RegexActiveModifiers{}, none)
	assert nocase == 0 && unchanged == 0
	right := RegexSimpleMatch(RegexLiteral{
		code_point: 49
	})
	union_count, union_pos := regex_greedy_consume_fast(input, 0, RegexSimpleUnion{
		left:  &literal
		right: &right
	}, RegexActiveModifiers{}, none)
	assert union_count == 0 && union_pos == 0
}

fn test_regex_greedy_consume_preserves_legacy_class_builtin_and_property_paths() {
	input := RegexInput(RegexUtf16Input{
		units: [u16(97), 98, 65, 0x212a]
	})
	class := RegexSimpleMatch(RegexBytecodeCharClass{
		ranges: [RegexCharRange{ start: 65, end: 90 }]
	})
	count, pos :=
		regex_greedy_consume_fast(input, 0, class, RegexActiveModifiers{ ignore_case: true }, none)
	assert count == 3 && pos == 3
	word, unchanged := regex_greedy_consume_fast(input, 3, RegexBuiltinCharacterClass.word, RegexActiveModifiers{
		ignore_case: true
	}, none)
	assert word == 0 && unchanged == 3
	property, property_pos := regex_greedy_consume_fast(input, 0, RegexUnicodePropertyData{
		name: 'Lowercase'
	}, RegexActiveModifiers{
		ignore_case: true
	}, none)
	assert property == 2 && property_pos == 2
	resolved, resolved_pos := regex_greedy_consume_fast(input, 0, RegexUnicodePropertyData{
		name:     'unknown'
		value:    ''
		resolved: regex_resolve_property('ASCII', none)
	}, RegexActiveModifiers{}, none)
	assert resolved == 3 && resolved_pos == 3
	negative, negative_pos := regex_greedy_consume_fast(input, 0, RegexBytecodeCharClass{
		ranges:  [RegexCharRange{ start: 65, end: 90 }]
		negated: true
	}, RegexActiveModifiers{}, none)
	assert negative == 2 && negative_pos == 2
}

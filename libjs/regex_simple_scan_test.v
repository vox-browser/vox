module libjs

fn test_regex_simple_scan_membership_preserves_negation_builtin_mode_and_literal_values() {
	for negated in [false, true] {
		class := RegexSimpleScan(RegexBytecodeCharClass{
			ranges:  [RegexCharRange{ start: 0x41, end: 0x5a }]
			negated: negated
		})
		assert regex_match_simple_scan(class, 0x41) == !negated
		assert regex_match_simple_scan(class, 0x61) == negated
		assert regex_match_simple_scan(class, 0x212a) == negated
	}
	assert regex_match_simple_scan(RegexBuiltinCharacterClass.word, 0x5f)
	assert !regex_match_simple_scan(RegexBuiltinCharacterClass.word, 0x17f)
	assert regex_match_simple_scan(RegexBuiltinCharacterClass.non_word, 0x212a)
	assert regex_match_simple_scan(RegexBuiltinCharacterClass.whitespace, 0xfeff)
	assert regex_match_simple_scan(RegexLiteral{ code_point: 0x10400 }, 0x10400)
	assert !regex_match_simple_scan(RegexLiteral{ code_point: 0x10400 }, 0xd801)
	assert !regex_match_simple_scan(RegexGreedyLoop{
		matcher: RegexLiteral{
			code_point: 0x61
		}
		min:     1
	}, 0x61)
}

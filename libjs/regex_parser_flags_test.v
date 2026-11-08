module libjs

fn test_regex_grammar_flags_preserve_each_compatible_subset_and_original_errors() {
	alphabet := 'gimsuvyd'
	for mask in 0 .. 256 {
		mut text := ''
		for index, character in alphabet {
			if mask & (1 << index) != 0 { text += rune(character).str() }
		}
		if mask & 48 == 48 {
			if _ := parse_regex_ast_flags(text) {
				assert false, text
			} else {
				assert err.msg() == 'invalid flags "${text}"'
			}
			continue
		}
		flags := parse_regex_ast_flags(text)!
		assert flags.global == (mask & 1 != 0)
		assert flags.ignore_case == (mask & 2 != 0)
		assert flags.multiline == (mask & 4 != 0)
		assert flags.dot_all == (mask & 8 != 0)
		assert flags.unicode == (mask & 16 != 0)
		assert flags.unicode_sets == (mask & 32 != 0)
		assert flags.sticky == (mask & 64 != 0)
		assert flags.has_indices == (mask & 128 != 0)
		for character in text {
			duplicate := text + rune(character).str()
			if _ := parse_regex_ast_flags(duplicate) {
				assert false, duplicate
			} else {
				assert err.msg() == 'invalid flags "${duplicate}"'
			}
		}
	}
	for text in ['x', 'U', 'g v', 'v\x00', '😀'] {
		if _ := parse_regex_ast_flags(text) {
			assert false, text
		} else {
			assert err.msg() == 'invalid flags "${text}"'
		}
	}
}

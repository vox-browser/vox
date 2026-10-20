module html

fn test_entity_name_index_preserves_every_prefix_and_complete_match() {
	mut expected := map[string]bool{}
	for name, points in named_char_ref_codepoints {
		mut matcher := NamedCharacterReferenceMatcher{}
		for index, byte in name.bytes() {
			prefix := name[..index + 1]
			expected[prefix] = true
			assert named_char_ref_has_prefix(prefix)
			assert matcher.try_consume_ascii_char(byte)
		}
		assert matcher.code_points()? == points
		assert matcher.overconsumed_code_points() == 0
		assert matcher.last_match_ends_with_semicolon() == name.ends_with(';')
	}
	// Compare the index with the previous prefix-set algorithm on every
	// possible ASCII continuation, including punctuation and invalid names.
	for prefix, _ in expected {
		for byte in 0 .. 128 {
			candidate := prefix + u8(byte).ascii_str()
			assert named_char_ref_has_prefix(candidate) == (candidate in expected)
		}
	}
}

fn test_entity_index_keeps_longest_match_and_rejects_non_ascii_without_consuming() {
	mut matcher := NamedCharacterReferenceMatcher{}
	for byte in 'noti'.bytes() { assert matcher.try_consume_ascii_char(byte) }
	assert !matcher.try_consume_code_point(`т`)
	assert !matcher.try_consume_ascii_char(`t`)
	assert matcher.last_match == 'not'
	assert matcher.overconsumed_code_points() == 1
	assert matcher.code_points()? == [u32(0xac)]
	matcher.reset()
	assert matcher.consumed == ''
	assert matcher.code_points() == none
	assert !named_char_ref_has_prefix('!')
	assert !named_char_ref_has_prefix('zzzz')
}

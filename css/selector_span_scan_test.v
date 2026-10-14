module css

fn test_selector_operator_scan_skips_quoted_text_and_handles_short_inputs() {
	assert top_level_index('data-label="a~=b"', '~=') == none
	assert top_level_index('data-label="a~=b"', '=')? == 10
	assert top_level_index('data-label^="test"', '^=')? == 10
	assert top_level_index('', '=') == none
	assert top_level_index('x', '~=') == none
	assert top_level_index('"quoted=" = x', '=')? == 10
}

fn test_selector_of_scan_uses_ascii_word_boundaries_and_skips_quotes() {
	assert top_level_ascii_word_index('2n OF .item', 'of')? == 3
	assert top_level_ascii_word_index('2n\tof\n.item', 'of')? == 3
	assert top_level_ascii_word_index('"of" of .item', 'of')? == 5
	assert top_level_ascii_word_index('2n oftype', 'of') == none
	assert top_level_ascii_word_index('2n Kf .item', 'of') == none
	assert top_level_ascii_word_index('x', 'of') == none
}

fn test_selector_hash_keeps_existing_utf8_byte_hash() {
	assert selector_string_hash('') == u32(2166136261)
	assert selector_string_hash('hello') == u32(1335831723)
	assert selector_string_hash('é') == u32(513665217)
}

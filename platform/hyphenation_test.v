module platform

fn test_hyphenation_uses_the_requested_dictionary_and_utf16_offsets() {
	$if macos {
		assert hyphenation_locations(utf16_code_units('generated'), 'en-US') == [3, 5, 7]
		assert hyphenation_locations(utf16_code_units('characteristically'), 'en').len > 1
	} $else {
		assert hyphenation_locations(utf16_code_units('generated'), 'en-US').len == 0
	}
	for language in ['', 'zz-ZZ'] {
		assert hyphenation_locations(utf16_code_units('generated'), language).len == 0
	}
}

fn test_hyphenation_preserves_english_capitalization_and_minimum_lengths() {
	for word in ['Generated', 'Éducation', 'five', 'the', ''] {
		assert hyphenation_locations(utf16_code_units(word), 'en-US').len == 0
	}
}

module libjs

fn test_regexp_source_escaping_tracks_character_classes_and_literal_backslashes() {
	for row in [['', '(?:)'], ['/', '\\/'], ['[/]/', '[/]\\/'],
		['\\/', '\\/'], ['\\[/]', '\\[\\/]'], ['[\\]/]', '[\\]/]'],
		['[[]/', '[[]\\/'], ['a\\', 'a'], ['\\', ''], ['\\\\', '\\\\'],
		['\\\\/', '\\\\\\/']] {
		assert escape_regexp_pattern(utf16_string(row[0])).str() == row[1]
	}
}

fn test_regexp_source_escaping_handles_all_line_terminators_and_preserves_raw_units() {
	for row in [[u32(0x0a), u32(`n`)], [u32(0x0d), u32(`r`)],
		[u32(0x2028), 0], [u32(0x2029), 0]] {
		unit := u16(row[0])
		expected := if row[1] != 0 { '\\' + rune(row[1]).str() } else { '\\u${unit:04x}' }
		for prefix in ['', '\\', '[', '[\\'] {
			mut input := utf16(prefix)
			input << unit
			assert escape_regexp_pattern(Utf16String.from_slice(input)).str() ==
				prefix.replace('\\', '') + expected
		}
	}
	// Unlike ParsePattern, source escaping preserves literal non-ASCII text,
	// including lone surrogates, and iterates supplementary pairs as code points.
	units := [u16(0), 0x80, 0xe9, 0xd800, 0x61, 0xdc00, 0xd83d, 0xde00, 0xffff]
	assert escape_regexp_pattern(Utf16String.from_slice(units)).data == units
	mut escaped_units := [u16(`\\`)]
	escaped_units << units
	assert escape_regexp_pattern(Utf16String.from_slice(escaped_units)).data == escaped_units
}

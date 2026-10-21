module platform

fn test_shaping_trailing_whitespace_preserves_utf16_counts_without_allocating() {
	texts := ['', 'word', ' \t\n\v\f\r', '字😀 \t\r\n', 'word\u00a0', 'word\u2003',
		'word\u00a0 ', '😀\u0000 \t', [u8(0xff), 0x80, 0x20, 0x09].bytestr()]
	expected := [0, 0, 6, 4, 0, 0, 1, 2, 2]
	// The decoded reference also covers malformed UTF-8 before an ASCII suffix.
	for index, text in texts {
		units := utf16_units_for_shaping(text)
		mut reference := 0
		for reference < units.len && is_ascii_space_for_shaping(units[units.len - reference - 1]) {
			reference++
		}
		assert reference == expected[index]
		assert trailing_whitespace_length(text) == reference
	}
	mut storage := new_arena('trailing whitespace inspection')
	entry := storage.enter()
	before := storage.usage().used
	for _ in 0 .. 256 {
		for index, text in texts {
			assert trailing_whitespace_length(text) == expected[index]
		}
	}
	growth := storage.usage().used - before
	storage.leave(entry)
	$if prealloc { assert growth == 0, '${growth} bytes for scalar whitespace queries' }
	storage.release()
}

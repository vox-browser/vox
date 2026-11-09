module libjs

fn test_empty_unicode_class_strings_use_progress_checks_in_repetitions() {
	// Independent Node v26.8.1 / RegExp v+d results: all match the empty
	// prefix. The optional capture remains unset for min=0 and participates
	// with [0,0] when the required minimum is positive.
	for pattern in [r'[\q{}]*', r'([\q{}])*', r'([\q{}])+', r'([\q{}]){0,3}', r'([\q{}]){2,3}',
		r'[[\q{}]&&[\q{}]]*'] {
		mut engine := RegexEngine.compile(pattern.runes(), RegexAstFlags{ unicode_sets: true, has_indices: true })!
		mut output := []i32{len: int(engine.program.capture_count + 1) * 2, init: -77}
		assert engine.exec(RegexAsciiInput{ bytes: 'a'.bytes() }, 0, mut output) == .match, pattern
		assert output[0] == 0 && output[1] == 0, pattern
		if engine.program.capture_count > 0 {
			expected := if pattern.contains('+') || pattern.contains('{2,3}') {
				i32(0)
			} else {
				i32(-1)
			}
			assert output[2] == expected && output[3] == expected, pattern
		}
		mut pairs := []i32{len: 6, init: -77}
		assert engine.find_all(RegexAsciiInput{ bytes: 'a'.bytes() }, 0, mut pairs) == 2, pattern
		assert pairs == [i32(0), 0, 1, 1, -77, -77], pattern
	}
}

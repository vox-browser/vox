module libjs

import os

fn test_regex_case_folding_retains_legacy_full_uppercase_and_unicode_simple_folding() {
	for point in 0 .. 128 {
		assert regex_case_fold(u32(point), false) == u32(if point >= 97 && point <= 122 {
			point - 32
		} else {
			point
		})
		assert regex_case_fold(u32(point), true) == u32(if point >= 65 && point <= 90 {
			point + 32
		} else {
			point
		})
	}
	assert regex_case_fold(0xe9, false) == 0xc9
	assert regex_case_fold(0xe9, true) == 0xe9
	assert regex_case_fold(0xdf, false) == 0xdf // Full uppercase expands to SS.
	assert regex_case_fold(0xfb03, false) == 0xfb03 // Full uppercase expands to FFI.
	assert regex_case_fold(0x17f, false) == 0x17f // A non-ASCII code point cannot become ASCII.
	assert regex_case_fold(0x17f, true) == 0x73
	assert regex_case_fold(0x212a, false) == 0x212a
	assert regex_case_fold(0x212a, true) == 0x6b
	assert regex_case_fold(0x3c2, false) == 0x3a3
	assert regex_case_fold(0x3c2, true) == 0x3c3
	assert regex_case_fold(0x10428, false) == 0x10400
	assert regex_case_fold(0x10400, true) == 0x10428
	for point in [u32(0xd800), 0xdfff] {
		assert regex_case_fold(point, false) == point
		assert regex_case_fold(point, true) == point
	}
	assert regex_case_fold_eq(0x3c2, 0x3a3, false)
	assert regex_case_fold_eq(0x3c2, 0x3c3, true)
	assert !regex_case_fold_eq(0xdf, 0x73, true)
	// Equal operands return before either invalid legacy operand is folded.
	assert regex_case_fold_eq(0xffffffff, 0xffffffff, false)
	assert regex_case_fold(0xffffffff, true) == 0xffffffff
}

fn test_regex_word_and_builtin_classes_preserve_unicode_ignore_case_extension() {
	for point in [u32(0x30), 0x39, 0x41, 0x5a, 0x5f, 0x61, 0x7a] {
		assert regex_is_word_char(point) && regex_is_word_char_unicode(point, true)
	}
	for point in [u32(0x2f), 0x3a, 0x40, 0x5b, 0x60, 0x7b, 0xe9, 0x130, 0x131, 0x10400, 0xd800] {
		assert !regex_is_word_char(point) && !regex_is_word_char_unicode(point, true)
	}
	for point in [u32(0x17f), 0x212a] {
		assert !regex_is_word_char_unicode(point, false)
		assert regex_is_word_char_unicode(point, true)
		assert regex_match_builtin_class(point, .word, true)
		assert !regex_match_builtin_class(point, .non_word, true)
	}
	assert regex_match_builtin_class(0x35, .digit, false)
	assert regex_match_builtin_class(0xff15, .non_digit, true)
	assert regex_match_builtin_class(0xfeff, .whitespace, true)
	assert regex_match_builtin_class(0x85, .non_whitespace, true)
}

fn test_regex_legacy_canonicalization_preserves_source_invalid_code_point_panic() {
	if os.getenv('VOX2_REGEX_FOLD_PANIC') == '1' {
		regex_case_fold(0x110000, false)
		assert false
		return
	}
	mut environment := os.environ()
	environment['VOX2_REGEX_FOLD_PANIC'] = '1'
	mut process := os.new_process(os.executable())
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('canonicalization requires a Unicode code point'), output
	process.close()
}

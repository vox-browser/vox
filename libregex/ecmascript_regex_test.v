module libregex

import libjs

fn test_source_regex_unicode_sets_captures_and_compile_errors() {
	mut regex := ECMAScriptRegex.compile(libjs.utf16_string(r'^(?<word>[\p{Letter}&&\p{ASCII}]+)\1$'), ECMAScriptCompileFlags{ unicode_sets: true })!
	defer { regex.destroy() }
	assert regex.capture_count() == 1 && regex.total_groups() == 2
	assert regex.named_groups().len == 1 && regex.named_groups()[0].name.str() == 'word'
	assert regex.named_groups()[0].index == 1
	assert regex.exec(libjs.utf16_string('AbAb'), 0) == .match_
	assert regex.capture_slot(0) == 0 && regex.capture_slot(1) == 4
	assert regex.capture_slot(2) == 0 && regex.capture_slot(3) == 2
	assert regex.exec(libjs.utf16_string('éé'), 0) == .no_match
	// exec_into only writes captures on a match; source resize preserves them.
	assert regex.capture_slot(2) == 0 && regex.capture_slot(3) == 2
	assert regex.test(libjs.utf16_string('1212'), 0) == .no_match
	for pattern in [r'[', r'[a--]', r'\p{not_a_property}', r'(a)\2'] {
		if mut invalid := ECMAScriptRegex.compile(libjs.utf16_string(pattern), ECMAScriptCompileFlags{ unicode_sets: true }) {
			invalid.destroy()
			assert false, pattern
		} else {
			assert err.msg().len > 0
		}
	}
}

fn test_source_regex_storage_paths_empty_pattern_find_all_growth_and_move_ownership() {
	mut empty := ECMAScriptRegex.compile(libjs.utf16_string(''), ECMAScriptCompileFlags{})!
	defer { empty.destroy() }
	assert empty.test(libjs.utf16_string(''), 0) == .match_
	mut source := ECMAScriptRegex.compile(libjs.utf16_string('a'), ECMAScriptCompileFlags{})!
	mut target := ECMAScriptRegex.compile(libjs.utf16_string('b'), ECMAScriptCompileFlags{})!
	defer {
		source.destroy()
		target.destroy()
	}
	target.move_from(mut source)
	assert target.find_all(libjs.utf16_string('a'.repeat(300)), 0) == 300
	assert target.find_all_match(299) == MatchPair{ start: 299, end: 300 }
	assert target.compiled_.find_all_buffer_.len == 1024
	utf16 := libjs.utf16_string_from_code_units_with_storage([u16(0x61), 0x61], false)!
	assert target.exec(utf16, 1) == .match_
	assert target.capture_slot(0) == 1 && target.capture_slot(1) == 2
	mut astral := ECMAScriptRegex.compile(libjs.utf16_string('😀'), ECMAScriptCompileFlags{ unicode_sets: true })!
	defer { astral.destroy() }
	assert astral.is_single_non_bmp_literal()
	assert astral.test(libjs.utf16_string('x😀'), 0) == .match_
}

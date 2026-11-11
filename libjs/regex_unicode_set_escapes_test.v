// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// Regressions translated from Ladybird 7d40499c017a529103126f4d006fd4bd2abc8e89.
module libjs

fn unicode_set_escaped_match(pattern string, input string) bool {
	mut regex := RegexEngine.compile(pattern.runes(), RegexAstFlags{ unicode_sets: true }) or { panic(err) }
	return regex.test(RegexUtf16Input{ units: utf16(input) }, 0) == .match
}

fn test_unicode_set_reserved_punctuators_and_control_escapes_match() {
	for character in '&-!#%,:;<=>@`~'.runes() {
		pattern := '[\\${character}]'
		assert unicode_set_escaped_match(pattern, character.str()), pattern
		assert !unicode_set_escaped_match(pattern, 'a'), pattern
		assert unicode_set_escaped_match('[\\q{\\${character}}]', character.str())
	}
	for pattern in [r'[\cJ]', r'[\q{\cJ}]'] {
		assert unicode_set_escaped_match(pattern, '\n')
		assert !unicode_set_escaped_match(pattern, 'J')
	}
	assert unicode_set_escaped_match(r'[\&-\)]', "'")
	assert unicode_set_escaped_match(r'[\p{L}--\&]', 'a')
	assert !unicode_set_escaped_match(r'[\p{L}--\&]', '&')
	assert unicode_set_escaped_match(r'[\&&&\&]', '&')
	assert unicode_set_escaped_match(r'^[\q{a\!b}]$', 'a!b')
	assert unicode_set_escaped_match(r'[\q{\/}]', '/')
	assert unicode_set_escaped_match(r'[\q{\^}]', '^')
}

fn test_unicode_set_escapes_retain_invalid_escape_and_double_punctuator_errors() {
	for pattern in [r'[\_]', r'[\"]', r"[\']", r'[\c1]', r'[\q{\_}]',
		r'[\q{\01}]', r'[\q{\c1}]', r'\&', '[!!]'] {
		if _ := parse_regex_ast(pattern, RegexAstFlags{ unicode_sets: true }) {
			assert false, pattern
		} else {
			assert err.msg().contains('invalid'), pattern
		}
	}
}

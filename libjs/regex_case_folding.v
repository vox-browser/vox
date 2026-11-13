module libjs

import vunicode

pub fn regex_canonicalize(code_point u32, unicode_mode bool) u32 {
	if unicode_mode { return vunicode.simple_fold(code_point) }
	if code_point > 0x10ffff { panic('Regex canonicalization requires a Unicode code point') }
	upper := vunicode.full_upper(code_point)
	if upper.len != 1 || (code_point >= 128 && upper[0] < 128) { return code_point }
	return upper[0]
}

// LibRegex/Rust/src/vm.rs::{case_fold,case_fold_eq}.
pub fn regex_case_fold(code_point u32, unicode_mode bool) u32 {
	if code_point < 128 {
		if unicode_mode {
			if code_point >= 0x41 && code_point <= 0x5a { return code_point + 32 }
		} else if code_point >= 0x61 && code_point <= 0x7a {
			return code_point - 32
		}
		return code_point
	}
	return regex_canonicalize(code_point, unicode_mode)
}

pub fn regex_case_fold_eq(a u32, b u32, unicode_mode bool) bool {
	if a == b { return true }
	return regex_case_fold(a, unicode_mode) == regex_case_fold(b, unicode_mode)
}

pub fn regex_is_word_char(code_point u32) bool {
	return (code_point >= 0x30 && code_point <= 0x39)
		|| (code_point >= 0x41 && code_point <= 0x5a)
		|| (code_point >= 0x61 && code_point <= 0x7a) || code_point == 0x5f
}

pub fn regex_is_word_char_unicode(code_point u32, unicode_ignore_case bool) bool {
	if regex_is_word_char(code_point) { return true }
	if unicode_ignore_case && regex_is_word_char(regex_case_fold(code_point, true)) { return true }
	return false
}

pub fn regex_is_digit(code_point u32) bool {
	return code_point >= 0x30 && code_point <= 0x39
}

pub fn regex_match_builtin_class(code_point u32, class RegexBuiltinCharacterClass, unicode_ignore_case bool) bool {
	return match class {
		.digit { regex_is_digit(code_point) }
		.non_digit { !regex_is_digit(code_point) }
		.word { regex_is_word_char_unicode(code_point, unicode_ignore_case) }
		.non_word { !regex_is_word_char_unicode(code_point, unicode_ignore_case) }
		.whitespace { regex_is_whitespace(code_point) }
		.non_whitespace { !regex_is_whitespace(code_point) }
	}
}

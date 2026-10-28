module libjs

#flag -I @DIR
#flag darwin -licucore
#flag linux -licuuc
#include "regex_case_folding.h"

@[typedef]
struct C.UCaseMap {}

fn C.u_foldCase(code_point i32, options u32) i32
fn C.ucasemap_open(locale &char, options u32, status &i32) &C.UCaseMap
fn C.ucasemap_close(case_map &C.UCaseMap)
fn C.ucasemap_utf8ToUpper(case_map &C.UCaseMap, output &char, capacity i32, input &char, length i32, status &i32) i32

// LibUnicode::canonicalize and its Rust simple_case_fold FFI. Legacy mode uses
// the same ICU UTF-8 full case case_map as AK::String::to_uppercase, not u_toupper.
pub fn regex_canonicalize(code_point u32, unicode_mode bool) u32 {
	if unicode_mode { return u32(C.u_foldCase(i32(code_point), 0)) }
	if code_point < 128 {
		return if code_point >= 0x61 && code_point <= 0x7a { code_point - 32 } else { code_point }
	}
	// AK::String::from_code_point asserts this boundary, retaining surrogates.
	if code_point > 0x10ffff { panic('Regex canonicalization requires a Unicode code point') }
	mut units := []u16{cap: 2}
	append_utf16_code_point(mut units, code_point)
	input := encode_utf16(units, false)
	mut status := i32(0)
	case_map := C.ucasemap_open(unsafe { nil }, 0, &status)
	if unsafe { case_map == nil } { return code_point }
	defer { C.ucasemap_close(case_map) }
	if status > 0 { return code_point }
	length := C.ucasemap_utf8ToUpper(case_map, unsafe { nil }, 0, input.str, i32(input.len), &status)
	if length < 0 || (status > 0 && status != C.U_BUFFER_OVERFLOW_ERROR) { return code_point }
	mut output := []u8{len: length}
	status = 0
	written := C.ucasemap_utf8ToUpper(case_map, &char(output.data), i32(output.len), input.str,
		i32(input.len), &status)
	if status > 0 { return code_point }
	assert written >= 0 && written <= output.len
	points := output[..written].bytestr().runes()
	if points.len != 1 { return code_point }
	uppercased := u32(points[0])
	if uppercased < 128 { return code_point }
	return uppercased
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

module libjs

#flag -I @DIR
#flag darwin -licucore
#flag linux -licuuc
#include "unicode_transform.h"

@[typedef]
struct C.UNormalizer2 {}

fn C.u_strToLower(output &u16, capacity i32, input &u16, length i32, locale &char, status &i32) i32
fn C.u_strToUpper(output &u16, capacity i32, input &u16, length i32, locale &char, status &i32) i32
fn C.unorm2_getNFDInstance(status &i32) &C.UNormalizer2
fn C.unorm2_getNFCInstance(status &i32) &C.UNormalizer2
fn C.unorm2_getNFKDInstance(status &i32) &C.UNormalizer2
fn C.unorm2_getNFKCInstance(status &i32) &C.UNormalizer2
fn C.unorm2_normalize(normalizer &C.UNormalizer2, input &u16, length i32, output &u16, capacity i32, status &i32) i32

fn icu_case_map(text Utf16String, uppercase bool) Utf16String {
	if text.is_empty() { return text }
	mut status := i32(0)
	length := if uppercase {
		C.u_strToUpper(unsafe { nil }, 0, text.data.data, i32(text.len()), unsafe { nil }, &status)
	} else {
		C.u_strToLower(unsafe { nil }, 0, text.data.data, i32(text.len()), unsafe { nil }, &status)
	}
	// ICU UnicodeString::caseMap marks failed results bogus (empty). Capacity
	// preflight replaces its private buffer-growth code; warnings are success.
	if length < 0 || (status > 0 && status != C.U_BUFFER_OVERFLOW_ERROR) { return Utf16String{} }
	mut units := []u16{len: length}
	status = 0
	written := if uppercase {
		C.u_strToUpper(units.data, i32(units.len), text.data.data, i32(text.len()), unsafe { nil }, &status)
	} else {
		C.u_strToLower(units.data, i32(units.len), text.data.data, i32(text.len()), unsafe { nil }, &status)
	}
	if status > 0 { return Utf16String{} }
	assert written >= 0 && written <= units.len
	return Utf16String.from_slice(units[..written])
}

// LibUnicode/Utf16String.cpp and AK::Utf16View's ASCII conversion bodies.
// Without an explicit locale, upstream bypasses ICU for ASCII storage but uses
// ICU's process default locale for other strings. Preserve that source choice.
fn unicode_string_case(text Utf16String, uppercase bool) Utf16String {
	if text.data.all(it <= 0x7f) {
		mut units := []u16{cap: text.len()}
		for unit in text.data {
			units << if uppercase && unit >= 0x61 && unit <= 0x7a {
				unit - 0x20
			} else if !uppercase && unit >= 0x41 && unit <= 0x5a {
				unit + 0x20
			} else {
				unit
			}
		}
		return Utf16String{
			data: units
		}
	}
	return icu_case_map(text, uppercase)
}

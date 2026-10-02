module libjs

#flag -I @DIR
#flag darwin -licucore
#flag linux -licuuc
#include "unicode_transform.h"

@[typedef]
struct C.UNormalizer2 {}

fn C.u_strToLower(output &u16, capacity int, input &u16, length int, locale &char, status &int) int
fn C.u_strToUpper(output &u16, capacity int, input &u16, length int, locale &char, status &int) int
fn C.unorm2_getNFDInstance(status &int) &C.UNormalizer2
fn C.unorm2_getNFCInstance(status &int) &C.UNormalizer2
fn C.unorm2_getNFKDInstance(status &int) &C.UNormalizer2
fn C.unorm2_getNFKCInstance(status &int) &C.UNormalizer2
fn C.unorm2_normalize(normalizer &C.UNormalizer2, input &u16, length int, output &u16, capacity int, status &int) int

fn icu_case_map(text Utf16String, uppercase bool) Utf16String {
	if text.is_empty() { return text }
	mut status := 0
	length := if uppercase {
		C.u_strToUpper(unsafe { nil }, 0, text.data.data, text.len(), unsafe { nil }, &status)
	} else {
		C.u_strToLower(unsafe { nil }, 0, text.data.data, text.len(), unsafe { nil }, &status)
	}
	// ICU UnicodeString::caseMap marks failed results bogus (empty). Capacity
	// preflight replaces its private buffer-growth code; warnings are success.
	if length < 0 || (status > 0 && status != C.U_BUFFER_OVERFLOW_ERROR) { return Utf16String{} }
	mut units := []u16{len: length}
	status = 0
	written := if uppercase {
		C.u_strToUpper(units.data, units.len, text.data.data, text.len(), unsafe { nil }, &status)
	} else {
		C.u_strToLower(units.data, units.len, text.data.data, text.len(), unsafe { nil }, &status)
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

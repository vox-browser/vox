// Copyright (c) 2021-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the self-contained host-parsing helpers of LibURL/Parser.cpp — the forbidden host and
// domain code point predicates, the opaque-host parser, and the "ends in a number" check (used to decide
// whether a domain should be parsed as IPv4). The domain host parser itself needs IDNA (domain to ASCII)
// and is not translated. Validation-error reporting is dropped.
// https://url.spec.whatwg.org/#host-parsing
module url

// A forbidden host code point: NUL, TAB, LF, CR, SPACE, and # / : < > ? @ [ \ ] ^ | .
const forbidden_host_code_points = [u8(0x00), 0x09, 0x0A, 0x0D, 0x20, 0x23, 0x2F, 0x3A, 0x3C, 0x3E,
	0x3F, 0x40, 0x5B, 0x5C, 0x5D, 0x5E, 0x7C]

// https://url.spec.whatwg.org/#forbidden-host-code-point
pub fn is_forbidden_host_code_point(code_point u32) bool {
	return code_point <= 0x7F && u8(code_point) in forbidden_host_code_points
}

// https://url.spec.whatwg.org/#forbidden-domain-code-point — a forbidden host code point, a C0 control,
// U+0025 (%), or U+007F DELETE.
pub fn is_forbidden_domain_code_point(code_point u32) bool {
	return is_forbidden_host_code_point(code_point) || code_point <= 0x1F || code_point == 0x25 ||
		code_point == 0x7F
}

// https://url.spec.whatwg.org/#concept-opaque-host-parser — validate that input has no forbidden host
// code point, then percent-encode it with the C0 control set. Failure is none.
pub fn parse_opaque_host(input string) ?string {
	// 1. A forbidden host code point makes the opaque host invalid.
	for code_point in input.runes() {
		if is_forbidden_host_code_point(u32(code_point)) {
			return none
		}
	}
	// 2-3. (Validation-error-only checks are omitted, as upstream.)
	// 4. Percent-encode using the C0 control percent-encode set.
	return percent_encode(input, .c0_control, false)
}

fn all_ascii_digits(input string) bool {
	for b in input.bytes() {
		if b < `0` || b > `9` {
			return false
		}
	}
	return true
}

fn all_ascii_hex_digits(input string) bool {
	for b in input.bytes() {
		if !is_ascii_hex_digit(b) {
			return false
		}
	}
	return true
}

// https://url.spec.whatwg.org/#ends-in-a-number-checker — whether a host's last label is an IPv4 number
// (a non-empty run of ASCII digits, or "0x"/"0X" followed by zero or more ASCII hex digits).
pub fn ends_in_a_number_checker(input string) bool {
	// 1. Strictly split on '.', keeping empty parts.
	mut parts := input.split('.')
	// 2. A trailing empty part is dropped (unless it is the only part, in which case there is no number).
	if parts[parts.len - 1] == '' {
		if parts.len == 1 {
			return false
		}
		parts = parts[..parts.len - 1]
	}
	// 3. Consider the last part.
	last := parts[parts.len - 1]
	// 4. A non-empty run of ASCII digits ends in a number.
	if last.len > 0 && all_ascii_digits(last) {
		return true
	}
	// 5. "0x"/"0X" followed by zero or more ASCII hex digits also ends in a number.
	if (last.starts_with('0x') || last.starts_with('0X')) && all_ascii_hex_digits(last[2..]) {
		return true
	}
	// 6. Otherwise it does not.
	return false
}

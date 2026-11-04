// Copyright (c) 2021-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of LibURL/Parser.cpp's host parsing algorithms. UTS #46 domain
// processing is provided by the same ICU backend used by Ladybird.
// https://url.spec.whatwg.org/#host-parsing
module url

// A forbidden host code point: NUL, TAB, LF, CR, SPACE, and # / : < > ? @ [ \ ] ^ | .
const forbidden_host_code_points = [u8(0x00), 0x09, 0x0A, 0x0D, 0x20, 0x23, 0x2F, 0x3A, 0x3C, 0x3E,
	0x3F, 0x40, 0x5B, 0x5C, 0x5D, 0x5E, 0x7C]

// https://url.spec.whatwg.org/#forbidden-host-code-point
pub fn is_forbidden_host_code_point(code_point u32) bool {
	if !disable_url_ascii_membership {
		if url_ascii_membership_diagnostics { report_url_ascii_membership(true) }
		return ascii_membership(code_point, host_ascii_lower, host_ascii_upper)
	}
	return code_point <= 0x7F && u8(code_point) in forbidden_host_code_points
}

// https://url.spec.whatwg.org/#forbidden-domain-code-point — a forbidden host code point, a C0 control,
// U+0025 (%), or U+007F DELETE.
pub fn is_forbidden_domain_code_point(code_point u32) bool {
	return is_forbidden_host_code_point(code_point) || code_point <= 0x1F || code_point == 0x25
		|| code_point == 0x7F
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

// https://url.spec.whatwg.org/#concept-host-parser
pub fn parse_host(input string, is_opaque bool) ?Host {
	if input.starts_with('[') {
		if !input.ends_with(']') {
			return none
		}
		pieces := parse_ipv6_address(input[1..input.len - 1]) or { return none }
		return Host.ipv6(pieces)
	}
	if is_opaque {
		value := parse_opaque_host(input) or { return none }
		return Host.from_string(value)
	}
	if input == '' {
		return none
	}
	domain_bytes := percent_decode(input)
	domain := domain_bytes.bytestr()
	ascii_domain := domain_to_ascii(domain, false) or { return none }
	for character in ascii_domain.bytes() {
		if is_forbidden_domain_code_point(character) {
			return none
		}
	}
	if ends_in_a_number_checker(ascii_domain) {
		address := parse_ipv4_address(ascii_domain) or { return none }
		return Host.ipv4(address)
	}
	return Host.from_string(ascii_domain)
}

// https://url.spec.whatwg.org/#ends-in-a-number-checker — whether a host's last label is an IPv4 number
// (a non-empty run of ASCII digits, or "0x"/"0X" followed by zero or more ASCII hex digits).
pub fn ends_in_a_number_checker(input string) bool {
	// Strict splitting and dropping exactly one trailing empty part select the
	// same byte interval. Inspect it in place without allocating the other
	// labels, a substring, or a byte-array copy for every parsed host.
	mut end := input.len
	if end > 0 && input[end - 1] == `.` { end-- }
	if end == 0 { return false }
	mut start := end
	for start > 0 && input[start - 1] != `.` {
		start--
	}
	if start == end { return false }
	if end - start >= 2 && input[start] == `0` && input[start + 1] in [`x`, `X`] {
		for index in start + 2 .. end {
			if !is_ascii_hex_digit(input[index]) { return false }
		}
		return true
	}
	for index in start .. end {
		if input[index] < `0` || input[index] > `9` { return false }
	}
	return true
}

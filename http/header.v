// Copyright (c) 2022, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the self-contained header validation/normalization helpers of LibHTTP/Header.cpp and
// the HTTP byte classes of LibHTTP/HTTP.h — is_header_name, is_header_value, and normalize_header_value.
// https://fetch.spec.whatwg.org/#headers

module http

// https://fetch.spec.whatwg.org/#http-newline-byte — 0x0A (LF) or 0x0D (CR).
fn is_http_newline(b u8) bool {
	return b == 0x0A || b == 0x0D
}

// https://fetch.spec.whatwg.org/#http-tab-or-space-byte — 0x09 (HT) or 0x20 (SP).
fn is_http_tab_or_space(b u8) bool {
	return b == 0x09 || b == 0x20
}

// https://fetch.spec.whatwg.org/#header-name — a non-empty sequence matching the field-name token
// production (the same token characters as a method).
pub fn is_header_name(header_name string) bool {
	if header_name.len == 0 {
		return false
	}
	for b in header_name.bytes() {
		if !is_method_token_byte(b) {
			return false
		}
	}
	return true
}

// https://fetch.spec.whatwg.org/#header-value — no leading or trailing HTTP tab/space byte, and no NUL
// or HTTP newline byte anywhere. The empty byte sequence is a valid header value.
pub fn is_header_value(header_value string) bool {
	if header_value.len == 0 {
		return true
	}
	bytes := header_value.bytes()
	if is_http_tab_or_space(bytes[0]) || is_http_tab_or_space(bytes[bytes.len - 1]) {
		return false
	}
	for b in bytes {
		if b == 0x00 || is_http_newline(b) {
			return false
		}
	}
	return true
}

// https://fetch.spec.whatwg.org/#concept-header-value-normalize — remove leading and trailing HTTP
// whitespace bytes (LF, CR, tab, space).
pub fn normalize_header_value(potential_value string) string {
	return potential_value.trim('\n\r\t ')
}

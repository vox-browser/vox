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

// The forbidden request header names (compared ASCII case-insensitively; stored lowercased).
const forbidden_request_header_names = ['accept-charset', 'accept-encoding',
	'access-control-request-headers', 'access-control-request-method', 'connection', 'content-length',
	'cookie', 'cookie2', 'date', 'dnt', 'expect', 'host', 'keep-alive', 'origin', 'referer',
	'set-cookie', 'te', 'trailer', 'transfer-encoding', 'upgrade', 'via']

// The method-override header names, whose value can name a forbidden method.
const method_override_header_names = ['x-http-method', 'x-http-method-override', 'x-method-override']

// https://fetch.spec.whatwg.org/#forbidden-request-header
pub fn is_forbidden_request_header(header Header) bool {
	lowercased_name := ascii_lowercase(header.name)
	// 1. A byte-case-insensitive match for one of the forbidden request header names.
	if lowercased_name in forbidden_request_header_names {
		return true
	}
	// 2. A name that, byte-lowercased, starts with `proxy-` or `sec-`.
	if lowercased_name.starts_with('proxy-') || lowercased_name.starts_with('sec-') {
		return true
	}
	// 3. A method-override header whose value, when got/decoded/split, names a forbidden method.
	if lowercased_name in method_override_header_names {
		for method in get_decode_and_split_header_value(header.value) {
			if is_forbidden_method(method) {
				return true
			}
		}
	}
	// 4. Otherwise it is not forbidden.
	return false
}

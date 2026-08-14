// Copyright (c) 2022-2023, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Fetch/Infrastructure/HTTP/CORS.cpp — the CORS request/response header safelist
// predicates (https://fetch.spec.whatwg.org/#cors-protocol-and-http-caches). Composes the http
// header list and the mimesniff MimeType record. The LibHTTP helpers these rely on
// (parse_single_range_header_value, convert_header_names_to_a_sorted_lowercase_set,
// is_forbidden_response_header_name) are translated inline.
module fetch

import http
import mimesniff

fn is_ascii_digit(byte u8) bool {
	return byte >= `0` && byte <= `9`
}

fn is_ascii_alpha(byte u8) bool {
	return (byte >= `a` && byte <= `z`) || (byte >= `A` && byte <= `Z`)
}

fn ascii_lowercase(input string) string {
	mut bytes := input.bytes()
	for i, ch in bytes {
		if ch >= `A` && ch <= `Z` {
			bytes[i] = ch + 0x20
		}
	}
	return bytes.bytestr()
}

fn equals_ignoring_ascii_case(a string, b string) bool {
	return ascii_lowercase(a) == ascii_lowercase(b)
}

fn skip_http_tab_or_space(data string, start int) int {
	mut p := start
	for p < data.len && (data[p] == `\t` || data[p] == ` `) {
		p++
	}
	return p
}

fn is_one_of_ignoring_ascii_case(name string, options []string) bool {
	lowered := ascii_lowercase(name)
	for option in options {
		if lowered == ascii_lowercase(option) {
			return true
		}
	}
	return false
}

// https://fetch.spec.whatwg.org/#cors-unsafe-request-header-byte
pub fn is_cors_unsafe_request_header_byte(byte u8) bool {
	// byte < 0x20 and not 0x09 (HT), or one of the listed punctuation/DEL bytes.
	return (byte < 0x20 && byte != 0x09)
		|| byte in [u8(0x22), 0x28, 0x29, 0x3A, 0x3C, 0x3E, 0x3F, 0x40, 0x5B, 0x5C, 0x5D, 0x7B, 0x7D, 0x7F]
}

// A parsed HTTP single range header value.
pub struct RangeHeaderValue {
pub:
	start ?u64
	end   ?u64
}

// LibHTTP: parse a single range header value ("bytes=start-end").
pub fn parse_single_range_header_value(value string, allow_whitespace bool) ?RangeHeaderValue {
	// 1. data is the isomorphic decoding of value (identity for a V string).
	data := value
	// 2. If data does not start with "bytes", return failure.
	if !data.starts_with('bytes') {
		return none
	}
	mut pos := 5
	if allow_whitespace {
		pos = skip_http_tab_or_space(data, pos)
	}
	// 5-6. Require "=".
	if pos >= data.len || data[pos] != `=` {
		return none
	}
	pos++
	if allow_whitespace {
		pos = skip_http_tab_or_space(data, pos)
	}
	// 8. Collect range-start digits.
	start_begin := pos
	for pos < data.len && is_ascii_digit(data[pos]) {
		pos++
	}
	range_start := data[start_begin..pos]
	if allow_whitespace {
		pos = skip_http_tab_or_space(data, pos)
	}
	// 11-12. Require "-".
	if pos >= data.len || data[pos] != `-` {
		return none
	}
	pos++
	if allow_whitespace {
		pos = skip_http_tab_or_space(data, pos)
	}
	// 14. Collect range-end digits.
	end_begin := pos
	for pos < data.len && is_ascii_digit(data[pos]) {
		pos++
	}
	range_end := data[end_begin..pos]
	// 16. If not past the end of data, failure.
	if pos != data.len {
		return none
	}
	// 17. If both are empty (null), failure.
	if range_start.len == 0 && range_end.len == 0 {
		return none
	}
	start_value := if range_start.len != 0 { ?u64(range_start.u64()) } else { ?u64(none) }
	end_value := if range_end.len != 0 { ?u64(range_end.u64()) } else { ?u64(none) }
	// 18. If start > end, failure.
	if s := start_value {
		if e := end_value {
			if s > e {
				return none
			}
		}
	}
	// 19. Return (start, end).
	return RangeHeaderValue{
		start: start_value
		end:   end_value
	}
}

// https://fetch.spec.whatwg.org/#forbidden-response-header-name
pub fn is_forbidden_response_header_name(name string) bool {
	return is_one_of_ignoring_ascii_case(name, ['Set-Cookie', 'Set-Cookie2'])
}

// LibHTTP: convert a list of header names to a sorted, lowercased, de-duplicated set.
pub fn convert_header_names_to_a_sorted_lowercase_set(names []string) []string {
	mut set := map[string]bool{}
	for name in names {
		set[ascii_lowercase(name)] = true
	}
	mut result := set.keys()
	result.sort()
	return result
}

// https://fetch.spec.whatwg.org/#cors-safelisted-request-header
pub fn is_cors_safelisted_request_header(header http.Header) bool {
	name := header.name
	value := header.value
	// 1. If value's length is greater than 128, return false.
	if value.len > 128 {
		return false
	}
	// 2. Byte-lowercase name and switch:
	if equals_ignoring_ascii_case(name, 'accept') {
		// A CORS-unsafe request-header byte disqualifies.
		for byte in value.bytes() {
			if is_cors_unsafe_request_header_byte(byte) {
				return false
			}
		}
	} else if is_one_of_ignoring_ascii_case(name, ['accept-language', 'content-language']) {
		// Only digits, letters, SP, *, ,, -, ., ;, = are allowed.
		for byte in value.bytes() {
			if !(is_ascii_digit(byte) || is_ascii_alpha(byte)
				|| byte in [u8(` `), `*`, `,`, `-`, `.`, `;`, `=`]) {
				return false
			}
		}
	} else if equals_ignoring_ascii_case(name, 'content-type') {
		// 1. A CORS-unsafe request-header byte disqualifies.
		for byte in value.bytes() {
			if is_cors_unsafe_request_header_byte(byte) {
				return false
			}
		}
		// 2-3. Parse the value as a MIME type; failure disqualifies.
		mime_type := mimesniff.MimeType.parse(value) or { return false }
		// 4. Essence must be one of the form-submission types.
		if mime_type.essence() !in ['application/x-www-form-urlencoded', 'multipart/form-data',
			'text/plain'] {
			return false
		}
	} else if equals_ignoring_ascii_case(name, 'range') {
		// 1-3. Parse a single range; a present range-start is required.
		range_value := parse_single_range_header_value(value, false) or { return false }
		if range_value.start == none {
			return false
		}
	} else {
		// Otherwise, return false.
		return false
	}
	// 3. Return true.
	return true
}

// https://fetch.spec.whatwg.org/#cors-unsafe-request-header-names
pub fn get_cors_unsafe_header_names(headers &http.HeaderList) []string {
	mut unsafe_names := []string{}
	mut potentially_unsafe_names := []string{}
	mut safelist_value_size := u64(0)
	// 4. For each header:
	for header in headers.headers() {
		if !is_cors_safelisted_request_header(header) {
			unsafe_names << header.name
		} else {
			potentially_unsafe_names << header.name
			safelist_value_size += u64(header.value.len)
		}
	}
	// 5. If safelistValueSize > 1024, all potentially-unsafe names become unsafe.
	if safelist_value_size > 1024 {
		unsafe_names << potentially_unsafe_names
	}
	// 6. Return the sorted-lowercase set of unsafeNames.
	return convert_header_names_to_a_sorted_lowercase_set(unsafe_names)
}

// https://fetch.spec.whatwg.org/#cors-non-wildcard-request-header-name
pub fn is_cors_non_wildcard_request_header_name(header_name string) bool {
	return equals_ignoring_ascii_case(header_name, 'Authorization')
}

// https://fetch.spec.whatwg.org/#privileged-no-cors-request-header-name
pub fn is_privileged_no_cors_request_header_name(header_name string) bool {
	return equals_ignoring_ascii_case(header_name, 'Range')
}

// https://fetch.spec.whatwg.org/#cors-safelisted-response-header-name
pub fn is_cors_safelisted_response_header_name(header_name string, list []string) bool {
	if is_one_of_ignoring_ascii_case(header_name, ['Cache-Control', 'Content-Language',
		'Content-Length', 'Content-Type', 'Expires', 'Last-Modified', 'Pragma'])
	{
		return true
	}
	// Any item in list that is not a forbidden response-header name.
	for list_header_name in list {
		if equals_ignoring_ascii_case(header_name, list_header_name)
			&& !is_forbidden_response_header_name(list_header_name) {
			return true
		}
	}
	return false
}

// https://fetch.spec.whatwg.org/#no-cors-safelisted-request-header-name
pub fn is_no_cors_safelisted_request_header_name(header_name string) bool {
	return is_one_of_ignoring_ascii_case(header_name, ['Accept', 'Accept-Language',
		'Content-Language', 'Content-Type'])
}

// https://fetch.spec.whatwg.org/#no-cors-safelisted-request-header
pub fn is_no_cors_safelisted_request_header(header http.Header) bool {
	// 1. Name must be a no-CORS-safelisted request-header name.
	if !is_no_cors_safelisted_request_header_name(header.name) {
		return false
	}
	// 2. And (name, value) must be a CORS-safelisted request-header.
	return is_cors_safelisted_request_header(header)
}

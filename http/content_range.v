// Copyright (c) 2022, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HeaderList::extract_content_range_values (LibHTTP/HeaderList.cpp) and its single
// byte content-range parser — extracting the first-byte-pos, last-byte-pos, and complete-length from a
// `Content-Range` header. Failure is represented by none (upstream's Variant<..., Failure>).
// https://fetch.spec.whatwg.org/#content-range-header

module http

import strconv

// The parsed portions of a single byte content-range: `bytes <first>-<last>/<complete>` where the
// complete length is none for "*".
pub struct ContentRangeValues {
pub:
	first_byte_pos  u64
	last_byte_pos   u64
	complete_length ?u64
}

// A non-empty run of ASCII digits parsed as a u64 (none if empty, non-digit, or overflowing).
fn parse_all_digits_u64(input string) ?u64 {
	if input.len == 0 {
		return none
	}
	for b in input.bytes() {
		if b < `0` || b > `9` {
			return none
		}
	}
	return strconv.parse_uint(input, 10, 64) or { return none }
}

// Parse `bytes <first-byte-pos>-<last-byte-pos>/<complete-length>` (complete-length is 1*DIGIT or "*").
// The entire value must be consumed. (AD-HOC, matching upstream: a space follows "bytes", not "=".)
fn parse_single_byte_content_range_as_values(input string) ?ContentRangeValues {
	prefix := 'bytes '
	if !input.starts_with(prefix) {
		return none
	}
	mut rest := input[prefix.len..]
	// first-byte-pos, terminated by '-'.
	dash := rest.index('-') or { return none }
	first_byte_pos := parse_all_digits_u64(rest[..dash]) or { return none }
	rest = rest[dash + 1..]
	// last-byte-pos, terminated by '/'.
	slash := rest.index('/') or { return none }
	last_byte_pos := parse_all_digits_u64(rest[..slash]) or { return none }
	rest = rest[slash + 1..]
	// complete-length: "*" (none) or 1*DIGIT, consuming the whole remainder.
	complete_length := if rest == '*' {
		?u64(none)
	} else {
		?u64(parse_all_digits_u64(rest) or { return none })
	}
	return ContentRangeValues{
		first_byte_pos:  first_byte_pos
		last_byte_pos:   last_byte_pos
		complete_length: complete_length
	}
}

// https://fetch.spec.whatwg.org/#concept-header-extract-content-range-values
pub fn (list &HeaderList) extract_content_range_values() ?ContentRangeValues {
	// 1-2. The value of the first `Content-Range` header; failure (none) when absent.
	content_range_value := list.get('Content-Range') or { return none }
	// 3-8. Parse it as a single byte content-range; failure (none) on a parse error.
	return parse_single_byte_content_range_as_values(content_range_value)
}

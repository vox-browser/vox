// Copyright (c) 2022, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the self-contained HeaderList operations of LibHTTP/HeaderList.cpp — combine and
// extract a length.
// https://fetch.spec.whatwg.org/#concept-header-list

module http

import strconv

// https://fetch.spec.whatwg.org/#concept-header-list-combine — set the first matching header's value to
// "<existing>, <value>", or append the header when there is no match.
pub fn (mut list HeaderList) combine(header Header) {
	for i in 0 .. list.headers.len {
		if equals_ignoring_ascii_case(list.headers[i].name, header.name) {
			list.headers[i].value = '${list.headers[i].value}, ${header.value}'
			return
		}
	}
	list.append(header)
}

// The three-way result of extracting a length: null (no usable Content-Length), a length, or failure
// (conflicting Content-Length values). Mirrors upstream Variant<Empty, u64, ExtractLengthFailure>.
pub struct ExtractLengthNull {}

pub struct ExtractLengthFailure {}

pub type ExtractLength = ExtractLengthNull | u64 | ExtractLengthFailure

// https://fetch.spec.whatwg.org/#concept-header-extract-length
pub fn (list &HeaderList) extract_length() ExtractLength {
	// 1-2. Get/decode/split `Content-Length`; null if absent.
	values := list.get_decode_and_split('Content-Length') or { return ExtractLengthNull{} }
	// 3-4. All values must agree; conflicting values are a failure.
	mut candidate_value := ?string(none)
	for value in values {
		if candidate := candidate_value {
			if value != candidate {
				return ExtractLengthFailure{}
			}
		} else {
			candidate_value = value
		}
	}
	candidate := candidate_value or { return ExtractLengthNull{} }
	// 5. An empty string or any non-ASCII-digit code point yields null.
	if candidate.len == 0 {
		return ExtractLengthNull{}
	}
	for b in candidate.bytes() {
		if b < `0` || b > `9` {
			return ExtractLengthNull{}
		}
	}
	// 6. Return the candidate interpreted as a decimal number (null if it overflows u64).
	length := strconv.parse_uint(candidate, 10, 64) or { return ExtractLengthNull{} }
	return length
}

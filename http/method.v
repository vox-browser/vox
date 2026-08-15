// Copyright (c) 2022, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibHTTP/Method.cpp — the Fetch HTTP method operations: the method token
// check, the CORS-safelisted and forbidden method predicates, and method normalization.
// https://fetch.spec.whatwg.org/#methods
module http

// A byte that is a valid method token character (RFC 7230 tchar: DIGIT / ALPHA / a set of punctuation).
fn is_method_token_byte(b u8) bool {
	if (b >= `A` && b <= `Z`) || (b >= `a` && b <= `z`) || (b >= `0` && b <= `9`) {
		return true
	}
	return match b {
		`!`, `#`, `$`, `%`, `&`, `'`, `*`, `+`, `-`, `.`, `^`, `_`, `|`, `~` { true }
		0x60 { true } // backtick
		else { false }
	}
}

// https://fetch.spec.whatwg.org/#concept-method — a method is a non-empty sequence of method token
// characters (the token production).
pub fn is_method(method string) bool {
	if method.len == 0 {
		return false
	}
	for b in method.bytes() {
		if !is_method_token_byte(b) {
			return false
		}
	}
	return true
}

// https://fetch.spec.whatwg.org/#cors-safelisted-method — GET, HEAD, or POST (matched case-sensitively;
// methods are normalized to uppercase before this check).
pub fn is_cors_safelisted_method(method string) bool {
	return method in ['GET', 'HEAD', 'POST']
}

// https://fetch.spec.whatwg.org/#forbidden-method — a byte-case-insensitive match for CONNECT, TRACE, or
// TRACK.
pub fn is_forbidden_method(method string) bool {
	return ascii_lowercase(method) in ['connect', 'trace', 'track']
}

// https://fetch.spec.whatwg.org/#concept-method-normalize — byte-uppercase the method when it is a
// byte-case-insensitive match for one of the standard methods; otherwise leave it unchanged.
pub fn normalize_method(method string) string {
	return match ascii_lowercase(method) {
		'delete' { 'DELETE' }
		'get' { 'GET' }
		'head' { 'HEAD' }
		'options' { 'OPTIONS' }
		'post' { 'POST' }
		'put' { 'PUT' }
		else { method }
	}
}

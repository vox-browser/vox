// Copyright (c) 2022-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/ReferrerPolicy/ReferrerPolicy.cpp and the self-contained core of
// AbstractOperations.cpp — the ReferrerPolicy enum, its string conversions, the default policy, and the
// policy-selection half of "parse a referrer policy from a Referrer-Policy header".
//
// OUT OF SCOPE: strip-url-for-use-as-referrer (URL mutation + Fetch local-scheme list), determine-a-
// request's-referrer and set-request's-referrer-policy-on-redirect (Fetch Request/Response, DOM Document,
// HTML Window, SecureContexts). Extracting the header-list values (step 1 of parse-from-header) is a
// generic Fetch/HTTP operation, so the parse function here takes the already-extracted tokens.
// https://w3c.github.io/webappsec-referrer-policy/
module referrerpolicy

// https://w3c.github.io/webappsec-referrer-policy/#enumdef-referrerpolicy
pub enum ReferrerPolicy {
	empty_string
	no_referrer
	no_referrer_when_downgrade
	same_origin
	origin
	strict_origin
	origin_when_cross_origin
	strict_origin_when_cross_origin
	unsafe_url
}

// https://w3c.github.io/webappsec-referrer-policy/#default-referrer-policy
pub const default_referrer_policy = ReferrerPolicy.strict_origin_when_cross_origin

// The token for a referrer policy ("" for the empty-string policy).
pub fn to_string(referrer_policy ReferrerPolicy) string {
	return match referrer_policy {
		.empty_string { '' }
		.no_referrer { 'no-referrer' }
		.no_referrer_when_downgrade { 'no-referrer-when-downgrade' }
		.same_origin { 'same-origin' }
		.origin { 'origin' }
		.strict_origin { 'strict-origin' }
		.origin_when_cross_origin { 'origin-when-cross-origin' }
		.strict_origin_when_cross_origin { 'strict-origin-when-cross-origin' }
		.unsafe_url { 'unsafe-url' }
	}
}

// The referrer policy for a token: the empty string maps to the empty-string policy, a known token
// (matched ASCII case-insensitively) to that policy, and anything else to none.
pub fn from_string(input string) ?ReferrerPolicy {
	if input == '' {
		return ReferrerPolicy.empty_string
	}
	return match ascii_lowercase(input) {
		'no-referrer' { ReferrerPolicy.no_referrer }
		'no-referrer-when-downgrade' { ReferrerPolicy.no_referrer_when_downgrade }
		'same-origin' { ReferrerPolicy.same_origin }
		'origin' { ReferrerPolicy.origin }
		'strict-origin' { ReferrerPolicy.strict_origin }
		'origin-when-cross-origin' { ReferrerPolicy.origin_when_cross_origin }
		'strict-origin-when-cross-origin' { ReferrerPolicy.strict_origin_when_cross_origin }
		'unsafe-url' { ReferrerPolicy.unsafe_url }
		else { none }
	}
}

// https://w3c.github.io/webappsec-referrer-policy/#parse-referrer-policy-from-header
// Steps 2-4: given the tokens extracted from the `Referrer-Policy` header list, return the last token
// that is a referrer policy other than the empty string, or the empty-string policy if there is none.
pub fn parse_a_referrer_policy_from_header_tokens(policy_tokens []string) ReferrerPolicy {
	// 2. Let policy be the empty string.
	mut policy := ReferrerPolicy.empty_string
	// 3. For each token: if it is a (non-empty-string) referrer policy, set policy to it.
	for token in policy_tokens {
		if referrer_policy := from_string(token) {
			if referrer_policy != .empty_string {
				policy = referrer_policy
			}
		}
	}
	// 4. Return policy.
	return policy
}

// ASCII-lowercase a string (matching equals_ignoring_ascii_case for the known tokens).
fn ascii_lowercase(input string) string {
	mut bytes := input.bytes()
	for i, ch in bytes {
		if ch >= `A` && ch <= `Z` {
			bytes[i] = ch + 0x20
		}
	}
	return bytes.bytestr()
}

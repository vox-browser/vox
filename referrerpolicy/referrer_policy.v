// Copyright (c) 2022-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/ReferrerPolicy/ReferrerPolicy.cpp and the self-contained core of
// AbstractOperations.cpp — the ReferrerPolicy enum, its string conversions, the default policy, and the
// policy-selection and request integration algorithms.
// https://w3c.github.io/webappsec-referrer-policy/
module referrerpolicy

import dom
import fetch
import referrercore

// https://w3c.github.io/webappsec-referrer-policy/#enumdef-referrerpolicy
pub type ReferrerPolicy = dom.ReferrerPolicy

// https://w3c.github.io/webappsec-referrer-policy/#default-referrer-policy
pub const default_referrer_policy = dom.ReferrerPolicy.strict_origin_when_cross_origin

// The token for a referrer policy ("" for the empty-string policy).
pub fn to_string(referrer_policy dom.ReferrerPolicy) string {
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
	return referrercore.parse_a_referrer_policy_from_header_tokens(policy_tokens)
}

// https://w3c.github.io/webappsec-referrer-policy/#parse-referrer-policy-from-header
pub fn parse_a_referrer_policy_from_a_referrer_policy_header(response &fetch.Response) ReferrerPolicy {
	return referrercore.parse_a_referrer_policy_from_header_list(response.header_list)
}

// https://w3c.github.io/webappsec-referrer-policy/#set-requests-referrer-policy-on-redirect
pub fn set_request_referrer_policy_on_redirect(mut request fetch.Request, response &fetch.Response) {
	policy := parse_a_referrer_policy_from_a_referrer_policy_header(response)
	if policy != .empty_string {
		request.referrer_policy = to_string(policy)
	}
}

pub enum OriginOnly {
	no
	yes
}

// https://w3c.github.io/webappsec-referrer-policy/#strip-url
pub fn strip_url_for_use_as_referrer(input ?dom.URL, origin_only OriginOnly) ?dom.URL {
	return referrercore.strip_url_for_use_as_referrer(input, if origin_only == .yes {
		referrercore.OriginOnly.yes
	} else {
		referrercore.OriginOnly.no
	})
}

// The independent core is also called by Fetch's main-fetch step. Keeping the
// request projection here avoids a Fetch -> ReferrerPolicy -> Fetch cycle.
pub fn determine_requests_referrer(request &fetch.Request) ?dom.URL {
	return referrercore.determine_requests_referrer(request.referrer_policy,
		request.referrer_source(), request.current_url())
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

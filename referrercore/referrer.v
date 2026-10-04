// Copyright (c) 2022-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/ReferrerPolicy/ReferrerPolicy.cpp and the self-contained core of
// AbstractOperations.cpp — the ReferrerPolicy enum, its string conversions, the default policy, and the
// policy-selection and request integration algorithms.
// https://w3c.github.io/webappsec-referrer-policy/
module referrercore

import dom
import http
import securecontexts

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
pub fn from_string(input string) ?dom.ReferrerPolicy {
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

// AbstractOperations.cpp:28–41. This existing Source token loop is shared
// by the Response wrapper and Fetch's acyclic HTTP redirect caller.
pub fn parse_a_referrer_policy_from_header_tokens(policy_tokens []string) ReferrerPolicy {
	mut policy := ReferrerPolicy.empty_string
	for token in policy_tokens {
		if referrer_policy := from_string(token) {
			if referrer_policy != .empty_string {
				policy = referrer_policy
			}
		}
	}
	return policy
}

// AbstractOperations.cpp:23–41 reads only Response's actual HeaderList.
// The owning Response passes that same list across V's acyclic module graph.
pub fn parse_a_referrer_policy_from_header_list(list &http.HeaderList) ReferrerPolicy {
	policy_tokens := list.extract_header_list_values('Referrer-Policy') or {
		return .empty_string
	}
	return parse_a_referrer_policy_from_header_tokens(policy_tokens)
}

pub enum OriginOnly {
	no
	yes
}

// https://w3c.github.io/webappsec-referrer-policy/#strip-url
pub fn strip_url_for_use_as_referrer(input ?dom.URL, origin_only OriginOnly) ?dom.URL {
	mut url := input or { return none }
	if url.scheme() in ['about', 'blob', 'data'] {
		return none
	}
	url = url.with_username('').with_password('')
	url.set_fragment(none)
	if origin_only == .yes {
		url = url.with_pathname('/')
		url = url.with_query(none)
	}
	return url
}

fn is_downgrade(source dom.URL, destination dom.URL) bool {
	return securecontexts.is_url_potentially_trustworthy(source) == .potentially_trustworthy
		&& securecontexts.is_url_potentially_trustworthy(destination) == .not_trustworthy
}

fn same_origin(a dom.URL, b dom.URL) bool {
	left := a.origin()
	right := b.origin()
	return left.value != 'opaque' && left.value != '' && left.value == right.value
}

// https://w3c.github.io/webappsec-referrer-policy/#determine-requests-referrer
pub fn determine_requests_referrer(policy_token string, source_url ?dom.URL, destination dom.URL) ?dom.URL {
	policy := from_string(policy_token) or { panic('invalid request referrer policy') }
	if policy == .empty_string {
		return none
	}
	source := source_url or { return none }
	mut referrer_url := strip_url_for_use_as_referrer(source, .no)
	referrer_origin := strip_url_for_use_as_referrer(source, .yes)
	if url := referrer_url {
		if url.serialize().len > 4096 {
			referrer_url = referrer_origin
		}
	}
	return match policy {
		.no_referrer {
			none
		}
		.origin {
			referrer_origin
		}
		.unsafe_url {
			referrer_url
		}
		.strict_origin {
			if url := referrer_url {
				if is_downgrade(url, destination) {
					none
				} else {
					referrer_origin
				}
			} else {
				none
			}
		}
		.strict_origin_when_cross_origin {
			if url := referrer_url {
				if same_origin(url, destination) {
					referrer_url
				} else if is_downgrade(url, destination) {
					none
				} else {
					referrer_origin
				}
			} else {
				none
			}
		}
		.same_origin {
			if url := referrer_url {
				if same_origin(url, destination) {
					referrer_url
				} else {
					none
				}
			} else {
				none
			}
		}
		.origin_when_cross_origin {
			if url := referrer_url {
				if same_origin(url, destination) {
					referrer_url
				} else {
					referrer_origin
				}
			} else {
				none
			}
		}
		.no_referrer_when_downgrade {
			if url := referrer_url {
				if is_downgrade(url, destination) {
					none
				} else {
					referrer_url
				}
			} else {
				none
			}
		}
		.empty_string {
			none
		}
	}
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

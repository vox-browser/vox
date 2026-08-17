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
import securecontexts

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

// https://w3c.github.io/webappsec-referrer-policy/#parse-referrer-policy-from-header
pub fn parse_a_referrer_policy_from_a_referrer_policy_header(response &fetch.Response) ReferrerPolicy {
	policy_tokens := response.header_list.get_decode_and_split('Referrer-Policy') or {
		return .empty_string
	}
	return parse_a_referrer_policy_from_header_tokens(policy_tokens)
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
pub fn determine_requests_referrer(request &fetch.Request) ?dom.URL {
	policy := from_string(request.referrer_policy) or { panic('invalid request referrer policy') }
	if policy == .empty_string || request.referrer.sentinel == .no_referrer {
		return none
	}
	mut source := dom.URL{}
	if explicit := request.referrer.url {
		source = explicit
	} else {
		if request.client_origin_opaque {
			return none
		}
		if request.client_is_window {
			source = request.client_document_url or { return none }
		} else {
			source = request.client_creation_url or { return none }
		}
	}
	mut referrer_url := strip_url_for_use_as_referrer(source, .no)
	referrer_origin := strip_url_for_use_as_referrer(source, .yes)
	if url := referrer_url {
		if url.serialize().len > 4096 {
			referrer_url = referrer_origin
		}
	}
	destination := request.current_url()
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

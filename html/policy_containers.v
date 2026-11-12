// Copyright (c) 2022, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2024, Andrew Kaster <akaster@serenityos.org>
// Copyright (c) 2025, Luke Wilde <luke@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of PolicyContainers.cpp, SerializedPolicyContainer.cpp, and the
// policy record types they use.
module html

import dom
import fetch
import contentsecuritypolicy
import referrercore

pub type ReferrerPolicy = dom.ReferrerPolicy

pub fn referrer_policy_from_string(value string) ?ReferrerPolicy {
	return match ascii_lowercase_string(value) {
		'' { ReferrerPolicy.empty_string }
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

pub type CSPPolicyDisposition = dom.CSPPolicyDisposition

pub type CSPPolicySource = dom.CSPPolicySource

pub type SerializedCSPDirective = dom.SerializedCSPDirective

pub type SerializedCSPPolicy = dom.SerializedCSPPolicy

pub type IntegrityPolicy = dom.IntegrityPolicy

pub type SerializedPolicyContainer = dom.SerializedPolicyContainer

pub type PolicyContainer = dom.PolicyContainer

pub fn create_a_policy_container_from_serialized_policy_container(serialized SerializedPolicyContainer) PolicyContainer {
	mut csp_list := []dom.SerializedCSPPolicy{cap: serialized.csp_list.len}
	for policy in serialized.csp_list {
		csp_list << policy.clone()
	}
	return dom.PolicyContainer{
		csp_list: csp_list
		embedder_policy: serialized.embedder_policy
		referrer_policy: serialized.referrer_policy
	}
}

$if test {
	fn parse_response_csp_policy(value string, disposition CSPPolicyDisposition, origin dom.Origin) SerializedCSPPolicy {
		// Compatibility String-input adapter. Genuine Response headers use the
		// Source response/ByteString parser at the factory caller separately.
		parsed := contentsecuritypolicy.parse_a_serialized_csp(value, .header, if disposition == .enforce {
			.enforce
		} else {
			.report
		})
		mut directives := []dom.SerializedCSPDirective{}
		for directive in parsed.directives() {
			directives << dom.SerializedCSPDirective{
				name: directive.name()
				value: directive.value()
			}
		}
		return dom.SerializedCSPPolicy{
			directives: directives
			disposition: disposition
			source: .header
			self_origin: origin
			pre_parsed_policy_string: parsed.pre_parsed_policy_string()
		}
	}
}

fn source_serialized_csp_policy_for_dom(policy contentsecuritypolicy.SerializedPolicy) SerializedCSPPolicy {
	mut directives := []dom.SerializedCSPDirective{cap: policy.directives.len}
	for directive in policy.directives {
		directives << dom.SerializedCSPDirective{
			name: directive.name
			value: directive.value.clone()
		}
	}
	// This is the explicit serialized DOM/native PolicyList representation
	// boundary; copy Policy::serialize fields and the actual typed Origin.
	return dom.SerializedCSPPolicy{
		directives: directives
		disposition: if policy.disposition == .enforce { .enforce } else { .report }
		source: if policy.source == .header { .header } else { .meta }
		self_origin: dom.origin_from_liburl(policy.self_origin)
		pre_parsed_policy_string: policy.pre_parsed_policy_string
	}
}

pub fn create_a_policy_container_from_fetch_response(response &fetch.Response) &PolicyContainer {
	// PolicyContainers.cpp:38–75. Preserve Source's blob/environment,
	// embedder-policy and integrity-policy FIXMEs; all actual defaults remain.
	mut result := &dom.PolicyContainer{}
	policies := contentsecuritypolicy.parse_a_responses_content_security_policies(fetch.csp_response(response))
	for policy in policies.serialize() or { panic(err) } {
		result.csp_list << source_serialized_csp_policy_for_dom(policy)
	}
	parsed_referrer_policy := referrercore.parse_a_referrer_policy_from_header_list(response.header_list)
	if parsed_referrer_policy != .empty_string {
		result.referrer_policy = parsed_referrer_policy
	}
	return result
}

pub fn create_a_policy_container_from_a_fetch_response(response &fetch.Response, _ &EnvironmentSettingsObject) &PolicyContainer {
	return create_a_policy_container_from_fetch_response(response)
}

fn url_scheme(url dom.URL) string {
	colon := url.value.index_u8(`:`)
	if colon <= 0 {
		return ''
	}
	return ascii_lowercase_string(url.value[..colon])
}

// https://html.spec.whatwg.org/multipage/browsers.html#requires-storing-the-policy-container-in-history
pub fn url_requires_storing_the_policy_container_in_history(url dom.URL) bool {
	scheme := url_scheme(url)
	if scheme == 'blob' {
		return false
	}
	return scheme == 'about' || scheme == 'data'
}

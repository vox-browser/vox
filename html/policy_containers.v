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

pub fn (policy ReferrerPolicy) to_string() string {
	return match policy {
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

pub enum CSPPolicyDisposition {
	enforce
	report
}

pub enum CSPPolicySource {
	header
	meta
}

pub struct SerializedCSPDirective {
pub:
	name  string
	value []string
}

pub struct SerializedCSPPolicy {
pub:
	directives               []SerializedCSPDirective
	disposition              CSPPolicyDisposition
	source                   CSPPolicySource
	self_origin              dom.Origin
	pre_parsed_policy_string string
}

fn (policy SerializedCSPPolicy) clone() SerializedCSPPolicy {
	mut directives := []SerializedCSPDirective{cap: policy.directives.len}
	for directive in policy.directives {
		directives << SerializedCSPDirective{
			name: directive.name
			value: directive.value.clone()
		}
	}
	return SerializedCSPPolicy{
		directives: directives
		disposition: policy.disposition
		source: policy.source
		self_origin: policy.self_origin
		pre_parsed_policy_string: policy.pre_parsed_policy_string
	}
}

pub struct IntegrityPolicy {
pub:
	sources              []string
	blocked_destinations []RequestDestination
	endpoints            []string
}

pub fn (policy &IntegrityPolicy) is_empty() bool {
	return policy.sources.len == 0 && policy.blocked_destinations.len == 0 && policy.endpoints.len == 0
}

pub struct SerializedPolicyContainer {
pub:
	csp_list        []SerializedCSPPolicy
	embedder_policy EmbedderPolicy
	referrer_policy ReferrerPolicy
}

@[heap]
pub struct PolicyContainer {
pub:
	csp_list                     []SerializedCSPPolicy
	embedder_policy              EmbedderPolicy
	referrer_policy              ReferrerPolicy = .strict_origin_when_cross_origin
	integrity_policy             IntegrityPolicy
	report_only_integrity_policy IntegrityPolicy
}

// https://html.spec.whatwg.org/multipage/browsers.html#clone-a-policy-container
pub fn (container &PolicyContainer) clone() PolicyContainer {
	mut csp_list := []SerializedCSPPolicy{cap: container.csp_list.len}
	for policy in container.csp_list {
		csp_list << policy.clone()
	}
	return PolicyContainer{
		csp_list: csp_list
		embedder_policy: container.embedder_policy
		referrer_policy: container.referrer_policy
		integrity_policy: container.integrity_policy
	}
}

pub fn (container &PolicyContainer) serialize() SerializedPolicyContainer {
	mut csp_list := []SerializedCSPPolicy{cap: container.csp_list.len}
	for policy in container.csp_list {
		csp_list << policy.clone()
	}
	return SerializedPolicyContainer{
		csp_list: csp_list
		embedder_policy: container.embedder_policy
		referrer_policy: container.referrer_policy
	}
}

pub fn create_a_policy_container_from_serialized_policy_container(serialized SerializedPolicyContainer) PolicyContainer {
	mut csp_list := []SerializedCSPPolicy{cap: serialized.csp_list.len}
	for policy in serialized.csp_list {
		csp_list << policy.clone()
	}
	return PolicyContainer{
		csp_list: csp_list
		embedder_policy: serialized.embedder_policy
		referrer_policy: serialized.referrer_policy
	}
}

fn parse_response_csp_policy(value string, disposition CSPPolicyDisposition, origin dom.Origin) SerializedCSPPolicy {
	mut directives := []SerializedCSPDirective{}
	for raw_directive in value.split(';') {
		parts := raw_directive.trim_space().fields()
		if parts.len == 0 {
			continue
		}
		directives << SerializedCSPDirective{
			name: ascii_lowercase_string(parts[0])
			value: parts[1..].clone()
		}
	}
	return SerializedCSPPolicy{
		directives: directives
		disposition: disposition
		source: .header
		self_origin: origin
		pre_parsed_policy_string: value
	}
}

pub fn create_a_policy_container_from_fetch_response(response &fetch.Response) &PolicyContainer {
	origin := if url := response.url() { url.origin() } else { dom.origin_create_opaque() }
	mut csp_list := []SerializedCSPPolicy{}
	if value := response.header_list.get('Content-Security-Policy') {
		csp_list << parse_response_csp_policy(value, .enforce, origin)
	}
	if value := response.header_list.get('Content-Security-Policy-Report-Only') {
		csp_list << parse_response_csp_policy(value, .report, origin)
	}
	mut referrer_policy := ReferrerPolicy.strict_origin_when_cross_origin
	if value := response.header_list.get('Referrer-Policy') {
		for token in value.split(',') {
			if parsed := referrer_policy_from_string(token.trim_space()) {
				if parsed != .empty_string {
					referrer_policy = parsed
				}
			}
		}
	}
	return &PolicyContainer{
		csp_list: csp_list
		referrer_policy: referrer_policy
	}
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

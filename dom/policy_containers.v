// Copyright (c) 2022, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2024, Jamie Mansfield
// Copyright (c) 2025, Luke Wilde <luke@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause

// Cycle-safe shared records for HTML/PolicyContainers.{h,cpp},
// HTML/SerializedPolicyContainer.h, HTML/EmbedderPolicy.h,
// ReferrerPolicy/ReferrerPolicy.h and Fetch/Infrastructure/HTTP/Requests.h.
// HTML aliases these exact records; Document retains the same actual owner.
// The existing serialized CSP list representation remains a separate boundary.
module dom

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

pub enum EmbedderPolicyValue {
	unsafe_none
	require_corp
	credentialless
}

pub fn (value EmbedderPolicyValue) to_string() string {
	return match value {
		.unsafe_none { 'unsafe-none' }
		.require_corp { 'require-corp' }
		.credentialless { 'credentialless' }
	}
}

pub struct EmbedderPolicy {
pub mut:
	value                          EmbedderPolicyValue = .unsafe_none
	report_only_value              EmbedderPolicyValue = .unsafe_none
	reporting_endpoint             string
	report_only_reporting_endpoint string
}

pub enum RequestDestination {
	audio
	audio_worklet
	document
	embed
	font
	frame
	iframe
	image
	json
	manifest
	object
	paint_worklet
	report
	script
	service_worker
	shared_worker
	style
	text
	track
	video
	web_identity
	worker
	xslt
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
	self_origin              Origin
	pre_parsed_policy_string string
}

pub fn (policy SerializedCSPPolicy) clone() SerializedCSPPolicy {
	mut directives := []SerializedCSPDirective{cap: policy.directives.len}
	for directive in policy.directives {
		directives << SerializedCSPDirective{
			name:  directive.name
			value: directive.value.clone()
		}
	}
	return SerializedCSPPolicy{
		directives:               directives
		disposition:              policy.disposition
		source:                   policy.source
		self_origin:              policy.self_origin
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
pub mut:
	csp_list        []SerializedCSPPolicy
	referrer_policy ReferrerPolicy = .strict_origin_when_cross_origin
pub:
	embedder_policy              EmbedderPolicy
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
		csp_list:         csp_list
		embedder_policy:  container.embedder_policy
		referrer_policy:  container.referrer_policy
		integrity_policy: container.integrity_policy
	}
}

pub fn (container &PolicyContainer) serialize() SerializedPolicyContainer {
	mut csp_list := []SerializedCSPPolicy{cap: container.csp_list.len}
	for policy in container.csp_list {
		csp_list << policy.clone()
	}
	return SerializedPolicyContainer{
		csp_list:        csp_list
		embedder_policy: container.embedder_policy
		referrer_policy: container.referrer_policy
	}
}

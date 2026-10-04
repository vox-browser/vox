// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Policy, PolicyList and response policy parsing.
module contentsecuritypolicy

import url
import http

pub enum Disposition {
	enforce
	report
}

pub enum PolicySource {
	header
	meta
}

@[heap]
pub struct Policy {
pub mut:
	self_origin ?url.Origin
mut:
	directives_               []Directive
	disposition_              Disposition
	source_                   PolicySource
	pre_parsed_policy_string_ string
}

pub fn parse_a_serialized_csp(serialized string, source PolicySource, disposition Disposition) &Policy {
	mut policy := &Policy{
		disposition_:              disposition
		source_:                   source
		pre_parsed_policy_string_: serialized
	}
	for raw_token in serialized.split(';') {
		token := raw_token.trim(' \t\n\r\f')
		// Source StringView::is_ascii() accepts the complete 0x00–0x7F range.
		if token == '' || token.bytes().any(it >= 0x80) {
			continue
		}
		mut split_at := 0
		for split_at < token.len && token[split_at] !in [` `, `\t`, `\n`, `\r`, `\f`] {
			split_at++
		}
		name := token[..split_at].to_lower()
		if policy.contains_directive_with_name(name) {
			continue
		}
		value := if split_at < token.len {
			token[split_at..].split_any(' \t\n\r\f').filter(it != '')
		} else {
			[]string{}
		}
		policy.directives_ << create_directive(name, value)
	}
	return policy
}

pub fn Policy.parse_a_serialized_csp(serialized string, source PolicySource, disposition Disposition) &Policy {
	return parse_a_serialized_csp(serialized, source, disposition)
}

pub fn parse_a_serialized_csp_bytes(serialized []u8, source PolicySource, disposition Disposition) &Policy {
	// Policy.cpp:32–35 selects LibTextCodec's isomorphic byte decoding.
	// Decoder.cpp:584–596 appends each byte as the same-valued code point.
	return parse_a_serialized_csp(serialized.map(rune(it)).string(), source, disposition)
}

pub fn Policy.parse_a_serialized_csp_bytes(serialized []u8, source PolicySource, disposition Disposition) &Policy {
	return parse_a_serialized_csp_bytes(serialized, source, disposition)
}

fn response_csp_header_list(response &Response) &http.HeaderList {
	if actual := response.header_list {
		return actual
	}
	// Explicit adapter for standalone records predating the native HeaderList
	// projection. Genuine Fetch owners never merge this compatibility map.
	mut list := http.HeaderList.create()
	for name, values in response.headers {
		for value in values {
			list.append(http.Header{name, value})
		}
	}
	return list
}

pub fn parse_a_responses_content_security_policies(response &Response) &PolicyList {
	// Policy.cpp:98–145 extracts enforced values first, then report-only
	// values. Each extracted raw Header ByteString uses isomorphic decoding.
	list := response_csp_header_list(response)
	mut policies := []&Policy{}
	if values := list.extract_header_list_values('Content-Security-Policy') {
		for value in values {
			policy := parse_a_serialized_csp_bytes(value.bytes(), .header, .enforce)
			if policy.directives_.len > 0 {
				policies << policy
			}
		}
	}
	if values := list.extract_header_list_values('Content-Security-Policy-Report-Only') {
		for value in values {
			policy := parse_a_serialized_csp_bytes(value.bytes(), .header, .report)
			if policy.directives_.len > 0 {
				policies << policy
			}
		}
	}
	for mut policy in policies {
		if response_url := response.url {
			policy.self_origin = response_url.origin()
		} else if response.header_list != none {
			// Source's actual Response URL dereference is required here.
			panic('CSP response policy requires the actual Response URL')
		}
	}
	return PolicyList.create(policies)
}

pub fn Policy.parse_a_responses_content_security_policies(response &Response) &PolicyList {
	return parse_a_responses_content_security_policies(response)
}

pub fn (policy &Policy) directives() []Directive {
	return policy.directives_.clone()
}

pub fn (policy &Policy) disposition() Disposition {
	return policy.disposition_
}

pub fn (policy &Policy) source() PolicySource {
	return policy.source_
}

pub fn (policy &Policy) pre_parsed_policy_string() string {
	return policy.pre_parsed_policy_string_
}

pub fn (policy &Policy) contains_directive_with_name(name string) bool {
	for directive in policy.directives_ {
		if directive.name() == name {
			return true
		}
	}
	return false
}

pub fn (policy &Policy) get_directive_by_name(name string) ?Directive {
	for directive in policy.directives_ {
		if directive.name() == name {
			return directive
		}
	}
	return none
}

pub fn (policy &Policy) self_origin_value() url.Origin {
	return policy.self_origin or { url.Origin.opaque([16]u8{}, .standard) }
}

pub fn (policy &Policy) clone() &Policy {
	mut directives := []Directive{}
	for directive in policy.directives_ {
		directives << directive.clone()
	}
	return &Policy{
		directives_:               directives
		disposition_:              policy.disposition_
		source_:                   policy.source_
		self_origin:              policy.self_origin
		pre_parsed_policy_string_: policy.pre_parsed_policy_string_
	}
}

pub fn (mut policy Policy) remove_directive(name string) {
	policy.directives_ = policy.directives_.filter(it.name() != name)
}

pub fn (mut policy Policy) set_self_origin(origin url.Origin) {
	policy.self_origin = origin
}

@[heap]
pub struct PolicyList {
pub mut:
	policies []&Policy
}

pub fn PolicyList.create(policies []&Policy) &PolicyList {
	return &PolicyList{
		policies: policies.clone()
	}
}

pub fn PolicyList.from_object(global &GlobalContext) ?&PolicyList {
	if isnil(global.policy_list) {
		return none
	}
	return global.policy_list
}

pub fn (list &PolicyList) contains_header_delivered_policy() bool {
	for policy in list.policies {
		if policy.source() == .header {
			return true
		}
	}
	return false
}

pub fn (list &PolicyList) csp_derived_sandboxing_flags() SandboxingFlagSet {
	mut found := ?Directive(none)
	for policy in list.policies {
		if policy.disposition() == .enforce {
			if directive := policy.get_directive_by_name(sandbox) {
				found = directive
			}
		}
	}
	if directive := found {
		return parse_a_sandboxing_directive(directive.value())
	}
	return SandboxingFlagSet{}
}

pub fn (mut list PolicyList) enforce_policy(policy &Policy) {
	list.policies << policy
}

pub fn (list &PolicyList) clone() &PolicyList {
	mut policies := []&Policy{}
	for policy in list.policies {
		policies << policy.clone()
	}
	return PolicyList.create(policies)
}

pub fn Policy.create_from_serialized_policy(serialized SerializedPolicy) &Policy {
	mut directives := []Directive{}
	for directive in serialized.directives {
		directives << create_directive(directive.name, directive.value)
	}
	return &Policy{
		directives_:               directives
		disposition_:              serialized.disposition
		source_:                   serialized.source
		self_origin:              serialized.self_origin
		pre_parsed_policy_string_: serialized.pre_parsed_policy_string
	}
}

pub fn PolicyList.create_from_serialized_policies(serialized []SerializedPolicy) &PolicyList {
	mut policies := []&Policy{}
	for policy in serialized {
		policies << Policy.create_from_serialized_policy(policy)
	}
	return PolicyList.create(policies)
}

pub fn (policy &Policy) serialize() !SerializedPolicy {
	origin := policy.self_origin or { return error('Policy has no self origin') }
	mut directives := []SerializedDirective{}
	for directive in policy.directives_ {
		directives << directive.serialize()
	}
	return SerializedPolicy{
		directives:               directives
		disposition:              policy.disposition_
		source:                   policy.source_
		self_origin:              origin
		pre_parsed_policy_string: policy.pre_parsed_policy_string_
	}
}

pub fn (list &PolicyList) serialize() ![]SerializedPolicy {
	mut policies := []SerializedPolicy{}
	for policy in list.policies {
		policies << policy.serialize()!
	}
	return policies
}

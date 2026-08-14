// Copyright (c) 2024, Jamie Mansfield <jmansfield@cadixdev.org>
// Copyright (c) 2025, Luke Wilde <luke@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/EmbedderPolicy.cpp.
module html

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

pub fn embedder_policy_value_from_string(value string) ?EmbedderPolicyValue {
	return match ascii_lowercase_string(value) {
		'unsafe-none' { EmbedderPolicyValue.unsafe_none }
		'require-corp' { EmbedderPolicyValue.require_corp }
		'credentialless' { EmbedderPolicyValue.credentialless }
		else { none }
	}
}

pub struct EmbedderPolicy {
pub mut:
	value                          EmbedderPolicyValue = .unsafe_none
	report_only_value              EmbedderPolicyValue = .unsafe_none
	reporting_endpoint             string
	report_only_reporting_endpoint string
}

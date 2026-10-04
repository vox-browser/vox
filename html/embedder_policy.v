// Copyright (c) 2024, Jamie Mansfield <jmansfield@cadixdev.org>
// Copyright (c) 2025, Luke Wilde <luke@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/EmbedderPolicy.cpp.
module html

import dom

pub type EmbedderPolicyValue = dom.EmbedderPolicyValue

pub fn embedder_policy_value_from_string(value string) ?EmbedderPolicyValue {
	return match ascii_lowercase_string(value) {
		'unsafe-none' { EmbedderPolicyValue.unsafe_none }
		'require-corp' { EmbedderPolicyValue.require_corp }
		'credentialless' { EmbedderPolicyValue.credentialless }
		else { none }
	}
}

pub type EmbedderPolicy = dom.EmbedderPolicy

// Copyright (c) 2024, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the X-Frame-Options algorithm in NavigationParams.cpp.
module html

import dom

fn csp_policy_contains_frame_ancestors(policy SerializedCSPPolicy) bool {
	for directive in policy.directives {
		if directive.name == 'frame-ancestors' {
			return true
		}
	}
	return false
}

fn append_unique_ascii_lowercase(mut values []string, value string) {
	normalized := ascii_lowercase_string(value)
	if normalized !in values {
		values << normalized
	}
}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#check-a-navigation-response's-adherence-to-x-frame-options
// Response header decoding and navigable ancestry walking are performed by the
// caller; this function translates the decision algorithm after those two
// dependency operations have produced their values.
pub fn check_a_navigation_responses_adherence_to_x_frame_options(is_child_navigable bool, csp_list []SerializedCSPPolicy, raw_x_frame_options []string, container_document_origins []dom.Origin, destination_origin dom.Origin) bool {
	if !is_child_navigable {
		return true
	}

	for policy in csp_list {
		if policy.disposition != .enforce {
			continue
		}
		if csp_policy_contains_frame_ancestors(policy) {
			return true
		}
	}

	mut x_frame_options := []string{}
	for value in raw_x_frame_options {
		append_unique_ascii_lowercase(mut x_frame_options, value)
	}

	if x_frame_options.len > 1 && ('deny' in x_frame_options
		|| 'allowall' in x_frame_options || 'sameorigin' in x_frame_options) {
		return false
	}
	if x_frame_options.len > 1 {
		return true
	}
	if x_frame_options.len > 0 && x_frame_options[0] == 'deny' {
		return false
	}
	if x_frame_options.len > 0 && x_frame_options[0] == 'sameorigin' {
		for container_origin in container_document_origins {
			if !container_origin.is_same_origin(destination_origin) {
				return false
			}
		}
	}
	return true
}

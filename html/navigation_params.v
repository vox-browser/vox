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
pub fn check_a_navigation_responses_adherence_to_x_frame_options(navigable &dom.Navigable, csp_list []SerializedCSPPolicy, raw_x_frame_options []string, destination_origin dom.Origin) bool {
	if navigable.parent() == none {
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
		// Each container document is the next parent navigable's active
		// document. Walking logical parents also works when a container is not
		// hosted in this process.
		mut ancestor := navigable.parent()
		for ancestor != none {
			current := ancestor or { break }
			ancestor_origin := current.active_document_origin() or { return false }
			if !ancestor_origin.is_same_origin(destination_origin) {
				return false
			}
			ancestor = current.parent()
		}
	}
	return true
}

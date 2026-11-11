// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of MixedContent/AbstractOperations.{h,cpp}.
module mixedcontent

import fetch
import mixedcontentcore

pub enum ProhibitsMixedSecurityContexts {
	prohibits_mixed_security_contexts
	does_not_restrict_mixed_security_contexts
}

pub enum SettingsGlobalKind {
	window
	worker
}

// Narrow typed projection of the HTML EnvironmentSettingsObject fields read by
// the upstream mixed-content algorithms.
pub struct EnvironmentSettings {
pub:
	origin_potentially_trustworthy           bool
	global_kind                              SettingsGlobalKind
	ancestor_origins_potentially_trustworthy []bool
	target_browsing_context_is_top_level     bool
}

fn algorithm_context(settings &EnvironmentSettings) mixedcontentcore.EnvironmentSettings {
	return mixedcontentcore.EnvironmentSettings{
		origin_potentially_trustworthy:           settings.origin_potentially_trustworthy
		global_kind:                              if settings.global_kind == .window {
			.window
		} else {
			.worker
		}
		ancestor_origins_potentially_trustworthy: settings.ancestor_origins_potentially_trustworthy
		target_browsing_context_is_top_level:     settings.target_browsing_context_is_top_level
	}
}

pub fn does_settings_prohibit_mixed_security_contexts(settings &EnvironmentSettings) ProhibitsMixedSecurityContexts {
	return if mixedcontentcore.does_settings_prohibit_mixed_security_contexts(algorithm_context(settings)) == .prohibits_mixed_security_contexts {
		.prohibits_mixed_security_contexts
	} else {
		.does_not_restrict_mixed_security_contexts
	}
}

pub fn upgrade_a_mixed_content_request_to_a_potentially_trustworthy_url_if_appropriate(mut request fetch.Request, settings &EnvironmentSettings) {
	if request.url_list.len == 0 { return }
	destination := if value := request.destination {
		?string(fetch.request_destination_to_string(value))
	} else {
		none
	}
	request.url_list[request.url_list.len - 1] = mixedcontentcore.upgraded_request_url(request.current_url(), destination,
		(request.initiator or { fetch.Initiator.download }) == .image_set,
		algorithm_context(settings))
}

pub fn should_fetching_request_be_blocked_as_mixed_content(request &fetch.Request, settings &EnvironmentSettings) fetch.RequestOrResponseBlocking {
	if request.url_list.len == 0 { return .blocked }
	destination := if value := request.destination {
		?string(fetch.request_destination_to_string(value))
	} else {
		none
	}
	return if mixedcontentcore.should_request_be_blocked(request.current_url(), destination,
		algorithm_context(settings))
	{
		.blocked
	} else {
		.allowed
	}
}

pub fn should_response_to_request_be_blocked_as_mixed_content(request &fetch.Request, response &fetch.Response, settings &EnvironmentSettings) fetch.RequestOrResponseBlocking {
	destination := if value := request.destination {
		?string(fetch.request_destination_to_string(value))
	} else {
		none
	}
	return if mixedcontentcore.should_response_be_blocked(response.url(), destination,
		algorithm_context(settings))
	{
		.blocked
	} else {
		.allowed
	}
}

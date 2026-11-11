// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of MixedContent/AbstractOperations.{h,cpp}.
module mixedcontentcore

import dom
import securecontexts

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

fn is_ipv4_address(host string) bool {
	parts := host.split('.')
	if parts.len != 4 {
		return false
	}
	for part in parts {
		if part == '' || part.len > 3 {
			return false
		}
		for character in part.bytes() {
			if !character.is_digit() {
				return false
			}
		}
		if part.int() > 255 {
			return false
		}
	}
	return true
}

fn is_ip_address(url dom.URL) bool {
	host := url.serialized_host().trim('[]')
	return is_ipv4_address(host) || host.contains(':')
}

// https://w3c.github.io/webappsec-mixed-content/#categorize-settings-object
pub fn does_settings_prohibit_mixed_security_contexts(settings &EnvironmentSettings) ProhibitsMixedSecurityContexts {
	if settings.origin_potentially_trustworthy {
		return .prohibits_mixed_security_contexts
	}
	if settings.global_kind == .window {
		for trustworthy in settings.ancestor_origins_potentially_trustworthy {
			if trustworthy {
				return .prohibits_mixed_security_contexts
			}
		}
	}
	return .does_not_restrict_mixed_security_contexts
}

// MixedContent/AbstractOperations.cpp upgrade algorithm. Main fetch runs it
// again for redirects, so callers pass and replace the request's current URL.
pub fn upgraded_request_url(url dom.URL, destination ?string, initiator_is_image_set bool, settings &EnvironmentSettings) dom.URL {
	destination_value := destination or { return url }
	if securecontexts.is_url_potentially_trustworthy(url) == .potentially_trustworthy
		|| is_ip_address(url)
		|| does_settings_prohibit_mixed_security_contexts(settings) == .does_not_restrict_mixed_security_contexts
		|| destination_value !in ['image', 'audio', 'video']
		|| (destination_value == 'image' && initiator_is_image_set) {
		return url
	}
	return if url.scheme() == 'http' { url.with_protocol('https') } else { url }
}

pub fn should_request_be_blocked(url dom.URL, destination ?string, settings &EnvironmentSettings) bool {
	// Blob URLs resolve from the local store, including those created in an
	// opaque-origin sandbox with a secure ancestor. They never use the network.
	if url.scheme() == 'blob' { return false }
	return does_settings_prohibit_mixed_security_contexts(settings) == .prohibits_mixed_security_contexts && securecontexts.is_url_potentially_trustworthy(url) != .potentially_trustworthy && !(destination or {
		''
	} == 'document' && settings.target_browsing_context_is_top_level)
}

pub fn should_response_be_blocked(response_url ?dom.URL, destination ?string, settings &EnvironmentSettings) bool {
	if does_settings_prohibit_mixed_security_contexts(settings) == .does_not_restrict_mixed_security_contexts || (destination or {
		''
	} == 'document' && settings.target_browsing_context_is_top_level) {
		return false
	}
	if record := response_url {
		if record.scheme() == 'blob' { return false }
		return securecontexts.is_url_potentially_trustworthy(record) != .potentially_trustworthy
	}
	return true
}

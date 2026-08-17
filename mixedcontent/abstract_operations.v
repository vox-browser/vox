// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of MixedContent/AbstractOperations.{h,cpp}.
module mixedcontent

import dom
import fetch
import html

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

// https://w3c.github.io/webappsec-mixed-content/#upgrade-algorithm
pub fn upgrade_a_mixed_content_request_to_a_potentially_trustworthy_url_if_appropriate(mut request fetch.Request, settings &EnvironmentSettings) {
	if request.url_list.len == 0 {
		return
	}
	url := request.url()
	destination := request.destination or { return }
	initiator_is_image_set := if initiator := request.initiator {
		initiator == .image_set
	} else {
		false
	}
	if html.is_url_potentially_trustworthy(url) || is_ip_address(url)
		|| does_settings_prohibit_mixed_security_contexts(settings) == .does_not_restrict_mixed_security_contexts
		|| destination !in [.image, .audio, .video]
		|| (destination == .image && initiator_is_image_set) {
		return
	}
	if url.scheme() == 'http' {
		request.url_list[0] = url.with_protocol('https')
	}
}

fn top_level_document_exception(request &fetch.Request, settings &EnvironmentSettings) bool {
	destination := request.destination or { return false }
	return destination == .document && settings.target_browsing_context_is_top_level
}

// https://w3c.github.io/webappsec-mixed-content/#should-block-fetch
pub fn should_fetching_request_be_blocked_as_mixed_content(request &fetch.Request, settings &EnvironmentSettings) fetch.RequestOrResponseBlocking {
	if request.url_list.len == 0 {
		return .blocked
	}
	if does_settings_prohibit_mixed_security_contexts(settings) == .does_not_restrict_mixed_security_contexts
		|| html.is_url_potentially_trustworthy(request.url())
		|| top_level_document_exception(request, settings) {
		return .allowed
	}
	return .blocked
}

// https://w3c.github.io/webappsec-mixed-content/#should-block-response
pub fn should_response_to_request_be_blocked_as_mixed_content(request &fetch.Request, response &fetch.Response, settings &EnvironmentSettings) fetch.RequestOrResponseBlocking {
	if does_settings_prohibit_mixed_security_contexts(settings) == .does_not_restrict_mixed_security_contexts
		|| top_level_document_exception(request, settings) {
		return .allowed
	}
	if response_url := response.url() {
		if html.is_url_potentially_trustworthy(response_url) {
			return .allowed
		}
	}
	return .blocked
}

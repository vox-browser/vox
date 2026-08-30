// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of PermissionsPolicy/AutoplayAllowlist.{h,cpp}.
@[has_globals]
module permissionspolicy

import dom

__global autoplay_allowlist_singleton = AutoplayAllowlist{}

pub enum Decision {
	enabled
	disabled
}

enum AllowlistMode {
	default_self
	global
	patterns
}

pub struct AutoplayAllowlist {
mut:
	mode     AllowlistMode
	patterns []dom.Origin
}

pub fn AutoplayAllowlist.new() AutoplayAllowlist {
	return AutoplayAllowlist{}
}

pub fn AutoplayAllowlist.the() &AutoplayAllowlist {
	return &autoplay_allowlist_singleton
}

pub fn (mut allowlist AutoplayAllowlist) enable_globally() {
	allowlist.mode = .global
	allowlist.patterns.clear()
}

pub fn (mut allowlist AutoplayAllowlist) enable_for_origins(origins []string) {
	allowlist.mode = .patterns
	allowlist.patterns.clear()
	for input in origins {
		mut value := input
		// URL::Parser::basic_parse first accepts any absolute URL, including
		// non-hierarchical schemes that do not contain "://". Only retry with
		// https:// when the input has no scheme at all.
		scheme := dom.URL{value}.scheme()
		if scheme == '' {
			value = 'https://${value}'
		} else if scheme in ['http', 'https', 'ws', 'wss'] && !value.contains('://') {
			// WHATWG's special-scheme parser accepts `https:example.test` as a
			// host URL; net.urllib treats it as opaque unless normalized here.
			value = '${scheme}://${value.all_after(':').trim_left('/')}'
		}
		url := dom.dom_url_parse(value, dom.url_about_blank(), 'utf-8') or { continue }
		origin := url.origin()
		if origin.value != 'opaque' {
			allowlist.patterns << origin
		}
	}
}

pub fn (allowlist &AutoplayAllowlist) is_allowed_for_origin(document_origin dom.Origin, document_is_opaque_file bool, origin dom.Origin, origin_is_opaque_file bool) Decision {
	if allowlist.mode == .global {
		return .enabled
	}
	if allowlist.mode == .patterns {
		for pattern in allowlist.patterns {
			if pattern.is_same_origin(origin) {
				return .enabled
			}
			if origin_is_opaque_file && document_is_opaque_file {
				return .enabled
			}
		}
		return .disabled
	}
	if origin.is_same_origin(document_origin) || (origin_is_opaque_file && document_is_opaque_file) {
		return .enabled
	}
	return .disabled
}

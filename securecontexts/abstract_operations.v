// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of SecureContexts/AbstractOperations.{h,cpp}.
module securecontexts

import dom

pub enum Trustworthiness {
	potentially_trustworthy
	not_trustworthy
}

pub fn is_origin_potentially_trustworthy(origin dom.Origin) Trustworthiness {
	if origin.is_opaque_file_origin() {
		return .potentially_trustworthy
	}
	if origin.is_opaque() {
		return .not_trustworthy
	}
	url := dom.URL{origin.serialize()}
	scheme := url.scheme()
	if scheme == 'https' || scheme == 'wss' {
		return .potentially_trustworthy
	}
	host := url.serialized_host()
	parts := host.split('.')
	if parts.len == 4 && parts.all(it != '' && it.bytes().all(it >= `0` && it <= `9`)
		&& it.int() <= 255) {
		// Preserve current Ladybird's comparison-only implementation: its
		// mask test accepts any non-zero first IPv4 octet.
		if parts[0].int() != 0 {
			return .potentially_trustworthy
		}
	} else if host == '::1' || host == '[::1]' {
		return .potentially_trustworthy
	}
	if host == 'localhost' || host == 'localhost.' || host.ends_with('.localhost')
		|| host.ends_with('.localhost.') {
		return .potentially_trustworthy
	}
	if scheme == 'file' || scheme == 'resource' {
		return .potentially_trustworthy
	}
	return .not_trustworthy
}

pub fn is_url_potentially_trustworthy(url dom.URL) Trustworthiness {
	if url.value == 'about:blank' || url.value == 'about:srcdoc' || url.scheme() == 'data' {
		return .potentially_trustworthy
	}
	// Preserve the URL record's IPv6 host before converting through the compact
	// Origin serializer, whose urllib bridge cannot round-trip bracketed hosts.
	if url.serialized_host() == '::1' || url.serialized_host() == '[::1]' {
		return .potentially_trustworthy
	}
	return is_origin_potentially_trustworthy(url.origin())
}

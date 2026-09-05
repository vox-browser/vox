// Copyright (c) 2025-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of LibURL/Pattern/Canonicalization.cpp.
module urlpattern

import url as liburl

fn dummy_pattern_url() liburl.URL {
	return liburl.parse('https://dummy.invalid/') or { panic('URLPattern dummy URL must parse') }
}

fn canonicalize_pattern_component(value string, kind PatternCanonicalization) !string {
	if value == '' {
		return value
	}
	return match kind {
		.protocol { canonicalize_pattern_protocol(value)! }
		.username { dummy_pattern_url().with_username(value).username }
		.password { dummy_pattern_url().with_password(value).password }
		.hostname { canonicalize_pattern_hostname(value)! }
		.ipv6_hostname { canonicalize_pattern_ipv6_hostname(value)! }
		.port { canonicalize_pattern_port(value, none)! }
		.pathname { canonicalize_pattern_pathname(value)! }
		.opaque_pathname { canonicalize_pattern_opaque_pathname(value)! }
		.search { (dummy_pattern_url().with_query(value).query or { '' }) }
		.hash { (dummy_pattern_url().with_fragment(value).fragment or { '' }) }
	}
}

fn canonicalize_pattern_protocol(value string) !string {
	parsed := liburl.parse('${value}://dummy.invalid') or {
		return error('TypeError: failed to canonicalize URL protocol string')
	}
	return parsed.scheme
}

fn canonicalize_pattern_hostname(value string) !string {
	parsed := liburl.parse('https://${value}/') or {
		return error('TypeError: failed to canonicalize URL hostname string')
	}
	host := parsed.host or { return '' }
	return host.serialize()
}

fn canonicalize_pattern_ipv6_hostname(value string) !string {
	mut result := ''
	for character in value.bytes() {
		if !((character >= `0` && character <= `9`) || (character >= `a` && character <= `f`) || (character >= `A` && character <= `F`) || character in [
			`[`,
			`]`,
			`:`,
		]) {
			return error('TypeError: failed to canonicalize IPv6 hostname string')
		}
		result += character.ascii_str().to_lower_ascii()
	}
	return result
}

fn canonicalize_pattern_port(value string, protocol ?string) !string {
	for character in value.bytes() {
		if character < `0` || character > `9` {
			return error('TypeError: failed to canonicalize port string')
		}
	}
	scheme := protocol or { 'https' }
	parsed := liburl.parse('${scheme}://dummy.invalid:${value}/') or {
		return error('TypeError: failed to canonicalize port string')
	}
	if port := parsed.port {
		return port.str()
	}
	return ''
}

fn canonicalize_pattern_pathname(value string) !string {
	leading_slash := value.starts_with('/')
	modified_value := if leading_slash { value } else { '/-' + value }
	base := dummy_pattern_url()
	parsed := liburl.parse_with_base(modified_value, &base) or {
		return error('TypeError: failed to canonicalize pathname string')
	}
	mut result := parsed.serialize_path()
	if !leading_slash {
		if result.len < 2 {
			return error('TypeError: failed to canonicalize pathname string')
		}
		result = result[2..]
	}
	return result
}

fn canonicalize_pattern_opaque_pathname(value string) !string {
	parsed := liburl.parse('pattern:${value}') or {
		return error('TypeError: failed to canonicalize opaque pathname string')
	}
	return parsed.serialize_path()
}

fn hostname_pattern_is_ipv6_address(input string) bool {
	if input.len < 2 {
		return false
	}
	return input[0] == `[` || (input[0] in [`{`, `\\`] && input[1] == `[`)
}

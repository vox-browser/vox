// Copyright (c) 2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the Host record and its serializer/classifiers from LibURL/Host.cpp/Host.h — a host is
// an IPv4 address, an IPv6 address, a domain string, or a distinct opaque host.
// https://url.spec.whatwg.org/#concept-host
module url

pub struct Ipv4Host {
pub:
	address u32
}

pub struct Ipv6Host {
pub:
	pieces []u16 // eight pieces
}

// https://url.spec.whatwg.org/#opaque-host
pub struct OpaqueHost {
pub:
	value string
}

// A string alternative is a domain or the empty host.
pub type Host = Ipv4Host | Ipv6Host | OpaqueHost | string

pub fn Host.ipv4(address u32) Host {
	return Ipv4Host{
		address: address
	}
}

pub fn Host.ipv6(pieces []u16) Host {
	return Ipv6Host{
		pieces: pieces
	}
}

// A domain or (for the empty string) the empty host.
pub fn Host.from_string(value string) Host {
	return value
}

pub fn Host.opaque(value string) Host {
	return OpaqueHost{ value: value }
}

// https://url.spec.whatwg.org/#concept-domain — a non-empty domain string.
pub fn (host Host) is_domain() bool {
	if host is string {
		return host != ''
	}
	return false
}

// https://url.spec.whatwg.org/#empty-host — the empty string host.
pub fn (host Host) is_empty_host() bool {
	return match host {
		string { host == '' }
		OpaqueHost { host.value == '' }
		else { false }
	}
}

// https://url.spec.whatwg.org/#concept-host-serializer
pub fn (host Host) serialize() string {
	return match host {
		// 1. An IPv4 address serializes as the dotted quad.
		Ipv4Host {
			serialize_ipv4_address(host.address)
		}
		// 2. An IPv6 address serializes in brackets.
		Ipv6Host {
			'[' + serialize_ipv6_address(host.pieces) + ']'
		}
		// 3. A domain, opaque host, or empty host serializes as itself.
		string {
			host
		}
		OpaqueHost {
			host.value
		}
	}
}

// https://url.spec.whatwg.org/#host-public-suffix
pub fn (host Host) public_suffix() ?string {
	if !host.is_domain() {
		return none
	}
	host_string := host as string
	trailing_dot := if host_string.ends_with('.') { '.' } else { '' }
	host_without_trailing_dot := if trailing_dot == '' {
		host_string
	} else {
		host_string[..host_string.len - 1]
	}
	public_suffix := get_public_suffix(host_without_trailing_dot) or {
		last_dot := host_without_trailing_dot.last_index('.') or { -1 }
		host_without_trailing_dot[last_dot + 1..]
	}
	return public_suffix + trailing_dot
}

// https://url.spec.whatwg.org/#host-registrable-domain
pub fn (host Host) registrable_domain() ?string {
	if !host.is_domain() {
		return none
	}
	host_string := host as string
	public_suffix := host.public_suffix() or { return none }
	if public_suffix == host_string {
		return none
	}
	trailing_dot := if host_string.ends_with('.') { '.' } else { '' }
	host_without_trailing_dot := if trailing_dot == '' {
		host_string
	} else {
		host_string[..host_string.len - 1]
	}
	mut registrable := get_registrable_domain(host_without_trailing_dot) or {
		last_dot := host_without_trailing_dot.last_index('.') or { -1 }
		if last_dot >= 0 {
			second_last_dot := host_without_trailing_dot[..last_dot].last_index('.') or { -1 }
			if second_last_dot >= 0 {
				host_without_trailing_dot[second_last_dot + 1..]
			} else {
				host_without_trailing_dot
			}
		} else {
			host_without_trailing_dot
		}
	}
	registrable += trailing_dot
	return registrable
}

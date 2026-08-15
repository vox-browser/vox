// Copyright (c) 2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the Host record and its serializer/classifiers from LibURL/Host.cpp/Host.h — a host is
// an IPv4 address, an IPv6 address, or a string (a domain, an opaque host, or the empty host). The
// public-suffix/registrable-domain methods need the Public Suffix List table and are out of scope.
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

// https://url.spec.whatwg.org/#concept-host — IPv4, IPv6, or a string (domain / opaque host / empty).
pub type Host = Ipv4Host | Ipv6Host | string

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

// A domain, an opaque host, or (for the empty string) the empty host.
pub fn Host.from_string(value string) Host {
	return value
}

// https://url.spec.whatwg.org/#concept-domain — a non-empty string host.
pub fn (host Host) is_domain() bool {
	if host is string {
		return host != ''
	}
	return false
}

// https://url.spec.whatwg.org/#empty-host — the empty string host.
pub fn (host Host) is_empty_host() bool {
	if host is string {
		return host == ''
	}
	return false
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
	}
}

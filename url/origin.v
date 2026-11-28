// Copyright (c) 2020-2025, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the Origin type from LibURL/Origin.cpp/Origin.h — an origin is either a tuple
// (scheme, host, port, domain) or an opaque origin (a nonce and a type). Provides serialize, is_opaque
// (and is_opaque_file_origin), effective_domain, is_same_origin, and is_same_origin_domain. create_opaque
// generates a random nonce upstream; here the nonce is supplied explicitly (Origin.opaque). is_same_site
// needs the Public Suffix List and is out of scope.
// https://html.spec.whatwg.org/multipage/browsers.html#concept-origin
module url

import rand

pub struct OriginTuple {
pub:
	scheme ?string
	host   Host
	port   ?u16
	domain ?string
}

pub enum OpaqueOriginType {
	standard
	file
	sandboxed_file
}

pub struct OpaqueOriginData {
pub:
	nonce [16]u8
	type_ OpaqueOriginType
}

// https://html.spec.whatwg.org/multipage/browsers.html#concept-origin
pub type Origin = OriginTuple | OpaqueOriginData

pub fn Origin.tuple(scheme ?string, host Host, port ?u16, domain ?string) Origin {
	return OriginTuple{
		scheme: scheme
		host:   host
		port:   port
		domain: domain
	}
}

// An opaque origin with an explicit nonce.
pub fn Origin.opaque(nonce [16]u8, type_ OpaqueOriginType) Origin {
	return OpaqueOriginData{
		nonce: nonce
		type_: type_
	}
}

// Origin::create_opaque(). Each invocation gets a fresh 128-bit nonce.
pub fn Origin.create_opaque(type_ OpaqueOriginType) Origin {
	first := rand.u64()
	second := rand.u64()
	mut nonce := [16]u8{}
	for index in 0 .. 8 {
		nonce[index] = u8(first >> (index * 8))
		nonce[index + 8] = u8(second >> (index * 8))
	}
	return Origin.opaque(nonce, type_)
}

fn (origin Origin) as_tuple() ?OriginTuple {
	if origin is OriginTuple {
		return origin
	}
	return none
}

fn (origin Origin) as_opaque() ?OpaqueOriginData {
	if origin is OpaqueOriginData {
		return origin
	}
	return none
}

pub fn (origin Origin) opaque_data() ?OpaqueOriginData {
	return origin.as_opaque()
}

fn opt_string_eq(a ?string, b ?string) bool {
	if x := a {
		if y := b {
			return x == y
		}
		return false
	}
	return b == none
}

fn opt_u16_eq(a ?u16, b ?u16) bool {
	if x := a {
		if y := b {
			return x == y
		}
		return false
	}
	return b == none
}

// https://html.spec.whatwg.org/multipage/origin.html#concept-origin-opaque
pub fn (origin Origin) is_opaque() bool {
	return origin is OpaqueOriginData
}

pub fn (origin Origin) is_opaque_file_origin() bool {
	if opaque := origin.as_opaque() {
		return opaque.type_ == .file
	}
	return false
}

// Sandboxing preserves a local document's ability to fetch adjacent files,
// while its fresh opaque nonce still isolates storage and same-origin access.
pub fn (origin Origin) is_file_origin() bool {
	if opaque := origin.as_opaque() {
		return opaque.type_ in [.file, .sandboxed_file]
	}
	tuple := origin.as_tuple() or { return false }
	return (tuple.scheme or { '' }) == 'file'
}

// https://html.spec.whatwg.org/multipage/origin.html#ascii-serialisation-of-an-origin
pub fn (origin Origin) serialize() string {
	tuple := origin.as_tuple() or {
		// 1. An opaque origin serializes to "null".
		return 'null'
	}
	// 2-6. scheme "://" host, then ":" port when the port is non-null.
	mut result := tuple.scheme or { '' }
	result += '://'
	result += tuple.host.serialize()
	if port := tuple.port {
		result += ':${port}'
	}
	return result
}

// https://html.spec.whatwg.org/multipage/origin.html#concept-origin-effective-domain
pub fn (origin Origin) effective_domain() ?Host {
	// 1. An opaque origin has no effective domain.
	tuple := origin.as_tuple() or { return none }
	// 2. A non-null domain is the effective domain.
	if domain := tuple.domain {
		return Host.from_string(domain)
	}
	// 3. Otherwise the host is.
	return tuple.host
}

// https://html.spec.whatwg.org/multipage/origin.html#same-origin
pub fn (origin Origin) is_same_origin(other Origin) bool {
	// 1. The same opaque origin.
	if a := origin.as_opaque() {
		if b := other.as_opaque() {
			return a.nonce == b.nonce
		}
		return false
	}
	// 2. Both tuple origins with identical scheme, host, and port.
	if a := origin.as_tuple() {
		if b := other.as_tuple() {
			return opt_string_eq(a.scheme, b.scheme) && a.host == b.host
				&& opt_u16_eq(a.port, b.port)
		}
	}
	// 3. Otherwise not same origin.
	return false
}

// https://html.spec.whatwg.org/multipage/origin.html#same-origin-domain
pub fn (origin Origin) is_same_origin_domain(other Origin) bool {
	// 1. The same opaque origin.
	if a := origin.as_opaque() {
		if b := other.as_opaque() {
			return a.nonce == b.nonce
		}
		return false
	}
	// 2. Both tuple origins.
	if a := origin.as_tuple() {
		if b := other.as_tuple() {
			// 1. Identical, non-null domains and identical schemes.
			if a.domain != none && opt_string_eq(a.domain, b.domain)
				&& opt_string_eq(a.scheme, b.scheme) {
				return true
			}
			// 2. Both domains null and same origin.
			if a.domain == none && b.domain == none && origin.is_same_origin(other) {
				return true
			}
		}
	}
	// 3. Otherwise not same origin-domain.
	return false
}

// https://html.spec.whatwg.org/multipage/browsers.html#same-site
pub fn (origin Origin) is_same_site(other Origin) bool {
	if opaque := origin.as_opaque() {
		if other_opaque := other.as_opaque() {
			return opaque.nonce == other_opaque.nonce
		}
		return false
	}
	first := origin.as_tuple() or { return false }
	second := other.as_tuple() or { return false }
	if !opt_string_eq(first.scheme, second.scheme) {
		return false
	}
	first_site_host := if registrable := first.host.registrable_domain() {
		Host.from_string(registrable)
	} else {
		first.host
	}
	second_site_host := if registrable := second.host.registrable_domain() {
		Host.from_string(registrable)
	} else {
		second.host
	}
	return first_site_host == second_site_host
}

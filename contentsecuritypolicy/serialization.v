// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of SerializedDirective.cpp and SerializedPolicy.cpp IPC records.
module contentsecuritypolicy

import url

pub struct SerializedPolicy {
pub:
	directives               []SerializedDirective
	disposition              Disposition
	source                   PolicySource
	self_origin              url.Origin
	pre_parsed_policy_string string
}

fn append_u32(mut output []u8, value u32) {
	output << u8(value >> 24)
	output << u8(value >> 16)
	output << u8(value >> 8)
	output << u8(value)
}

fn append_u16(mut output []u8, value u16) {
	output << u8(value >> 8)
	output << u8(value)
}

fn append_string(mut output []u8, value string) {
	append_u32(mut output, u32(value.len))
	output << value.bytes()
}

fn append_optional_string(mut output []u8, value ?string) {
	if entry := value {
		output << u8(1)
		append_string(mut output, entry)
	} else {
		output << u8(0)
	}
}

struct ByteDecoder {
	data []u8
mut:
	position int
}

fn (mut decoder ByteDecoder) byte() !u8 {
	if decoder.position >= decoder.data.len {
		return error('Unexpected end of serialized CSP')
	}
	value := decoder.data[decoder.position]
	decoder.position++
	return value
}

fn (mut decoder ByteDecoder) u16_value() !u16 {
	return u16(decoder.byte()!) << 8 | u16(decoder.byte()!)
}

fn (mut decoder ByteDecoder) u32_value() !u32 {
	return u32(decoder.byte()!) << 24 | u32(decoder.byte()!) << 16 | u32(decoder.byte()!) << 8 | u32(decoder.byte()!)
}

fn (mut decoder ByteDecoder) string_value() !string {
	length := int(decoder.u32_value()!)
	if length < 0 || decoder.position + length > decoder.data.len {
		return error('Invalid string length in serialized CSP')
	}
	value := decoder.data[decoder.position..decoder.position + length].bytestr()
	decoder.position += length
	return value
}

struct DecodedOptionalString {
	present bool
	value   string
}

fn (mut decoder ByteDecoder) optional_string() !DecodedOptionalString {
	present := decoder.byte()!
	if present == 0 {
		return DecodedOptionalString{}
	}
	if present != 1 {
		return error('Invalid optional string marker')
	}
	return DecodedOptionalString{
		present: true
		value:   decoder.string_value()!
	}
}

fn append_directive(mut output []u8, directive SerializedDirective) {
	append_string(mut output, directive.name)
	append_u32(mut output, u32(directive.value.len))
	for value in directive.value {
		append_string(mut output, value)
	}
}

fn decode_directive_from(mut decoder ByteDecoder) !SerializedDirective {
	name := decoder.string_value()!
	count := int(decoder.u32_value()!)
	mut value := []string{cap: count}
	for _ in 0 .. count {
		value << decoder.string_value()!
	}
	return SerializedDirective{
		name:  name
		value: value
	}
}

pub fn encode_serialized_directive(directive SerializedDirective) []u8 {
	mut output := []u8{}
	append_directive(mut output, directive)
	return output
}

pub fn decode_serialized_directive(data []u8) !SerializedDirective {
	mut decoder := ByteDecoder{
		data: data
	}
	directive := decode_directive_from(mut decoder)!
	if decoder.position != data.len {
		return error('Trailing data after serialized directive')
	}
	return directive
}

fn append_host(mut output []u8, host url.Host) {
	match host {
		url.Ipv4Host {
			output << u8(0)
			append_u32(mut output, host.address)
		}
		url.Ipv6Host {
			output << u8(1)
			for index in 0 .. 8 {
				append_u16(mut output, if index < host.pieces.len {
					host.pieces[index]
				} else {
					u16(0)
				})
			}
		}
		string {
			output << u8(2)
			append_string(mut output, host)
		}
		url.OpaqueHost {
			output << u8(3)
			append_string(mut output, host.value)
		}
	}
}

fn decode_host(mut decoder ByteDecoder) !url.Host {
	return match decoder.byte()! {
		0 {
			url.Host.ipv4(decoder.u32_value()!)
		}
		1 {
			mut pieces := []u16{cap: 8}
			for _ in 0 .. 8 {
				pieces << decoder.u16_value()!
			}
			url.Host.ipv6(pieces)
		}
		2 {
			url.Host.from_string(decoder.string_value()!)
		}
		3 {
			url.Host.opaque(decoder.string_value()!)
		}
		else {
			return error('Invalid host tag in serialized CSP')
		}
	}
}

fn append_origin(mut output []u8, origin url.Origin) {
	match origin {
		url.OriginTuple {
			output << u8(0)
			append_optional_string(mut output, origin.scheme)
			append_host(mut output, origin.host)
			if port := origin.port {
				output << u8(1)
				append_u16(mut output, port)
			} else {
				output << u8(0)
			}
			append_optional_string(mut output, origin.domain)
		}
		url.OpaqueOriginData {
			output << u8(1)
			output << origin.nonce[..]
			output << u8(origin.type_)
		}
	}
}

fn decode_origin(mut decoder ByteDecoder) !url.Origin {
	tag := decoder.byte()!
	if tag == 0 {
		decoded_scheme := decoder.optional_string()!
		scheme := if decoded_scheme.present { ?string(decoded_scheme.value) } else { ?string(none) }
		host := decode_host(mut decoder)!
		port := if decoder.byte()! == 1 { ?u16(decoder.u16_value()!) } else { ?u16(none) }
		decoded_domain := decoder.optional_string()!
		domain := if decoded_domain.present { ?string(decoded_domain.value) } else { ?string(none) }
		return url.Origin.tuple(scheme, host, port, domain)
	}
	if tag == 1 {
		mut nonce := [16]u8{}
		for index in 0 .. 16 {
			nonce[index] = decoder.byte()!
		}
		type_byte := decoder.byte()!
		if type_byte > u8(url.OpaqueOriginType.sandboxed_file) {
			return error('Invalid opaque origin type')
		}
		return url.Origin.opaque(nonce, unsafe { url.OpaqueOriginType(type_byte) })
	}
	return error('Invalid origin tag in serialized CSP')
}

pub fn encode_serialized_policy(policy SerializedPolicy) []u8 {
	mut output := []u8{}
	append_u32(mut output, u32(policy.directives.len))
	for directive in policy.directives {
		append_directive(mut output, directive)
	}
	output << u8(policy.disposition)
	output << u8(policy.source)
	append_origin(mut output, policy.self_origin)
	append_string(mut output, policy.pre_parsed_policy_string)
	return output
}

pub fn decode_serialized_policy(data []u8) !SerializedPolicy {
	mut decoder := ByteDecoder{
		data: data
	}
	count := int(decoder.u32_value()!)
	mut directives := []SerializedDirective{cap: count}
	for _ in 0 .. count {
		directives << decode_directive_from(mut decoder)!
	}
	disposition_byte := decoder.byte()!
	source_byte := decoder.byte()!
	if disposition_byte > u8(Disposition.report) || source_byte > u8(PolicySource.meta) {
		return error('Invalid policy enum in serialized CSP')
	}
	origin := decode_origin(mut decoder)!
	pre_parsed := decoder.string_value()!
	if decoder.position != data.len {
		return error('Trailing data after serialized policy')
	}
	return SerializedPolicy{
		directives:               directives
		disposition:              unsafe { Disposition(disposition_byte) }
		source:                   unsafe { PolicySource(source_byte) }
		self_origin:              origin
		pre_parsed_policy_string: pre_parsed
	}
}

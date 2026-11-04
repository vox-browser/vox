// Copyright (c) 2021-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the URL percent-encoding suite of LibURL/URL.cpp.
// https://url.spec.whatwg.org/#percent-encoded-bytes
module url

// https://url.spec.whatwg.org/#percent-encode-set — each set is a superset of a smaller one.
pub enum PercentEncodeSet {
	c0_control
	fragment
	query
	special_query
	path
	userinfo
	component
	application_x_www_form_urlencoded
	encode_uri
}

// The extra ASCII bytes each set adds on top of its base set.
const fragment_extra = [u8(0x20), 0x22, 0x3C, 0x3E, 0x60] // SP " < > `
const query_extra = [u8(0x20), 0x22, 0x23, 0x3C, 0x3E] // SP " # < >
const path_extra = [u8(0x3F), 0x5E, 0x60, 0x7B, 0x7D] // ? ^ ` { }
const userinfo_extra = [u8(0x2F), 0x3A, 0x3B, 0x3D, 0x40, 0x5B, 0x5C, 0x5D, 0x7C] // / : ; = @ [ \ ] |
const component_extra = [u8(0x24), 0x25, 0x26, 0x2B, 0x2C] // $ % & + ,
const form_urlencoded_extra = [u8(0x21), 0x27, 0x28, 0x29, 0x7E] // ! ' ( ) ~
// The characters JS encodeURI() leaves un-encoded.
const encode_uri_allowed = [u8(0x3B), 0x2C, 0x2F, 0x3F, 0x3A, 0x40, 0x26, 0x3D, 0x2B, 0x24, 0x2D,
	0x5F, 0x2E, 0x21, 0x7E, 0x2A, 0x27, 0x28, 0x29, 0x23] // ; , / ? : @ & = + $ - _ . ! ~ * ' ( ) #

fn code_point_in(code_point u32, chars []u8) bool {
	return code_point <= 0x7F && u8(code_point) in chars
}

fn is_ascii_alphanumeric(code_point u32) bool {
	return (code_point >= `0` && code_point <= `9`)
		|| (code_point >= `A` && code_point <= `Z`)
		|| (code_point >= `a` && code_point <= `z`)
}

// https://url.spec.whatwg.org/#c0-control-percent-encode-set
pub fn code_point_is_in_percent_encode_set(code_point u32, set PercentEncodeSet) bool {
	if !disable_url_ascii_membership {
		if url_ascii_membership_diagnostics { report_url_ascii_membership(false) }
		return percent_encode_set_ascii_membership(code_point, set)
	}
	return code_point_is_in_percent_encode_set_scanning(code_point, set)
}

fn code_point_is_in_percent_encode_set_scanning(code_point u32, set PercentEncodeSet) bool {
	return match set {
		.c0_control {
			code_point < 0x20 || code_point > 0x7E
		}
		.fragment {
			code_point_is_in_percent_encode_set_scanning(code_point, .c0_control)
				|| code_point_in(code_point, fragment_extra)
		}
		.query {
			code_point_is_in_percent_encode_set_scanning(code_point, .c0_control)
				|| code_point_in(code_point, query_extra)
		}
		.special_query {
			code_point_is_in_percent_encode_set_scanning(code_point, .query) || code_point == `'`
		}
		.path {
			code_point_is_in_percent_encode_set_scanning(code_point, .query)
				|| code_point_in(code_point, path_extra)
		}
		.userinfo {
			code_point_is_in_percent_encode_set_scanning(code_point, .path)
				|| code_point_in(code_point, userinfo_extra)
		}
		.component {
			code_point_is_in_percent_encode_set_scanning(code_point, .userinfo)
				|| code_point_in(code_point, component_extra)
		}
		.application_x_www_form_urlencoded {
			code_point_is_in_percent_encode_set_scanning(code_point, .component)
				|| code_point_in(code_point, form_urlencoded_extra)
		}
		.encode_uri {
			code_point > 0x7E || (!is_ascii_alphanumeric(code_point)
				&& !code_point_in(code_point, encode_uri_allowed))
		}
	}
}

// Append the UTF-8 bytes of a code point, each as %XX.
fn percent_encode_code_point(code_point u32) string {
	mut result := ''
	for b in rune(code_point).bytes() {
		result += '%${b:02X}'
	}
	return result
}

// https://url.spec.whatwg.org/#string-percent-encode-after-encoding — percent-encode every code point of
// input that is in `set`. With space_as_plus, a space is written as '+' instead.
pub fn percent_encode(input string, set PercentEncodeSet, space_as_plus bool) string {
	mut builder := ''
	for code_point in input.runes() {
		cp := u32(code_point)
		if space_as_plus && cp == u32(` `) {
			builder += '+'
		} else if code_point_is_in_percent_encode_set(cp, set) {
			builder += percent_encode_code_point(cp)
		} else {
			builder += code_point.str()
		}
	}
	return builder
}

fn is_ascii_hex_digit(b u8) bool {
	return (b >= `0` && b <= `9`) || (b >= `A` && b <= `F`) || (b >= `a` && b <= `f`)
}

fn parse_ascii_hex_digit(b u8) u8 {
	if b >= `0` && b <= `9` {
		return b - `0`
	}
	if b >= `A` && b <= `F` {
		return b - `A` + 10
	}
	return b - `a` + 10
}

// https://url.spec.whatwg.org/#percent-decode — decode %XX sequences into a byte sequence, leaving a lone
// or malformed '%' as-is.
pub fn percent_decode(input string) []u8 {
	bytes := input.bytes()
	if !input.contains('%') {
		return bytes.clone()
	}
	mut output := []u8{}
	mut i := 0
	for i < bytes.len {
		if bytes[i] != `%` {
			output << bytes[i]
		} else if i + 2 >= bytes.len || !is_ascii_hex_digit(bytes[i + 1])
			|| !is_ascii_hex_digit(bytes[i + 2]) {
			output << bytes[i]
		} else {
			output << (parse_ascii_hex_digit(bytes[i + 1]) << 4) | parse_ascii_hex_digit(bytes[i + 2])
			i += 2
		}
		i++
	}
	return output
}

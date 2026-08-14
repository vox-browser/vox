// Copyright (c) 2022-2024, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Infra.
module infra

import x.json2

pub const ascii_whitespace = '\t\n\x0c\r '
pub const ascii_whitespace_code_points = [u32(`\t`), u32(`\n`), u32(`\x0c`), u32(`\r`), u32(` `)]!

pub type Boolean = bool
pub type Signed16BitInteger = i16
pub type Signed32BitInteger = i32
pub type Signed64BitInteger = i64
pub type Signed8BitInteger = i8
pub type Unsigned16BitInteger = u16
pub type Unsigned32BitInteger = u32
pub type Unsigned64BitInteger = u64
pub type Unsigned8BitInteger = u8

// V 0.5 does not expose a native u128 on every backend. This exact two-limb
// representation still spans Infra's complete 0...2^128-1 domain.
pub struct Unsigned128BitInteger {
pub:
	high u64
	low  u64
}

// V's dynamic JSON value is the direct equivalent of Infra's JSONTopLevel.
pub type JSONBaseValue = json2.Any
pub type JSONObject = map[string]json2.Any
pub type JSONTopLevel = json2.Any
pub type JSONValue = json2.Any

// https://infra.spec.whatwg.org/#ascii-whitespace
pub fn is_ascii_whitespace(code_point u32) bool {
	return code_point == `\t` || code_point == `\n` || code_point == `\x0c` || code_point == `\r`
		|| code_point == ` `
}

// https://infra.spec.whatwg.org/#byte-lowercase
pub fn byte_lowercase(mut bytes []u8) {
	for mut byte in bytes {
		if byte >= `A` && byte <= `Z` {
			byte += 0x20
		}
	}
}

// https://infra.spec.whatwg.org/#byte-uppercase
pub fn byte_uppercase(mut bytes []u8) {
	for mut byte in bytes {
		if byte >= `a` && byte <= `z` {
			byte -= 0x20
		}
	}
}

// https://infra.spec.whatwg.org/#byte-sequence-starts-with
pub fn is_prefix_of(potential_prefix []u8, input []u8) bool {
	if potential_prefix.len > input.len {
		return false
	}
	return input[..potential_prefix.len] == potential_prefix
}

// https://infra.spec.whatwg.org/#byte-less-than
pub fn is_byte_less_than(a []u8, b []u8) bool {
	limit := if a.len < b.len { a.len } else { b.len }
	for i in 0 .. limit {
		if a[i] != b[i] {
			return a[i] < b[i]
		}
	}
	return a.len < b.len
}

// https://infra.spec.whatwg.org/#normalize-newlines
pub fn normalize_newlines(input string) string {
	if !input.contains('\r') {
		return input
	}
	return input.replace('\r\n', '\n').replace('\r', '\n')
}

// https://infra.spec.whatwg.org/#strip-and-collapse-ascii-whitespace
pub fn strip_and_collapse_whitespace(input string) string {
	mut output := []u8{cap: input.len}
	mut pending_space := false
	mut emitted_non_whitespace := false
	for byte in input.bytes() {
		if is_ascii_whitespace(byte) {
			pending_space = emitted_non_whitespace
			continue
		}
		if pending_space {
			output << ` `
			pending_space = false
		}
		output << byte
		emitted_non_whitespace = true
	}
	return output.bytestr()
}

// Compatibility name retained for the original module's public API.
pub fn strip_and_collapse_ascii_whitespace(input string) string {
	return strip_and_collapse_whitespace(input)
}

fn utf16_code_units(input string) []u16 {
	mut result := []u16{cap: input.len}
	for code_point_rune in input.runes() {
		code_point := u32(code_point_rune)
		if code_point <= 0xffff {
			result << u16(code_point)
			continue
		}
		value := code_point - 0x10000
		result << u16(0xd800 + (value >> 10))
		result << u16(0xdc00 + (value & 0x3ff))
	}
	return result
}

// https://infra.spec.whatwg.org/#code-unit-prefix
pub fn is_code_unit_prefix(potential_prefix string, input string) bool {
	prefix_units := utf16_code_units(potential_prefix)
	input_units := utf16_code_units(input)
	if prefix_units.len > input_units.len {
		return false
	}
	return input_units[..prefix_units.len] == prefix_units
}

// https://infra.spec.whatwg.org/#scalar-value-string
pub fn convert_to_scalar_value_string(input string) string {
	mut output := []rune{cap: input.len}
	for code_point in input.runes() {
		value := u32(code_point)
		output << if value >= 0xd800 && value <= 0xdfff { rune(0xfffd) } else { code_point }
	}
	return output.string()
}

// https://infra.spec.whatwg.org/#code-unit-less-than
pub fn code_unit_less_than(a string, b string) bool {
	a_units := utf16_code_units(a)
	b_units := utf16_code_units(b)
	limit := if a_units.len < b_units.len { a_units.len } else { b_units.len }
	for i in 0 .. limit {
		if a_units[i] != b_units[i] {
			return a_units[i] < b_units[i]
		}
	}
	return a_units.len < b_units.len
}

// https://infra.spec.whatwg.org/#parse-a-json-string-to-a-javascript-value
pub fn parse_json_string_to_javascript_value(input string) !json2.Any {
	return json2.decode[json2.Any](input)
}

// https://infra.spec.whatwg.org/#parse-json-bytes-to-a-javascript-value
pub fn parse_json_bytes_to_javascript_value(bytes []u8) !json2.Any {
	return parse_json_string_to_javascript_value(bytes.bytestr())
}

// https://infra.spec.whatwg.org/#serialize-a-javascript-value-to-a-json-string
pub fn serialize_javascript_value_to_json_string(value json2.Any) !string {
	return value.json_str()
}

// https://infra.spec.whatwg.org/#serialize-a-javascript-value-to-json-bytes
pub fn serialize_javascript_value_to_json_bytes(value json2.Any) ![]u8 {
	return serialize_javascript_value_to_json_string(value)!.bytes()
}

// V's json2.Any is already a JSON-compatible representation, so the Infra-value
// conversion is identity-preserving.
pub fn serialize_an_infra_value_to_a_json_string(value JSONTopLevel) string {
	return value.json_str()
}

pub fn serialize_an_infra_value_to_json_bytes(value JSONTopLevel) []u8 {
	return serialize_an_infra_value_to_a_json_string(value).bytes()
}

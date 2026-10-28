// Copyright (c) 2018-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of parse_legacy_color_value (LibWeb/HTML/Parser/HTMLParser.cpp) — the HTML "rules for
// parsing a legacy colour value": handle the empty string, "transparent", named colors, the #RGB short
// form, and otherwise the historical hex-normalization fallback. Composes the color module's
// from_named_css_color_string.
// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#rules-for-parsing-a-legacy-colour-value
module color

fn is_hex_digit(b u8) bool {
	return (b >= `0` && b <= `9`) || (b >= `a` && b <= `f`) || (b >= `A` && b <= `F`)
}

fn hex_nibble(b u8) u8 {
	if b >= `0` && b <= `9` {
		return b - `0`
	}
	if b >= `a` && b <= `f` {
		return b - `a` + 10
	}
	return b - `A` + 10
}

// A component's u8 value: a single nibble when length is 1, otherwise the first two hex digits.
fn component_value(component []u8, length int) u8 {
	if length == 1 {
		return hex_nibble(component[0])
	}
	return (hex_nibble(component[0]) << 4) | hex_nibble(component[1])
}

pub fn parse_legacy_color_value(input_value string) ?Color {
	// 1. The empty string is a failure.
	if input_value == '' {
		return none
	}
	// 2. Strip leading and trailing ASCII whitespace.
	input := input_value.trim('\t\n\x0c\r ')
	// 3. "transparent" is a failure.
	if ascii_lowercase(input) == 'transparent' {
		return none
	}
	// 4. A named color.
	if named := from_named_css_color_string(input) {
		return named
	}
	// 5. The #RGB short form: "#" then three hex digits, each doubled.
	bytes := input.bytes()
	if bytes.len == 4 && bytes[0] == `#` && is_hex_digit(bytes[1]) && is_hex_digit(bytes[2])
		&& is_hex_digit(bytes[3]) {
		return Color{
			red:   hex_nibble(bytes[1]) * 17
			green: hex_nibble(bytes[2]) * 17
			blue:  hex_nibble(bytes[3]) * 17
			alpha: 255
		}
	}
	// 6. Replace non-BMP code points (> U+FFFF) with "00".
	mut code_points := []rune{}
	for code_point in input.runes() {
		if u32(code_point) > 0xFFFF {
			code_points << `0`
			code_points << `0`
		} else {
			code_points << code_point
		}
	}
	// 7. Truncate to the first 128 code points.
	if code_points.len > 128 {
		code_points = code_points[..128]
	}
	// 8. Remove a leading "#".
	if code_points.len > 0 && code_points[0] == `#` {
		code_points = code_points[1..]
	}
	// 9. Replace any code point that is not an ASCII hex digit with "0". (Now all ASCII.)
	mut chars := []u8{}
	for code_point in code_points {
		if code_point >= 0 && code_point <= 0x7F && is_hex_digit(u8(code_point)) {
			chars << u8(code_point)
		} else {
			chars << `0`
		}
	}
	// 10. Pad with "0" until the length is a non-zero multiple of three.
	for chars.len == 0 || chars.len % 3 != 0 {
		chars << `0`
	}
	// 11. Split into three equal components.
	mut length := chars.len / 3
	mut first := chars[0..length].clone()
	mut second := chars[length..length * 2].clone()
	mut third := chars[length * 2..length * 3].clone()
	// 12. Keep only the last eight characters of each component when longer.
	if length > 8 {
		first = first[length - 8..]
		second = second[length - 8..]
		third = third[length - 8..]
		length = 8
	}
	// 13. Drop leading zeros shared by all three components, down to length two.
	for length > 2 && first[0] == `0` && second[0] == `0` && third[0] == `0` {
		length--
		first = first[1..]
		second = second[1..]
		third = third[1..]
	}
	// 14. Truncate each component to its first two characters when still longer than two.
	if length > 2 {
		first = first[0..2]
		second = second[0..2]
		third = third[0..2]
	}
	// 15-19. Interpret each component as a hex number.
	return Color{
		red:   component_value(first, length)
		green: component_value(second, length)
		blue:  component_value(third, length)
		alpha: 255
	}
}

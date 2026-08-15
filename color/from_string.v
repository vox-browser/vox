// Copyright (c) 2018-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Color::from_string and its hex/rgb()/rgba() parsers from LibGfx/Color.cpp — parse a
// color string that is a hex color (#RGB / #RGBA / #RRGGBB / #RRGGBBAA), an rgb()/rgba() function, the
// keyword "transparent", or a named color. Composes the color module's from_named_css_color_string and
// the hex helpers from legacy_color.v.
// https://drafts.csswg.org/css-color/
module color

import strconv

fn hex_nibble_opt(b u8) ?u8 {
	if is_hex_digit(b) {
		return hex_nibble(b)
	}
	return none
}

fn hex_pair(c1 u8, c2 u8) ?u8 {
	high := hex_nibble_opt(c1) or { return none }
	low := hex_nibble_opt(c2) or { return none }
	return (high << 4) | low
}

// A hex color (the string includes the leading "#"): #RGB, #RGBA, #RRGGBB, or #RRGGBBAA.
fn hex_string_to_color(input string) ?Color {
	if input.len == 4 {
		r := hex_nibble_opt(input[1]) or { return none }
		g := hex_nibble_opt(input[2]) or { return none }
		b := hex_nibble_opt(input[3]) or { return none }
		return Color{
			red:   r * 17
			green: g * 17
			blue:  b * 17
			alpha: 255
		}
	}
	if input.len == 5 {
		r := hex_nibble_opt(input[1]) or { return none }
		g := hex_nibble_opt(input[2]) or { return none }
		b := hex_nibble_opt(input[3]) or { return none }
		a := hex_nibble_opt(input[4]) or { return none }
		return Color{
			red:   r * 17
			green: g * 17
			blue:  b * 17
			alpha: a * 17
		}
	}
	if input.len != 7 && input.len != 9 {
		return none
	}
	r := hex_pair(input[1], input[2]) or { return none }
	g := hex_pair(input[3], input[4]) or { return none }
	b := hex_pair(input[5], input[6]) or { return none }
	a := if input.len == 9 {
		hex_pair(input[7], input[8]) or { return none }
	} else {
		u8(255)
	}
	return Color{
		red:   r
		green: g
		blue:  b
		alpha: a
	}
}

// Clamp a double to the 0..255 u8 range (truncating), matching AK::clamp_to<u8, double>.
fn clamp_to_u8(value f64) u8 {
	if value < 0.0 {
		return 0
	}
	if value > 255.0 {
		return 255
	}
	return u8(value)
}

fn parse_component(part string) ?u8 {
	value := strconv.atof64(part.trim(' \t\n\r\x0c')) or { return none }
	return clamp_to_u8(value)
}

fn parse_rgb_color(input string) ?Color {
	// input is "rgb(...)"; take the content between the parentheses.
	parts := input[4..input.len - 1].split(',')
	if parts.len != 3 {
		return none
	}
	return Color{
		red:   parse_component(parts[0]) or { return none }
		green: parse_component(parts[1]) or { return none }
		blue:  parse_component(parts[2]) or { return none }
		alpha: 255
	}
}

fn parse_rgba_color(input string) ?Color {
	// input is "rgba(...)".
	parts := input[5..input.len - 1].split(',')
	if parts.len != 4 {
		return none
	}
	r := parse_component(parts[0]) or { return none }
	g := parse_component(parts[1]) or { return none }
	b := parse_component(parts[2]) or { return none }
	// The alpha (0 if unparseable) scaled to 0..255; out of range is a failure.
	alpha := strconv.atof64(parts[3].trim(' \t\n\r\x0c')) or { 0.0 }
	scaled := int(alpha * 255)
	if scaled < 0 || scaled > 255 {
		return none
	}
	return Color{
		red:   r
		green: g
		blue:  b
		alpha: u8(scaled)
	}
}

// https://drafts.csswg.org/css-color/ — Color::from_string: a hex color, an rgb()/rgba() function, the
// "transparent" keyword, or a named color; none otherwise.
pub fn from_string(input string) ?Color {
	if input == '' {
		return none
	}
	if input[0] == `#` {
		return hex_string_to_color(input)
	}
	lowercased := ascii_lowercase(input)
	if lowercased.starts_with('rgb(') && input.ends_with(')') {
		return parse_rgb_color(input)
	}
	if lowercased.starts_with('rgba(') && input.ends_with(')') {
		return parse_rgba_color(input)
	}
	if lowercased == 'transparent' {
		return Color{
			red:   0
			green: 0
			blue:  0
			alpha: 0
		}
	}
	return from_named_css_color_string(input)
}

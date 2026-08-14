// Copyright (c) 2023, Jonatan Klemets <jonatan.r.klemets@gmail.com>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/Numbers.cpp.
module html

import math
import strconv

fn is_number_ascii_whitespace(character u8) bool {
	return character == `\t` || character == `\n` || character == `\x0c` || character == `\r`
		|| character == ` `
}

fn is_number_ascii_digit(character u8) bool {
	return character >= `0` && character <= `9`
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#rules-for-parsing-integers
pub fn parse_integer_digits(input string) ?string {
	mut position := 0
	for position < input.len && is_number_ascii_whitespace(input[position]) {
		position++
	}
	if position == input.len {
		return none
	}

	start_index := position
	if input[position] == `-` || input[position] == `+` {
		position++
	}
	if position == input.len || !is_number_ascii_digit(input[position]) {
		return none
	}
	for position < input.len && is_number_ascii_digit(input[position]) {
		position++
	}
	return input[start_index..position]
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#rules-for-parsing-integers
pub fn parse_integer(input string) ?i32 {
	digits := parse_integer_digits(input) or { return none }
	value := strconv.parse_int(digits, 10, 32) or { return none }
	return i32(value)
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#rules-for-parsing-non-negative-integers
pub fn parse_non_negative_integer_digits(input string) ?string {
	digits := parse_integer_digits(input) or { return none }
	if digits.len > 1 && digits[0] == `-` && digits[1] != `0` {
		return none
	}
	return digits
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#rules-for-parsing-non-negative-integers
pub fn parse_non_negative_integer(input string) ?u32 {
	digits := parse_non_negative_integer_digits(input) or { return none }
	value := strconv.parse_int(digits, 10, 64) or { return none }
	if value > i64(0xffff_ffff) {
		return none
	}
	return u32(value)
}

fn finish_parsing_floating_point_number(value f64) ?f64 {
	// Conversion steps 15 through 18. V f64 arithmetic already uses IEEE 754
	// round-to-nearest semantics, as does the C++ implementation.
	if math.is_inf(value, 0) || math.is_nan(value) {
		return none
	}
	if value == 0.0 && math.signbit(value) {
		return 0.0
	}
	if math.abs(value) >= math.pow(2.0, 1024.0) {
		return none
	}
	return value
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#rules-for-parsing-floating-point-number-values
pub fn parse_floating_point_number(input string) ?f64 {
	mut position := 0
	mut value := 1.0
	mut divisor := 1.0
	mut exponent := i64(1)

	for position < input.len && is_number_ascii_whitespace(input[position]) {
		position++
	}
	if position == input.len {
		return none
	}

	if input[position] == `-` {
		value = -1.0
		divisor = -1.0
		position++
		if position == input.len {
			return none
		}
	} else if input[position] == `+` {
		position++
		if position == input.len {
			return none
		}
	}

	mut at_fraction := false
	if input[position] == `.` && position + 1 < input.len
		&& is_number_ascii_digit(input[position + 1]) {
		value = 0.0
		at_fraction = true
	} else {
		if !is_number_ascii_digit(input[position]) {
			return none
		}
		start_index := position
		for position < input.len && is_number_ascii_digit(input[position]) {
			position++
		}
		integer_part := strconv.atof64(input[start_index..position]) or { return none }
		value *= integer_part
		if position == input.len {
			return finish_parsing_floating_point_number(value)
		}
	}

	if at_fraction || (position < input.len && input[position] == `.`) {
		position++
		if position == input.len || (!is_number_ascii_digit(input[position])
			&& input[position] != `e` && input[position] != `E`) {
			return finish_parsing_floating_point_number(value)
		}
		if input[position] != `e` && input[position] != `E` {
			for {
				divisor *= 10.0
				value += f64(input[position] - `0`) / divisor
				position++
				if position == input.len {
					return finish_parsing_floating_point_number(value)
				}
				if !is_number_ascii_digit(input[position]) {
					break
				}
			}
		}
	}

	if position < input.len && (input[position] == `e` || input[position] == `E`) {
		position++
		if position == input.len {
			return finish_parsing_floating_point_number(value)
		}
		if input[position] == `-` {
			exponent = -1
			position++
			if position == input.len {
				return finish_parsing_floating_point_number(value)
			}
		} else if input[position] == `+` {
			position++
			if position == input.len {
				return finish_parsing_floating_point_number(value)
			}
		}
		if !is_number_ascii_digit(input[position]) {
			return finish_parsing_floating_point_number(value)
		}
		start_index := position
		for position < input.len && is_number_ascii_digit(input[position]) {
			position++
		}
		exponent_value := strconv.parse_int(input[start_index..position], 10, 32) or { return none }
		exponent *= exponent_value
		value *= math.pow(10.0, f64(exponent))
	}

	return finish_parsing_floating_point_number(value)
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#valid-floating-point-number
pub fn is_valid_floating_point_number(input string) bool {
	mut position := 0
	if position < input.len && input[position] == `-` {
		position++
	}

	leading_digits_start := position
	for position < input.len && is_number_ascii_digit(input[position]) {
		position++
	}
	has_leading_digits := position > leading_digits_start

	if position < input.len && input[position] == `.` {
		position++
		fraction_digits_start := position
		for position < input.len && is_number_ascii_digit(input[position]) {
			position++
		}
		if position == fraction_digits_start {
			return false
		}
	} else if !has_leading_digits {
		return false
	}

	if position < input.len && (input[position] == `e` || input[position] == `E`) {
		position++
		if position < input.len && (input[position] == `-` || input[position] == `+`) {
			position++
		}
		exponent_digits_start := position
		for position < input.len && is_number_ascii_digit(input[position]) {
			position++
		}
		if position == exponent_digits_start {
			return false
		}
	}
	return position == input.len
}

pub fn convert_non_negative_integer_to_string(value i32) !string {
	if value < 0 {
		return error('The attribute is limited to only non-negative numbers')
	}
	return value.str()
}

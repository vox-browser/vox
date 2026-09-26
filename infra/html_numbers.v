module infra

import strconv

// Translation of the integer and floating-point microsyntaxes in Libraries/LibWeb/HTML/Numbers.cpp. HTML exposes
// them unchanged; Editing's fontSize command parses its value with the same rules.

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

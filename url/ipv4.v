// Copyright (c) 2021-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the self-contained IPv4 parser of LibURL/Parser.cpp — the WHATWG URL "IPv4 number
// parser" and "IPv4 parser". These are pure string->number algorithms; the surrounding host parser and
// URL record are not translated. Validation-error reporting (a debug side effect) is dropped, but the
// per-number validation_error flag is kept on ParsedIPv4Number. The address is returned as a u32.
// https://url.spec.whatwg.org/#concept-ipv4-parser
module url

import strconv

pub struct ParsedIPv4Number {
pub:
	number           u32
	validation_error bool
}

// https://url.spec.whatwg.org/#ipv4-number-parser
pub fn parse_ipv4_number(number_input string) ?ParsedIPv4Number {
	mut input := number_input
	// 1. The empty string is a failure.
	if input.len == 0 {
		return none
	}
	mut validation_error := false
	mut radix := 10
	// 4. A leading "0x"/"0X" selects hexadecimal.
	if input.len >= 2 && (input.starts_with('0X') || input.starts_with('0x')) {
		validation_error = true
		input = input[2..]
		radix = 16
	} else if input.len >= 2 && input[0] == `0` {
		// 5. Otherwise a leading "0" selects octal.
		validation_error = true
		input = input[1..]
		radix = 8
	}
	// 6. If input is now empty, the number is 0 (with a validation error).
	if input.len == 0 {
		return ParsedIPv4Number{
			number:           0
			validation_error: true
		}
	}
	// 7-8. Parse the remaining digits in the chosen radix; a non-digit or an overflow of u32 is a failure.
	output := strconv.parse_uint(input, radix, 32) or { return none }
	// 9. Return the number and whether a validation error occurred.
	return ParsedIPv4Number{
		number:           u32(output)
		validation_error: validation_error
	}
}

// 256 to the power of exp (as u64, so 256^4 = 2^32 does not overflow).
fn pow_256(exp int) u64 {
	mut result := u64(1)
	for _ in 0 .. exp {
		result *= 256
	}
	return result
}

// https://url.spec.whatwg.org/#concept-ipv4-parser — parse an IPv4 address into a 32-bit number, or none
// on failure. Supports the shorthand forms (fewer than four parts, and hex/octal parts).
pub fn parse_ipv4_address(input string) ?u32 {
	// 1. Strictly split on '.', keeping empty parts.
	mut parts := input.split('.')
	// 2. Drop a trailing empty part (when there is more than one part).
	if parts[parts.len - 1] == '' && parts.len > 1 {
		parts = parts[..parts.len - 1]
	}
	// 3. More than four parts is a failure.
	if parts.len > 4 {
		return none
	}
	// 4-5. Parse each part as an IPv4 number.
	mut numbers := []u32{}
	for part in parts {
		result := parse_ipv4_number(part) or { return none }
		numbers << result.number
	}
	// 6-7. A number other than the last one that exceeds 255 is a failure.
	for i, number in numbers {
		if number > 255 && i != numbers.len - 1 {
			return none
		}
	}
	// 8. The last number must be below 256^(5 - size).
	if u64(numbers[numbers.len - 1]) >= pow_256(5 - numbers.len) {
		return none
	}
	// 9-13. Combine the parts into a single 32-bit address.
	mut ipv4 := numbers[numbers.len - 1]
	numbers = numbers[..numbers.len - 1]
	for counter, n in numbers {
		ipv4 += n * u32(pow_256(3 - counter))
	}
	return ipv4
}

// https://url.spec.whatwg.org/#concept-ipv4-serializer — the dotted-quad form of a 32-bit address.
pub fn serialize_ipv4_address(address u32) string {
	mut n := address
	mut output := []u8{len: 4}
	// The four bytes, most significant last: output[3-i] = n % 256, then n /= 256.
	for i in 0 .. 4 {
		output[3 - i] = u8(n % 256)
		n /= 256
	}
	return '${output[0]}.${output[1]}.${output[2]}.${output[3]}'
}

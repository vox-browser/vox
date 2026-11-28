// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math

// ECMA-402 ToIntlMathematicalValue: Number inputs use their shortest decimal
// representation. BigInt and decimal String inputs retain all significant
// digits. This differs deliberately from Number.prototype.toFixed's binary MV.
struct IntlDecimal {
	negative bool
	special string // empty, nan, infinity
	digits string = '0'
	exponent int
}

fn intl_decimal_parse(text string, negative_zero bool) IntlDecimal {
	mut source := text
	negative := source.starts_with('-') || negative_zero
	if source.starts_with('-') || source.starts_with('+') { source = source[1..] }
	mut exponent := 0
	pieces := source.to_lower().split('e')
	if pieces.len == 2 { exponent = pieces[1].int() }
	mantissa := pieces[0]
	if dot := mantissa.index('.') { exponent -= mantissa.len - dot - 1 }
	mut digits := mantissa.replace('.', '').trim_left('0')
	if digits == '' { return IntlDecimal{negative: negative} }
	for digits.len > 1 && digits.ends_with('0') { digits = digits[..digits.len - 1]; exponent++ }
	return IntlDecimal{negative: negative, digits: digits, exponent: exponent}
}

fn intl_mathematical_value(mut vm VM, value Value) !IntlDecimal {
	primitive := value.to_primitive_with_hint(mut vm, .number)!
	if primitive.is_bigint() { return intl_decimal_parse(primitive.as_bigint().big_integer.str(), false) }
	number := primitive.to_number(mut vm)!.number
	negative := math.f64_bits(number) >> 63 != 0
	if math.is_nan(number) { return IntlDecimal{special: 'nan'} }
	if math.is_inf(number, 0) { return IntlDecimal{negative: negative, special: 'infinity'} }
	if number == 0 { return IntlDecimal{negative: negative} }
	if !primitive.is_string() { return intl_decimal_parse(format_f64_value(number), negative) }
	units := primitive.as_string().utf16.data
	mut start := 0; mut end := units.len
	for start < end && is_number_whitespace(units[start]) { start++ }
	for end > start && is_number_whitespace(units[end - 1]) { end-- }
	source := encode_utf16(units[start..end], false)
	vm.consume_execution_budget()!
	if source.len > 2 && source[0] == `0` && source[1] in [`x`, `X`, `o`, `O`, `b`, `B`] {
		integer := string_to_bigint(utf16_string(source)) or { return IntlDecimal{special: 'nan'} }
		return intl_decimal_parse(integer.big_integer.str(), false)
	}
	return intl_decimal_parse(source, negative)
}

fn (value IntlDecimal) magnitude() int { return if value.digits == '0' { 0 } else { value.digits.len + value.exponent - 1 } }

// Quotient/remainder by a sanctioned small rounding increment. Operate on
// decimal digits, avoiding f64 and powers proportional to an arbitrary BigInt.
fn intl_decimal_divide(digits string, divisor int) (string, int) {
	mut remainder := 0
	mut output := []u8{cap: digits.len}
	for digit in digits.bytes() {
		remainder = remainder * 10 + int(digit - `0`)
		quotient := remainder / divisor
		if quotient != 0 || output.len > 0 { output << u8(quotient + `0`) }
		remainder %= divisor
	}
	return if output.len == 0 { '0' } else { output.bytestr() }, remainder
}

fn intl_decimal_multiply(digits string, multiplier int, add int) string {
	mut output := []u8{cap: digits.len + 5}
	mut carry := add
	for index := digits.len - 1; index >= 0; index-- {
		carry += int(digits[index] - `0`) * multiplier
		output << u8(carry % 10 + `0`); carry /= 10
	}
	for carry > 0 { output << u8(carry % 10 + `0`); carry /= 10 }
	output.reverse_in_place()
	return output.bytestr()
}

// Round |value| to increment * 10^exponent, mapping all nine signed rounding
// modes to unsigned decisions. Fractional tails remain exact even beyond 2^53.
fn intl_decimal_round(mut vm VM, value IntlDecimal, exponent int, increment int, mode string) !IntlDecimal {
	vm.consume_execution_budget()!
	shift := value.exponent - exponent
	mut integer := value.digits
	mut fraction := ''
	if shift >= 0 {
		checked_js_string_length_sum(mut vm, uint(integer.len), uint(shift), .string_size_must_not_overflow)!
		integer += '0'.repeat(shift)
	} else {
		point := integer.len + shift
		if point <= 0 { fraction = '0'.repeat(-point) + integer; integer = '0' }
		else { fraction = integer[point..]; integer = integer[..point] }
	}
	quotient, remainder := intl_decimal_divide(integer, increment)
	inexact := remainder != 0 || fraction.trim('0') != ''
	gap := increment - 2 * remainder
	// Compare the fractional remainder to half of one unit only when needed.
	mut comparison := if gap < 0 { 1 } else if gap > 1 { -1 } else if gap == 0 { if fraction.trim('0') == '' { 0 } else { 1 } } else { -1 }
	if gap == 1 && fraction.len > 0 {
		comparison = if fraction[0] < `5` { -1 } else if fraction[0] > `5` || fraction[1..].trim('0') != '' { 1 } else { 0 }
	}
	up := inexact && match mode {
		'ceil' { !value.negative }
		'floor' { value.negative }
		'expand' { true }
		'trunc' { false }
		else { comparison > 0 || (comparison == 0 && match mode {
			'halfCeil' { !value.negative }
			'halfFloor' { value.negative }
			'halfTrunc' { false }
			'halfEven' { (quotient[quotient.len - 1] - `0`) % 2 != 0 }
			else { true }
		}) }
	}
	digits := intl_decimal_multiply(quotient, increment, if up { increment } else { 0 })
	return IntlDecimal{negative: value.negative, digits: digits, exponent: exponent}
}

fn intl_decimal_fixed(value IntlDecimal, minimum_fraction int) string {
	point := value.digits.len + value.exponent
	mut integer := if point <= 0 { '0' } else if point >= value.digits.len { value.digits + '0'.repeat(point - value.digits.len) } else { value.digits[..point] }
	mut fraction := if point <= 0 { '0'.repeat(-point) + value.digits } else if point < value.digits.len { value.digits[point..] } else { '' }
	integer = integer.trim_left('0'); if integer == '' { integer = '0' }
	for fraction.len > minimum_fraction && fraction.ends_with('0') { fraction = fraction[..fraction.len - 1] }
	if fraction.len < minimum_fraction { fraction += '0'.repeat(minimum_fraction - fraction.len) }
	return integer + if fraction != '' { '.' + fraction } else { '' }
}

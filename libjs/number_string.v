module libjs

import math
import math.big

// Runtime/NumberPrototype.cpp::this_number_value. Inherited slots and
// conversion hooks do not qualify a receiver for Number prototype methods.
fn this_number_value(mut vm VM, value Value) !Value {
	if value.is_number() { return value }
	if value.is_object() {
		if wrapper := value.as_object().number_object { return Value.from_f64(wrapper.value) }
	}
	return vm.throw_error_type(.type_error, .not_an_object_of_type, 'Number')
}

const number_radix_digits = '0123456789abcdefghijklmnopqrstuvwxyz'

// Runtime/NumberPrototype.cpp::to_string. Preserve floating-point radix division
// for the integer part. Exact remainder and rounding-boundary arithmetic chooses
// fractional digits that round back to the original double.
pub fn number_prototype_to_string(mut vm VM) !Value {
	number_value := this_number_value(mut vm, vm.this_value())!
	radix_mv := if vm.argument(0).is_undefined() {
		f64(10)
	} else {
		vm.argument(0).to_integer_or_infinity(mut vm)!
	}
	if radix_mv < 2 || radix_mv > 36 { return vm.throw_error_type(.range_error, .invalid_radix) }
	if radix_mv == 10 { return Value.from_string(number_value.to_primitive_string(mut vm)!) }
	if !number_value.is_finite_number() || number_value.number == 0 {
		return Value.from_string(number_value.to_primitive_string(mut vm)!)
	}
	mut number := number_value.number
	negative := number < 0
	if negative { number *= -1 }
	mut int_part := math.floor(number)
	radix := int(radix_mv)
	mut fractional_digits := []u8{}
	if number != int_part {
		bits := math.f64_bits(number)
		exponent_field := int((bits >> 52) & 0x7ff)
		mantissa := bits & ((u64(1) << 52) - 1)
		significand := if exponent_field == 0 { mantissa } else { mantissa | (u64(1) << 52) }
		exponent := if exponent_field == 0 { -1074 } else { exponent_field - 1023 - 52 }
		// At normal powers of two above the smallest normal value, the previous
		// double is half as far away as the next. Scale so both boundaries are integers.
		asymmetric_boundaries := significand == (u64(1) << 52) && exponent > -1074
		scale := if asymmetric_boundaries { u32(2) } else { u32(1) }
		one := big.integer_from_int(1)
		denominator := one.left_shift(u32(-exponent) + scale)
		mut remainder := big.integer_from_u64(significand).left_shift(scale) % denominator
		mut lower_boundary := one
		mut upper_boundary := big.integer_from_int(if asymmetric_boundaries { 2 } else { 1 })
		radix_integer := big.integer_from_int(radix)
		inclusive_boundaries := significand & 1 == 0
		mut significand_is_odd := u64(int_part) & 1 != 0
		for {
			scaled_remainder := remainder * radix_integer
			quotient, next_remainder := scaled_remainder.div_mod(denominator)
			digit := u8(big_integer_to_u64(quotient))
			fractional_digits << digit
			// Odd radices carry parity from every digit, including the integer part.
			significand_is_odd = ((radix & 1 != 0) && significand_is_odd) != (digit & 1 != 0)
			remainder = next_remainder
			lower_boundary = lower_boundary * radix_integer
			upper_boundary = upper_boundary * radix_integer
			can_round_down := remainder < lower_boundary
				|| (inclusive_boundaries && remainder == lower_boundary)
			upper_candidate := remainder + upper_boundary
			can_round_up := upper_candidate > denominator
				|| (inclusive_boundaries && upper_candidate == denominator)
			if !can_round_down && !can_round_up { continue }
			twice_remainder := remainder.left_shift(1)
			round_up := can_round_up && (!can_round_down || twice_remainder > denominator
				|| (twice_remainder == denominator && significand_is_odd))
			if round_up {
				for fractional_digits.len > 0 && fractional_digits.last() == u8(radix - 1) {
					fractional_digits.delete_last()
				}
				if fractional_digits.len == 0 {
					int_part++
				} else {
					fractional_digits[fractional_digits.len - 1]++
				}
			}
			for fractional_digits.len > 0 && fractional_digits.last() == 0 {
				fractional_digits.delete_last()
			}
			break
		}
	}
	mut backwards := []u8{}
	if int_part == 0 {
		backwards << u8(`0`)
	} else {
		for int_part > 0 {
			backwards << number_radix_digits[int(math.floor(math.fmod(int_part, radix)))]
			int_part /= radix
			int_part = math.floor(int_part)
		}
	}
	mut builder := []u16{}
	if negative { builder << u16(`-`) }
	for index := backwards.len - 1; index >= 0; index-- {
		builder << u16(backwards[index])
	}
	if fractional_digits.len > 0 {
		builder << u16(`.`)
		for digit in fractional_digits {
			builder << u16(number_radix_digits[int(digit)])
		}
	}
	return Value.from_string(vm.create_string(Utf16String{ data: builder }))
}

pub fn number_prototype_value_of(mut vm VM) !Value {
	return this_number_value(mut vm, vm.this_value())
}

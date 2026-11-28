module libjs

import math
import math.bits
import math.big

struct FixedBinaryDecomposition {
	significand u64
	exponent int
}

fn decompose_fixed_double(number f64) FixedBinaryDecomposition {
	encoded := math.f64_bits(number)
	exponent := int((encoded >> 52) & 0x7ff)
	mantissa := encoded & ((u64(1) << 52) - 1)
	return FixedBinaryDecomposition{
		significand: if exponent == 0 { mantissa } else { mantissa | (u64(1) << 52) }
		exponent: if exponent == 0 { 1 - 1023 - 52 } else { exponent - 1023 - 52 }
	}
}

// NumberPrototype.cpp::compute_to_fixed_scaled_integer. Decompose IEEE-754
// exactly, scale its significand by 5^f and 2^(exponent+f), divide, and round
// half-up. This never formats an already-rounded decimal Number string.
fn compute_to_fixed_scaled_integer(number f64, fraction_digits u32) big.Integer {
	decomposition := decompose_fixed_double(number)
	binary_significand := big.integer_from_u64(decomposition.significand)
	numerator := binary_significand * big.integer_from_int(5).pow(fraction_digits)
	binary_scale := decomposition.exponent + int(fraction_digits)
	if binary_scale >= 0 { return numerator.left_shift(u32(binary_scale)) }
	denominator := big.integer_from_int(1).left_shift(u32(-binary_scale))
	mut quotient, remainder := numerator.div_mod(denominator)
	if remainder.left_shift(1) >= denominator { quotient = quotient + big.integer_from_int(1) }
	return quotient
}

const fixed_powers_of_five = [u64(1), 5, 25, 125, 625, 3125, 15625, 78125, 390625, 1953125, 9765625, 48828125, 244140625, 1220703125, 6103515625, 30517578125, 152587890625, 762939453125, 3814697265625, 19073486328125, 95367431640625, 476837158203125, 2384185791015625, 11920928955078125, 59604644775390625, 298023223876953125, 1490116119384765625, 7450580596923828125]

// For at most 27 fractional digits, the exact numerator fits in 116 bits.
// Use a two-word product and round half-up, falling back if the result needs
// more than a u64 or scaling requires a left shift.
fn try_compute_to_fixed_scaled_integer_in_u64(number f64, fraction_digits u32) ?u64 {
	if fraction_digits >= u32(fixed_powers_of_five.len) { return none }
	decomposition := decompose_fixed_double(number)
	binary_scale := decomposition.exponent + int(fraction_digits)
	if binary_scale >= 0 { return none }
	shift := u32(-binary_scale)
	if shift >= 117 { return u64(0) }
	high, low := bits.mul_64(decomposition.significand, fixed_powers_of_five[fraction_digits])
	mut quotient := u64(0)
	mut round_up := u64(0)
	if shift >= 64 {
		quotient = high >> (shift - 64)
		round_up = if shift == 64 { low >> 63 } else { (high >> (shift - 65)) & 1 }
	} else {
		if high >> shift != 0 { return none }
		quotient = (low >> shift) | (high << (64 - shift))
		round_up = (low >> (shift - 1)) & 1
	}
	rounded, carry := bits.add_64(quotient, round_up, 0)
	if carry != 0 { return none }
	return rounded
}

// Runtime/NumberPrototype.cpp::to_fixed. Its range check precedes the receiver's
// nonfinite fast path, unlike toExponential/toPrecision.
pub fn number_prototype_to_fixed(mut vm VM) !Value {
	number_value := this_number_value(mut vm, vm.this_value())!
	fraction_digits := vm.argument(0).to_integer_or_infinity(mut vm)!
	if !Value.from_f64(fraction_digits).is_finite_number() || fraction_digits < 0
		|| fraction_digits > 100 {
		return vm.throw_error_type(.range_error, .invalid_fraction_digits)
	}
	if !number_value.is_finite_number() {
		return Value.from_string(number_value.to_primitive_string(mut vm)!)
	}
	mut number := number_value.number
	sign := if number < 0 { '-' } else { '' }
	if number < 0 { number = -number }
	if number >= 1e21 { return Value.from_string(number_value.to_primitive_string(mut vm)!) }
	count := int(fraction_digits)
	digits := if small := try_compute_to_fixed_scaled_integer_in_u64(number, u32(count)) {
		small.str()
	} else {
		compute_to_fixed_scaled_integer(number, u32(count)).str()
	}
	padded_length := if count != 0 { math.max(digits.len, count + 1) } else { digits.len }
	zero_count := padded_length - digits.len
	whole_length := padded_length - count
	mut output := []u16{len: sign.len + padded_length + if count != 0 { 1 } else { 0 }}
	mut position := 0
	if sign.len != 0 {
		output[position] = u16(`-`)
		position++
	}
	for index in 0 .. padded_length {
		if count != 0 && index == whole_length {
			output[position] = u16(`.`)
			position++
		}
		output[position] = if index < zero_count { u16(`0`) } else { u16(digits[index - zero_count]) }
		position++
	}
	return Value.from_string(vm.create_string(Utf16String{data: output}))
}

module libjs

import math
import math.big

// NumberPrototype.cpp::compute_to_fixed_scaled_integer. Decompose IEEE-754
// exactly, scale its significand by 5^f and 2^(exponent+f), divide, and round
// half-up. This never formats an already-rounded decimal Number string.
fn compute_to_fixed_scaled_integer(number f64, fraction_digits u32) big.Integer {
	bits := math.f64_bits(number)
	exponent := int((bits >> 52) & 0x7ff)
	mantissa := bits & ((u64(1) << 52) - 1)
	binary_significand := big.integer_from_u64(if exponent == 0 {
		mantissa
	} else {
		mantissa | (u64(1) << 52)
	})
	binary_exponent := if exponent == 0 { 1 - 1023 - 52 } else { exponent - 1023 - 52 }
	numerator := binary_significand * big.integer_from_int(5).pow(fraction_digits)
	binary_scale := binary_exponent + int(fraction_digits)
	if binary_scale >= 0 { return numerator.left_shift(u32(binary_scale)) }
	denominator := big.integer_from_int(1).left_shift(u32(-binary_scale))
	mut quotient, remainder := numerator.div_mod(denominator)
	if remainder.left_shift(1) >= denominator { quotient = quotient + big.integer_from_int(1) }
	return quotient
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
	mut text := compute_to_fixed_scaled_integer(number, u32(count)).str()
	if count != 0 {
		mut k := text.len
		if k <= count {
			text = '0'.repeat(count + 1 - k) + text
			k = count + 1
		}
		text = text[..k - count] + '.' + text[k - count..]
	}
	return Value.from_string(vm.create_string_from_str(sign + text))
}

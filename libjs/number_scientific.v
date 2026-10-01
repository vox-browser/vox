module libjs

import math
import math.big

// AK::DecimalExponentialForm and convert_to_decimal_exponential_form. The
// pinned AK implementation delegates to fmt::detail::dragonbox::to_decimal;
// that untranslated backend is retained explicitly, without a host formatter.
pub struct NumberDecimalExponentialForm {
pub:
	sign     bool
	fraction u64
	exponent int
}

pub type NumberDecimalExponentialFormGetter = fn (number f64) NumberDecimalExponentialForm

struct NumberSignificandAndExponent {
	significand big.Integer
	exponent    int
}

fn number_count_digits(value u64) int {
	mut number := value
	mut count := 0
	for {
		number /= 10
		count++
		if number == 0 { return count }
	}
	return count
}

// The compute_significand lambda in NumberPrototype.cpp, lifted into a V
// function with the same captured binary representation and precision.
fn number_compute_significand(binary_significand big.Integer, binary_exponent int, precision int, exponent int) big.Integer {
	mut numerator := binary_significand
	mut denominator := big.integer_from_int(1)
	if binary_exponent > 0 {
		numerator = numerator.left_shift(u32(binary_exponent))
	} else if binary_exponent < 0 {
		denominator = denominator.left_shift(u32(-binary_exponent))
	}
	scale := precision - exponent - 1
	if scale > 0 {
		numerator = numerator * big.integer_from_int(10).pow(u32(scale))
	} else if scale < 0 {
		denominator = denominator * big.integer_from_int(10).pow(u32(-scale))
	}
	mut quotient, remainder := numerator.div_mod(denominator)
	if remainder.left_shift(1) >= denominator { quotient = quotient + big.integer_from_int(1) }
	return quotient
}

// Runtime/NumberPrototype.cpp::compute_significand_and_exponent_with_precision.
// The decimal backend supplies only the initial exponent. Exact binary integer
// arithmetic chooses the significand, corrects carries, and compares the two
// candidates at a power-of-ten boundary, choosing the larger candidate on ties.
fn compute_significand_and_exponent_with_precision(number f64, precision int, decimal NumberDecimalExponentialFormGetter) NumberSignificandAndExponent {
	seed := decimal(number)
	mut exponent := seed.exponent + number_count_digits(seed.fraction) - 1
	bits := math.f64_bits(number)
	binary_field := int((bits >> 52) & 0x7ff)
	mantissa := bits & ((u64(1) << 52) - 1)
	binary_significand := big.integer_from_u64(if binary_field == 0 {
		mantissa
	} else {
		mantissa | (u64(1) << 52)
	})
	binary_exponent := if binary_field == 0 { 1 - 1023 - 52 } else { binary_field - 1023 - 52 }
	mut significand := number_compute_significand(binary_significand, binary_exponent, precision,
		exponent)
	digit_count := significand.str().len
	if digit_count > precision {
		exponent++
		significand = number_compute_significand(binary_significand, binary_exponent, precision,
			exponent)
	} else if digit_count < precision {
		exponent--
		significand = number_compute_significand(binary_significand, binary_exponent, precision,
			exponent)
	}
	if significand == big.integer_from_int(10).pow(u32(precision - 1)) {
		alternate := number_compute_significand(binary_significand, binary_exponent, precision,
			exponent - 1)
		if alternate.str().len == precision {
			mut lhs := significand * big.integer_from_int(10) + alternate
			mut rhs := big.integer_from_int(2) * binary_significand
			scale := exponent - precision
			if scale > 0 {
				lhs = lhs * big.integer_from_int(10).pow(u32(scale))
			} else if scale < 0 {
				rhs = rhs * big.integer_from_int(10).pow(u32(-scale))
			}
			if binary_exponent > 0 {
				rhs = rhs.left_shift(u32(binary_exponent))
			} else if binary_exponent < 0 {
				lhs = lhs.left_shift(u32(-binary_exponent))
			}
			if lhs > rhs {
				significand = alternate
				exponent--
			}
		}
	}
	return NumberSignificandAndExponent{
		significand: significand
		exponent:    exponent
	}
}

// Runtime/NumberPrototype.cpp::to_exponential. The conversion of fractionDigits
// precedes the nonfinite fast path, while its range check follows that path.
pub fn number_prototype_to_exponential(mut vm VM, decimal NumberDecimalExponentialFormGetter) !Value {
	digits_value := vm.argument(0)
	number_value := this_number_value(mut vm, vm.this_value())!
	mut fraction_digits := vm.argument(0).to_integer_or_infinity(mut vm)!
	if !number_value.is_finite_number() {
		return Value.from_string(number_value.to_primitive_string(mut vm)!)
	}
	if fraction_digits < 0 || fraction_digits > 100 {
		return vm.throw_error_type(.range_error, .invalid_fraction_digits)
	}
	mut number := number_value.number
	sign := if number < 0 { '-' } else { '' }
	if number < 0 { number = -number }
	mut text := ''
	mut exponent := 0
	if number == 0 {
		text = '0'.repeat(int(fraction_digits) + 1)
	} else if !digits_value.is_undefined() {
		result := compute_significand_and_exponent_with_precision(number, int(fraction_digits) + 1,
			decimal)
		text = result.significand.str()
		exponent = result.exponent
	} else {
		result := decimal(number)
		text = result.fraction.str()
		fraction_digits = number_count_digits(result.fraction) - 1
		exponent = result.exponent + int(fraction_digits)
	}
	if fraction_digits != 0 { text = text[..1] + '.' + text[1..] }
	exponent_sign := if exponent < 0 { '-' } else { '+' }
	if exponent < 0 { exponent = -exponent }
	return Value.from_string(vm.create_string_from_str(sign + text + 'e' + exponent_sign +
		exponent.str()))
}

// Runtime/NumberPrototype.cpp::to_precision, including the alternate candidate
// below a decimal power and the -6/precision thresholds for scientific output.
pub fn number_prototype_to_precision(mut vm VM, decimal NumberDecimalExponentialFormGetter) !Value {
	precision_value := vm.argument(0)
	number_value := this_number_value(mut vm, vm.this_value())!
	if precision_value.is_undefined() {
		return Value.from_string(number_value.to_primitive_string(mut vm)!)
	}
	precision := precision_value.to_integer_or_infinity(mut vm)!
	if !number_value.is_finite_number() {
		return Value.from_string(number_value.to_primitive_string(mut vm)!)
	}
	if precision < 1 || precision > 100 {
		return vm.throw_error_type(.range_error, .invalid_precision)
	}
	mut number := number_value.number
	sign := if number < 0 { '-' } else { '' }
	if number < 0 { number = -number }
	count := int(precision)
	mut text := ''
	mut exponent := 0
	if number == 0 {
		text = '0'.repeat(count)
	} else {
		result := compute_significand_and_exponent_with_precision(number, count, decimal)
		text = result.significand.str()
		exponent = result.exponent
		if exponent < -6 || exponent >= count {
			if count != 1 { text = text[..1] + '.' + text[1..] }
			exponent_sign := if exponent < 0 { '-' } else { '+' }
			if exponent < 0 { exponent = -exponent }
			return Value.from_string(vm.create_string_from_str(sign + text + 'e' + exponent_sign +
				exponent.str()))
		}
	}
	if exponent == count - 1 { return Value.from_string(vm.create_string_from_str(sign + text)) }
	if exponent >= 0 {
		text = text[..exponent + 1] + '.' + text[exponent + 1..]
	} else {
		text = '0.' + '0'.repeat(-(exponent + 1)) + text
	}
	return Value.from_string(vm.create_string_from_str(sign + text))
}

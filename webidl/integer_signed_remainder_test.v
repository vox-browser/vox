module webidl

import math

fn test_signed_64_conversion_preserves_small_negative_integers_and_truncation() {
	for number in [-1.0, -2.0, -17.9, -1025.0, -9007199254740991.0] {
		assert convert_to_int(number_value(number), 64, true, .no, .no)! == math.ceil(number)
	}
}

fn test_signed_64_conversion_wraps_at_signed_boundaries_without_unsigned_round_trip() {
	half := math.pow(2, 63)
	assert convert_to_int(number_value(half), 64, true, .no, .no)! == -half
	assert convert_to_int(number_value(-half), 64, true, .no, .no)! == -half
	assert convert_to_int(number_value(half + 2048), 64, true, .no, .no)! == -half + 2048
	assert convert_to_int(number_value(-half - 2048), 64, true, .no, .no)! == half - 2048
}

fn test_signed_64_conversion_reduces_large_positive_and_negative_multiples() {
	modulus := math.pow(2, 64)
	for number, expected in {modulus + 4096: f64(4096), -modulus - 4096: f64(-4096), modulus - 4096: f64(-4096), -modulus + 4096: f64(4096)} {
		assert convert_to_int(number_value(number), 64, true, .no, .no)! == expected
	}
	for number in [modulus, -modulus, math.nan(), math.inf(1), math.inf(-1)] {
		assert convert_to_int(number_value(number), 64, true, .no, .no)! == 0
	}
}

fn test_signed_remainder_keeps_narrow_integer_wrap_and_unsigned_conversion() {
	for bits in [8, 16, 32] {
		half := math.pow(2, bits - 1)
		assert convert_to_int(number_value(-1), bits, true, .no, .no)! == -1
		assert convert_to_int(number_value(half), bits, true, .no, .no)! == -half
		assert convert_to_int(number_value(-half - 1), bits, true, .no, .no)! == half - 1
		assert convert_to_int(number_value(-1), bits, false, .no, .no)! == 2 * half - 1
	}
}

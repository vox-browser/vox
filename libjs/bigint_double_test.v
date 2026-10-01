module libjs

import math
import math.big

fn test_bigint_double_rounds_halfway_by_mantissa_parity_and_retains_sign() {
	for source, expected in {
		'0':                    0.0
		'42':                   42.0
		'9007199254740991':     9007199254740991.0
		'9007199254740993':     9007199254740992.0
		'9007199254740995':     9007199254740996.0
		'18014398509481985':    18014398509481984.0
		'18014398509481986':    18014398509481984.0
		'18014398509481987':    18014398509481988.0
		'18014398509481990':    18014398509481992.0
		'18446744073709551615': 18446744073709551616.0
	} {
		integer := big.integer_from_string(source)!
		assert big_integer_to_double(integer, .ties_to_even) == expected, source
		if integer.signum != 0 { assert big_integer_to_double(integer.neg(), .ties_to_even) == -expected
		 }
	}
	assert big_integer_to_double(big.integer_from_string('9007199254740995')!, .toward_zero) == 9007199254740994.0
	assert big_integer_to_double(big.integer_from_string('-9007199254740995')!, .toward_zero) == -9007199254740994.0
}

fn test_bigint_double_handles_word_boundaries_carry_overflow_and_exact_binary_roundtrips() {
	for power in [53, 60, 64, 127, 256, 511, 1023] {
		integer := big.integer_from_int(1).left_shift(u32(power))
		assert big_integer_to_double(integer, .ties_to_even) == math.ldexp(1, power)
		previous := big_integer_to_double(integer - big.integer_from_int(1), .ties_to_even)
		assert previous == if power == 53 {
			9007199254740991.0
		} else {
			math.ldexp(1, power)
		}
		assert big_integer_to_double(integer - big.integer_from_int(1), .toward_zero) <= math.ldexp(1,
			power)
	}
	maximum := big_integer_from_double(math.max_f64)
	assert big_integer_to_double(maximum, .ties_to_even) == math.max_f64
	boundary := big.integer_from_int(1).left_shift(1024) - big.integer_from_int(1).left_shift(970)
	assert math.is_inf(big_integer_to_double(boundary, .ties_to_even), 1)
	assert big_integer_to_double(boundary - big.integer_from_int(1), .ties_to_even) == math.max_f64
	assert big_integer_to_double(boundary, .toward_zero) == math.max_f64
	assert math.is_inf(big_integer_to_double(big.integer_from_int(1).left_shift(4096).neg(),
		.ties_to_even), -1)
	for number in [1e30, -1e30, 1e100, -1e100, math.max_f64, -math.max_f64] {
		assert big_integer_to_double(big_integer_from_double(number), .ties_to_even) == number
	}
}

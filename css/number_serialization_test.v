module css

import math

struct NumberSerializationCase {
	value    f64
	expected string
}

fn test_number_serialization_preserves_integer_limits_rounding_and_special_values() {
	cases := [
		NumberSerializationCase{0.0, '0'},
		NumberSerializationCase{-0.0, '0'},
		NumberSerializationCase{0.00000049, '0'},
		NumberSerializationCase{-0.00000049, '0'},
		NumberSerializationCase{0.00000051, '0.000001'},
		NumberSerializationCase{-0.00000051, '-0.000001'},
		NumberSerializationCase{1, '1'},
		NumberSerializationCase{-16, '-16'},
		NumberSerializationCase{12.5, '12.5'},
		NumberSerializationCase{1.2345674, '1.234567'},
		NumberSerializationCase{1.2345676, '1.234568'},
		NumberSerializationCase{2147483647.0, '2147483647'},
		NumberSerializationCase{-2147483648.0, '-2147483648'},
		NumberSerializationCase{2147483648.0, '2147483648'},
		NumberSerializationCase{-2147483649.0, '-2147483649'},
		NumberSerializationCase{math.inf(1), 'inf'},
		NumberSerializationCase{math.inf(-1), '-inf'},
		NumberSerializationCase{math.nan(), 'nan'},
	]
	for case in cases {
		assert serialize_a_number(case.value) == case.expected
	}
}

// Keep the fixed six-decimal formatter as an independent compatibility oracle
// for the integer and tail-trimming fast paths, including very large values.
fn fixed_six_decimal_serialization(value f64) string {
	if math.abs(value) < 0.0000005 {
		return '0'
	}
	formatted := '${value:.6f}'
	if formatted.contains('.') {
		trimmed := formatted.trim_right('0').trim_right('.')
		return if trimmed == '-0' { '0' } else { trimmed }
	}
	return formatted
}

fn test_number_serialization_matches_fixed_precision_across_magnitudes() {
	for exponent in [-308, -50, -8, -7, -6, -3, 0, 3, 6, 9, 20, 30, 100, 308] {
		for coefficient in [0.5, 1.0, 1.0000001, 1.2345675, 9.9999999] {
			for sign in [-1.0, 1.0] {
				value := sign * coefficient * math.pow(10, f64(exponent))
				if math.is_inf(value, 0) {
					continue
				}
				assert serialize_a_number(value) == fixed_six_decimal_serialization(value)
			}
		}
	}
	for index in 0 .. 10000 {
		integer := (index * 104729) % 500000 - 250000
		assert serialize_a_number(f64(integer)) == '${integer}'
		fraction := f64(integer) / 64
		assert serialize_a_number(fraction) == fixed_six_decimal_serialization(fraction)
	}
}

// SPDX-License-Identifier: BSD-2-Clause
module webidl

import math

fn test_primitive_to_number_uses_source_string_numeric_grammar() {
	for text, expected in {
		'':                   f64(0)
		'\u2000\u2028\ufeff': f64(0)
		'\u2000384\ufeff':    f64(384)
		'0x180':              f64(384)
		'0b110000000':        f64(384)
		'0o600':              f64(384)
		'-1.75e2':            f64(-175)
		'+2.5':               f64(2.5)
	} {
		assert value_to_number(string_value(text))! == expected
	}
	for text in ['-0x1', '+0b1', '0b2', '0o8', '1 trailing', 'infinity', 'NaN'] {
		assert math.is_nan(value_to_number(string_value(text))!)
	}
	assert math.is_inf(value_to_number(string_value('Infinity'))!, 1)
	assert math.is_inf(value_to_number(string_value('-Infinity'))!, -1)
	assert 1.0 / value_to_number(string_value('-0'))! == math.inf(-1)
	assert value_to_number(boolean_value(true))! == 1
	assert value_to_number(null_value())! == 0
	assert math.is_nan(value_to_number(undefined_value())!)
	if _ := value_to_number(bigint_value(0)) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Cannot convert BigInt to number'
	}
	if _ := value_to_number(object_value({
		'valueOf': number_value(3)
	})) {
		assert false
	} else {
		// The typed boundary cannot invoke VM ToPrimitive methods.
		assert err.msg() == 'TypeError: value cannot be converted to a number'
	}
	assert convert_to_int(string_value('0x100'), 8, false, .no, .no)! == 0
	assert convert_to_int(string_value('0xff'), 8, false, .yes, .no)! == 255
}

fn test_primitive_number_to_string_preserves_source_decimal_exponent_thresholds() {
	for value, expected in {
		f64(4294967296):          '4294967296'
		f64(9007199254740991):    '9007199254740991'
		f64(1e20):                '100000000000000000000'
		f64(1e21):                '1e+21'
		f64(1e-6):                '0.000001'
		f64(5e-7):                '5e-7'
		f64(1000000000000000128): '1000000000000000100'
	} {
		assert to_string(number_value(value))! == expected
		assert to_string(number_value(-value))! == '-${expected}'
	}
	assert to_string(number_value(-0.0))! == '0'
	assert to_string(number_value(math.nan()))! == 'NaN'
	assert to_string(number_value(math.inf(1)))! == 'Infinity'
	assert to_string(number_value(math.inf(-1)))! == '-Infinity'
}

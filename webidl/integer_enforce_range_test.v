// SPDX-License-Identifier: BSD-2-Clause
module webidl

import math

fn test_enforce_range_source_nonfinite_diagnostics_and_truncation_order() {
	for value in [number_value(math.nan()), number_value(math.inf(1)), number_value(math.inf(-1)),
		undefined_value(), string_value('not a number')] {
		if _ := convert_to_int(value, 32, false, .yes, .no) {
			assert false
		} else {
			assert err.msg() == 'TypeError: Number must not be NaN or Infinity'
		}
	}
	assert convert_to_int(number_value(-0.9), 8, false, .yes, .no)! == 0
	assert convert_to_int(number_value(255.9), 8, false, .yes, .no)! == 255
	assert convert_to_int(number_value(-128.9), 8, true, .yes, .no)! == -128
	assert convert_to_int(number_value(127.9), 8, true, .yes, .no)! == 127
	assert convert_to_int(number_value(4294967295.9), 32, false, .yes, .no)! == 4294967295
}

fn test_enforce_range_source_concrete_integer_bounds_and_decimal_formatting() {
	// Values are fractional before IntegerPart, and errors report the final
	// truncated integer with the source's concrete signed/unsigned bounds.
	for bits, invalid in {
		8:  f64(256.9)
		16: f64(65536.9)
		32: f64(4294967296.9)
		64: f64(9007199254740992)
	} {
		upper := match bits {
			8 { '255' }
			16 { '65535' }
			32 { '4294967295' }
			else { '9007199254740991' }
		}
		actual := match bits {
			8 { '256' }
			16 { '65536' }
			32 { '4294967296' }
			else { '9007199254740992' }
		}
		if _ := convert_to_int(number_value(invalid), bits, false, .yes, .no) {
			assert false
		} else {
			assert err.msg() == "TypeError: Number '${actual}' is outside of allowed range of 0 to ${upper}"
		}
	}
	if _ := convert_to_int(number_value(-129.9), 8, true, .yes, .no) {
		assert false
	} else {
		assert err.msg() == "TypeError: Number '-129' is outside of allowed range of -128 to 127"
	}
	if _ := convert_to_int(number_value(-9007199254740992), 64, true, .yes, .no) {
		assert false
	} else {
		assert err.msg() == "TypeError: Number '-9007199254740992' is outside of allowed range of -9007199254740991 to 9007199254740991"
	}
	for value, text in {
		f64(1e20):  '100000000000000000000'
		f64(1e21):  '1e+21'
		f64(-1e21): '-1e+21'
	} {
		if _ := convert_to_int(number_value(value), 32, false, .yes, .no) {
			assert false
		} else {
			assert err.msg() == "TypeError: Number '${text}' is outside of allowed range of 0 to 4294967295"
		}
	}
}

module webidl

import libjs

fn test_full_to_bigint_retains_arbitrary_precision_and_source_primitive_cases() {
	for text, decimal in {
		'': '0'
		'\u00a0\ufeff18446744073709551615\u2028': '18446744073709551615'
		'0x100000000000000000000000000000000': '340282366920938463463374607431768211456'
		'-18446744073709551617': '-18446744073709551617'
	} {
		integer := value_to_bigint(string_value(text))!
		assert integer.big_integer.str() == decimal
		primitive := bigint_value_for_record(integer)
		assert voidptr(value_to_bigint(primitive)!) == voidptr(integer)
		assert to_string(primitive)! == decimal
		assert value_to_bigint_int64(primitive)! == integer.to_i64()
	}
	assert value_to_bigint(boolean_value(true))!.big_integer.str() == '1'
	assert value_to_bigint(boolean_value(false))!.big_integer.str() == '0'
	assert value_to_bigint(bigint_value(-2))!.big_integer.str() == '-2'
	for value in [number_value(1), null_value(), undefined_value()] {
		if _ := value_to_bigint(value) { assert false } else { assert err.msg().starts_with('TypeError:') }
	}
	for text in ['1.5', '-0xff', '1n', '0b2'] {
		if _ := value_to_bigint(string_value(text)) { assert false } else { assert err.msg().starts_with('SyntaxError:') }
	}
}

fn test_full_to_bigint_requires_actual_runtime_conversion_and_preserves_original_completion() {
	reason := dom_exception_value_for_record(DOMException.create_record('OperationError', 'actual bigint failure'))
	value := runtime_value(RuntimeValue{
		bigint_conversion: fn [reason] () !&libjs.BigInt { return throw_value(reason) }
		string_conversion: fn () !string { assert false; return error('must not substitute ToString') }
	})
	if _ := value_to_bigint(value) { assert false } else {
		assert err is ValueException
		if err is ValueException { assert err.value.opaque_id == reason.opaque_id }
	}
	missing := runtime_value(RuntimeValue{
		bigint_int64_conversion: fn () !i64 { assert false; return error('must not use the wrapping operation') }
		string_conversion: fn () !string { assert false; return error('must not substitute ToString') }
	})
	if _ := value_to_bigint(missing) { assert false } else { assert err.msg().contains('full ToBigInt') }
}

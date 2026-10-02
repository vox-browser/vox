module webassembly

import webidl
import libjs

fn test_table64_source_full_to_bigint_bounds_and_unsigned_output() {
	maximum := u64(-1)
	for text, expected in {
		'': u64(0)
		'9223372036854775808': u64(1) << 63
		'18446744073709551615': maximum
		'0xffffffffffffffff': maximum
		'\u00a0\ufeff18446744073709551615\u2028': maximum
	} {
		assert address_value_to_u64(webidl.string_value(text), .i64)! == expected
		output := table_limit_to_js_value(expected, .i64)
		assert output.kind == .bigint
		assert webidl.to_string(output)! == expected.str()
		assert webidl.value_to_bigint(output)!.big_integer.signum >= 0
		assert address_value_to_u64(output, .i64)! == expected
	}
	assert address_value_to_u64(webidl.boolean_value(true), .i64)! == 1
	assert address_value_to_u64(webidl.boolean_value(false), .i64)! == 0
	for text in ['-1', '-18446744073709551616', '-340282366920938463463374607431768211456'] {
		if _ := address_value_to_u64(webidl.string_value(text), .i64) { assert false } else { assert err.msg() == 'TypeError: Table size must be non-negative' }
	}
	for text in ['18446744073709551616', '18446744073709551617', '340282366920938463463374607431768211456'] {
		if _ := address_value_to_u64(webidl.string_value(text), .i64) { assert false } else { assert err.msg() == 'TypeError: Table size is too large' }
	}
	for value in [webidl.number_value(1), webidl.null_value(), webidl.undefined_value()] {
		if _ := address_value_to_u64(value, .i64) { assert false } else { assert err.msg().starts_with('TypeError:') }
	}
	if _ := address_value_to_u64(webidl.string_value('1.5'), .i64) { assert false } else { assert err.msg().starts_with('SyntaxError:') }
}

fn test_table64_binding_bounds_follow_actual_conversion_and_original_completion() {
	reason := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('OperationError', 'actual table64 conversion'))
	value := webidl.runtime_value(webidl.RuntimeValue{
		bigint_conversion: fn [reason] () !&libjs.BigInt { return webidl.throw_value(reason) }
		bigint_int64_conversion: fn () !i64 { assert false; return error('must not wrap before bounds') }
		string_conversion: fn () !string { assert false; return error('must not substitute ToString') }
	})
	if _ := address_value_to_u64(value, .i64) { assert false } else {
		assert err is webidl.ValueException
		if err is webidl.ValueException { assert err.value.opaque_id == reason.opaque_id }
	}
	// Actual source Table store mutations remain behind the binding conversion.
	table_ := Table.create_machine(WebAssemblyCache.create(), BinaryValueType{kind: .extern_reference}, .i64,
		1, u64(2), BinaryNullReference{})!
	assert table_.length_from_bindings()!.bigint_value == 1
	assert table_.grow_from_bindings(webidl.boolean_value(true), webidl.string_value('new'))!.bigint_value == 1
	assert table_.length()! == 2
	assert table_.get_from_bindings(webidl.string_value('1'))!.string_value == 'new'
	if _ := table_.set_from_bindings(webidl.string_value('18446744073709551616'), webidl.string_value('wrong')) {
		assert false
	} else { assert err.msg() == 'TypeError: Table size is too large' }
	assert table_.get_from_bindings(webidl.string_value('1'))!.string_value == 'new'
}

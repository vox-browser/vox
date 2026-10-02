module webassembly

import webidl

fn test_i64_conversion_uses_source_to_bigint_and_low_signed_64_bits() {
	for text, expected in {
		'':                      i64(0)
		'\u00a0\ufeff42\u2028':  i64(42)
		'0xffffffffffffffff':    i64(-1)
		'18446744073709551617':  i64(1)
		'-18446744073709551617': i64(-1)
		'9223372036854775808':   i64(-9223372036854775807) - 1
	} {
		assert to_webassembly_value(webidl.string_value(text), .i64)!.i64_value == expected
	}
	assert to_webassembly_value(webidl.boolean_value(true), .i64)!.i64_value == 1
	assert to_webassembly_value(webidl.boolean_value(false), .i64)!.i64_value == 0
	for value in [webidl.number_value(1), webidl.null_value(), webidl.undefined_value()] {
		if _ := to_webassembly_value(value, .i64) {
			assert false
		} else {
			assert err.msg().starts_with('TypeError:')
		}
	}
	for text in ['1n', '1.5', '-0xff', '0b2'] {
		if _ := to_webassembly_value(webidl.string_value(text), .i64) {
			assert false
		} else {
			assert err.msg() == 'SyntaxError: Invalid value for BigInt: ${text}'
		}
	}
}

fn test_i64_globals_and_host_results_use_same_source_conversion() {
	mut global := construct_global(GlobalDescriptor{ value: .i64, mutable_: true }, webidl.boolean_value(true))!
	assert global.value()!.bigint_value == 1
	global.set_value(webidl.string_value('0xffffffffffffffff'))!
	assert global.value()!.bigint_value == -1
	function := create_host_function('bigint-binding-realm', fn (_ []webidl.Value) !webidl.Value {
		return webidl.string_value('18446744073709551617')
	}, FunctionType{ results: [.i64] }, 0)
	assert function.invoke([]WasmValue{})![0].i64_value == 1
	reason := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('OperationError', 'actual conversion failure'))
	throwing := webidl.runtime_value(webidl.RuntimeValue{
		bigint_int64_conversion: fn [reason] () !i64 { return webidl.throw_value(reason) }
		string_conversion:       fn () !string {
			panic('ToBigInt must not substitute string conversion')
		}
	})
	if _ := to_webassembly_value(throwing, .i64) {
		assert false
	} else {
		assert err is webidl.ValueException
		if err is webidl.ValueException {
			assert err.value.opaque_id == reason.opaque_id
		}
	}
}

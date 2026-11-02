module browserjs

import webassembly
import webidl

fn test_actual_engine_to_bigint_i64_preserves_number_hint_and_original_throws() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	actual := runtime.evaluate_host_value('globalThis.bigintHints=[];({[Symbol.toPrimitive](hint){bigintHints.push(hint);return "18446744073709551617"},valueOf(){throw "wrong hook"}})')!
	value := runtime.webidl_value(actual)!
	assert webidl.value_to_bigint_int64(value)! == 1
	assert webassembly.to_webassembly_value(value, .i64)!.i64_value == 1
	assert runtime.evaluate_host('JSON.stringify(bigintHints)')! == '["number","number"]'
	for expression in ['true', '"18446744073709551617"', '18446744073709551617n'] {
		native := runtime.evaluate_host_value(expression)!
		assert webidl.value_to_bigint_int64(runtime.webidl_value(native)!)! == 1
	}
	for expression, expected in {
		'9223372036854775807n':   i64(9223372036854775807)
		'9223372036854775808n':   i64(-9223372036854775807) - 1
		'18446744073709551615n':  i64(-1)
		'-18446744073709551617n': i64(-1)
	} {
		native := runtime.evaluate_host_value(expression)!
		assert webidl.value_to_bigint_int64(runtime.webidl_value(native)!)! == expected
	}
	for expression in ['1', 'null', 'undefined', 'Symbol()', '({valueOf(){return 1}})', '"1.5"'] {
		native := runtime.evaluate_host_value(expression)!
		if _ := webidl.value_to_bigint_int64(runtime.webidl_value(native)!) {
			assert false
		} else {
			assert err is JavaScriptValueException
		}
	}
	throwing := runtime.evaluate_host_value('globalThis.bigintReason=Symbol("actual bigint throw");({[Symbol.toPrimitive](){throw bigintReason}})')!
	wrapped := runtime.webidl_value(throwing)!
	runtime.define_value_host_function('__convertActualBigint', fn [runtime, wrapped] (_ voidptr, _ []voidptr) !voidptr {
		webidl.value_to_bigint_int64(wrapped)!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	assert runtime.evaluate_host('let caught;try{__convertActualBigint()}catch(error){caught=error}caught===bigintReason')! == 'true'
	runtime.evaluate_host('BigInt.asIntN=()=>{throw "author asIntN"};globalThis.BigInt=()=>{throw "author BigInt"};BigInt.prototype={toString(){throw "author toString"}};undefined')!
	assert webidl.value_to_bigint_int64(value)! == 1
	runtime.close()
	if _ := webidl.value_to_bigint_int64(value) {
		assert false
	} else {
		assert err.msg().contains('closed')
	}
}

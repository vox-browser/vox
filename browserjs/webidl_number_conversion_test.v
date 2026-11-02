module browserjs

import math
import webidl

fn test_actual_engine_to_number_preserves_primitive_hooks_and_original_exceptions() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	actual := runtime.evaluate_host_value('globalThis.numberHints=[];({[Symbol.toPrimitive](hint){numberHints.push(hint);return "4294967297.75"},valueOf(){throw "wrong hook"}})')!
	value := runtime.webidl_value(actual)!
	assert value.number_primitive() == none
	assert webidl.value_to_number(value)! == 4294967297.75
	assert webidl.convert_to_int(value, 32, true, .no, .no)! == 1
	assert runtime.evaluate_host('JSON.stringify(numberHints)')! == '["number","number"]'
	for expression in ['1n', 'Symbol()'] {
		non_number := runtime.evaluate_host_value(expression)!
		non_number_wrapped := runtime.webidl_value(non_number)!
		if _ := webidl.value_to_number(non_number_wrapped) {
			assert false
		} else {
			assert err is JavaScriptValueException
		}
	}
	throwing := runtime.evaluate_host_value('globalThis.numberReason=Symbol("actual throw");({[Symbol.toPrimitive](){throw numberReason}})')!
	wrapped := runtime.webidl_value(throwing)!
	runtime.define_value_host_function('__convertActualNumber', fn [runtime, wrapped] (_ voidptr, _ []voidptr) !voidptr {
		webidl.value_to_number(wrapped)!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	assert runtime.evaluate_host('let caught;try{__convertActualNumber()}catch(error){caught=error}caught===numberReason')! == 'true'
	runtime.evaluate_host('globalThis.Number=()=>{throw "author Number"}')!
	assert webidl.value_to_number(value)! == 4294967297.75
	for expression in ['NaN', 'undefined'] {
		native := runtime.evaluate_host_value(expression)!
		assert math.is_nan(webidl.value_to_number(runtime.webidl_value(native)!)!)
	}
	zero := runtime.evaluate_host_value('-0')!
	assert math.signbit(webidl.value_to_number(runtime.webidl_value(zero)!)!)
	runtime.close()
	if _ := webidl.value_to_number(value) {
		assert false
	} else {
		assert err.msg().contains('closed')
	}
}

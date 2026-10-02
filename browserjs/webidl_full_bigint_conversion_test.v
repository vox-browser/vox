module browserjs

import webidl

fn test_actual_engine_full_to_bigint_preserves_number_hint_once_and_arbitrary_width() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	actual := runtime.evaluate_host_value('globalThis.fullBigintHints=[];({[Symbol.toPrimitive](hint){fullBigintHints.push(hint);return "340282366920938463463374607431768211457"},valueOf(){throw "wrong hook"}})')!
	value := runtime.webidl_value(actual)!
	integer := webidl.value_to_bigint(value)!
	assert integer.big_integer.str() == '340282366920938463463374607431768211457'
	assert runtime.evaluate_host('fullBigintHints.length===1&&fullBigintHints[0]==="number"')! == 'true'
	projected := runtime.javascript_bigint(webidl.bigint_value_for_record(integer))!
	runtime.define_value_host_function('__actualFullBigintOutput', fn [projected] (_ voidptr, _ []voidptr) !voidptr { return projected })!
	assert runtime.evaluate_host('typeof __actualFullBigintOutput()==="bigint"&&__actualFullBigintOutput()===340282366920938463463374607431768211457n')! == 'true'
	ordinary := runtime.evaluate_host_value('globalThis.fullBigintOrder=[];({get [Symbol.toPrimitive](){fullBigintOrder.push("exotic");return null},get valueOf(){fullBigintOrder.push("valueOf get");return function(){fullBigintOrder.push("valueOf call");return {}}},get toString(){fullBigintOrder.push("toString get");return function(){fullBigintOrder.push("toString call");return "18446744073709551615"}}})')!
	assert webidl.value_to_bigint(runtime.webidl_value(ordinary)!)!.big_integer.str() == '18446744073709551615'
	assert runtime.evaluate_host('fullBigintOrder.join("|")==="exotic|valueOf get|valueOf call|toString get|toString call"')! == 'true'
	for expression in ['true', '"18446744073709551615"', '18446744073709551615n', '-18446744073709551617n'] {
		native := runtime.evaluate_host_value(expression)!
		assert webidl.value_to_bigint(runtime.webidl_value(native)!)!.big_integer.str() != ''
	}
	for expression in ['1', 'null', 'undefined', 'Symbol()', '({valueOf(){return 1}})', '"1.5"', '({[Symbol.toPrimitive]:1})', '({[Symbol.toPrimitive](){return {}}})', '({valueOf(){return {}},toString(){return {}}})'] {
		native := runtime.evaluate_host_value(expression)!
		if _ := webidl.value_to_bigint(runtime.webidl_value(native)!) { assert false } else { assert err is JavaScriptValueException }
	}
	throwing := runtime.evaluate_host_value('globalThis.fullBigintReason=Symbol("actual bigint failure");({get [Symbol.toPrimitive](){throw fullBigintReason}})')!
	wrapped := runtime.webidl_value(throwing)!
	runtime.define_value_host_function('__throwFullBigint', fn [wrapped] (_ voidptr, _ []voidptr) !voidptr {
		webidl.value_to_bigint(wrapped)!
		return unsafe { nil }
	})!
	assert runtime.evaluate_host('{let caught;try{__throwFullBigint()}catch(error){caught=error}caught===fullBigintReason}')! == 'true'
	runtime.evaluate_host('globalThis.BigInt=()=>{throw "author BigInt"};Reflect.apply=()=>{throw "author apply"};Symbol.toPrimitive="author key";Array.prototype[Symbol.iterator]=()=>{throw "author iterator"};undefined')!
	assert webidl.value_to_bigint(value)!.big_integer.str() == integer.big_integer.str()
	assert webidl.value_to_bigint(runtime.webidl_value(ordinary)!)!.big_integer.str() == '18446744073709551615'
	runtime.close()
	if _ := webidl.value_to_bigint(value) { assert false } else { assert err.msg().contains('closed') }
}

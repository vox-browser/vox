module browserjs

import webidl

fn test_native_simple_exception_conversion_reuses_one_actual_engine_error_value() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	for type_ in [webidl.SimpleExceptionType.range_error, .type_error, .eval_error, .reference_error, .uri_error] {
		native := &webidl.SimpleException{type_: type_, message: 'source completion message'}
		value := webidl.simple_exception_value_for_record(native)
		actual := runtime.javascript_simple_exception(value)!
		assert actual == runtime.javascript_simple_exception(value)!
		other := runtime.javascript_simple_exception(webidl.simple_exception_value(webidl.SimpleException{type_: type_, message: native.message}))!
		assert actual != other
		function_name := '__sourceSimple' + native.name()
		runtime.define_value_host_function(function_name, fn [actual] (_ voidptr, _ []voidptr) !voidptr { return actual })!
		assert runtime.evaluate_host(function_name+'().name')! == native.name()
		assert runtime.evaluate_host(function_name+'() instanceof '+native.name()+'&&'+function_name+'().message==="source completion message"')! == 'true'
	}
	runtime.evaluate_host('globalThis.actualRangeError=RangeError;globalThis.RangeError=function(){throw "author constructor"}')!
	actual := runtime.javascript_simple_exception(webidl.simple_exception_value(webidl.SimpleException{type_: .range_error, message: 'captured intrinsic'}))!
	runtime.define_value_host_function('__sourceActualRangeError', fn [actual] (_ voidptr, _ []voidptr) !voidptr { return actual })!
	assert runtime.evaluate_host('__sourceActualRangeError() instanceof actualRangeError')! == 'true'
	runtime.close()
	if _ := runtime.javascript_simple_exception(webidl.simple_exception_value(webidl.SimpleException{type_: .range_error})) { assert false } else { assert err.msg().contains('closed') }
}

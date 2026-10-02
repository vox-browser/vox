module webassembly

import math
import webidl

fn test_source_numeric_wasm_conversions_use_to_number_before_numeric_narrowing() {
	assert to_webassembly_value(webidl.string_value('0x100000001'), .i32)!.i32_value == 1
	assert to_webassembly_value(webidl.number_value(2147483648.75), .i32)!.i32_value == -2147483648
	assert to_webassembly_value(webidl.number_value(-4294967297.9), .i32)!.i32_value == -1
	assert to_webassembly_value(webidl.boolean_value(true), .i32)!.i32_value == 1
	assert to_webassembly_value(webidl.null_value(), .i32)!.i32_value == 0
	for value in [webidl.undefined_value(), webidl.number_value(math.nan()),
		webidl.number_value(math.inf(1)), webidl.number_value(math.inf(-1))] {
		assert to_webassembly_value(value, .i32)!.i32_value == 0
	}
	assert to_webassembly_value(webidl.string_value('1.5'), .f32)!.f32_value == 1.5
	assert to_webassembly_value(webidl.boolean_value(false), .f32)!.f32_value == 0
	assert to_webassembly_value(webidl.null_value(), .f64)!.f64_value == 0
	assert math.is_nan(to_webassembly_value(webidl.undefined_value(), .f64)!.f64_value)
	assert math.is_inf(to_webassembly_value(webidl.string_value('Infinity'), .f64)!.f64_value, 1)
	assert f64(to_webassembly_value(webidl.number_value(16777217), .f32)!.f32_value) == 16777216
	assert math.signbit(to_webassembly_value(webidl.number_value(-0.0), .f64)!.f64_value)
	for type_ in [ValueType.i32, .f32, .f64] {
		if _ := to_webassembly_value(webidl.bigint_value(1), type_) {
			assert false
		} else {
			assert err.msg() == 'TypeError: Cannot convert BigInt to number'
		}
	}
}

fn test_global_setter_and_host_result_use_source_numeric_conversion() {
	mut global := construct_global(GlobalDescriptor{ value: .i32, mutable_: true }, webidl.string_value('3.5'))!
	assert global.value()!.number_value == 3
	global.set_value(webidl.boolean_value(true))!
	assert global.value()!.number_value == 1
	global.set_value(webidl.number_value(math.inf(1)))!
	assert global.value()!.number_value == 0
	function := create_host_function('numeric-binding-realm', fn (_ []webidl.Value) !webidl.Value {
		return webidl.string_value('4294967295')
	}, FunctionType{ results: [.i32] }, 0)
	assert function.invoke([]WasmValue{})![0].i32_value == -1
}

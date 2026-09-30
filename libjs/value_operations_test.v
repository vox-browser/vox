module libjs

import math

fn test_string_to_number_uses_ecmascript_whitespace_radices_and_complete_input() {
	for text, expected in {
		'':                     0.0
		'\u00a0\ufeff42\u2028': 42.0
		'0xff':                 255.0
		'0B101':                5.0
		'0o77':                 63.0
		'.5':                   0.5
		'1.e2':                 100.0
		'-2e-2':                -0.02
		'0x20000000000003':     9007199254740996.0
	} {
		assert string_to_number(utf16_string(text)) == expected, text
	}
	assert math.is_inf(string_to_number(utf16_string(' +Infinity ')), 1)
	assert math.is_inf(string_to_number(utf16_string('-Infinity')), -1)
	assert math.signbit(string_to_number(utf16_string('-0')))
	for invalid in ['+0x1', '-0b1', '0b2', '0o8', '0x', 'nan', 'inf', '1_0', '1 0', '1e', '.',
		'+', '1.2.3', '\u008542', '\u180e42', '42' + [u8(0)].bytestr()] {
		assert math.is_nan(string_to_number(utf16_string(invalid))), invalid
	}
}

fn test_primitive_coercion_modulo_int32_and_negative_zero_arithmetic() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert js_null().to_number(mut vm)!.as_i32() == 0
	assert Value.from_bool(true).to_number(mut vm)!.as_i32() == 1
	assert math.is_nan(js_undefined().to_number(mut vm)!.number)
	assert Value.from_f64(4294967297.9).to_u32(mut vm)! == 1
	assert Value.from_f64(-4294967297.9).to_u32(mut vm)! == 0xffffffff
	assert Value.from_f64(2147483648.0).to_i32(mut vm)! == -2147483648
	assert Value.from_f64(math.inf(1)).to_i32(mut vm)! == 0
	assert add(mut vm, Value.from_i32(2147483647), Value.from_i32(1))!.number == 2147483648.0
	assert math.signbit(mul(mut vm, Value.from_i32(0), Value.from_i32(-1))!.number)
	assert math.signbit(unary_minus(mut vm, Value.from_i32(0))!.number)
	assert math.is_inf(div(mut vm, Value.from_i32(1), Value.from_f64(-0.0))!.number, -1)
	assert math.is_nan(div(mut vm, Value.from_i32(0), Value.from_i32(0))!.number)
	assert mod_(mut vm, Value.from_i32(-5), Value.from_i32(2))!.number == -1
	assert math.signbit(mod_(mut vm, Value.from_i32(-4), Value.from_i32(2))!.number)
	assert exp(mut vm, Value.from_f64(math.nan()), Value.from_i32(0))!.number == 1
	assert math.is_nan(exp(mut vm, Value.from_i32(1), Value.from_f64(math.inf(1)))!.number)
}

fn test_string_addition_comparisons_and_equality_keep_utf16_content() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	one := Value.from_string(vm.create_string_from_str('1'))
	assert add(mut vm, one, Value.from_i32(2))!.as_string().str() == '12'
	assert add(mut vm, js_null(), one)!.as_string().str() == 'null1'
	assert sub(mut vm, one, Value.from_bool(true))!.number == 0
	zero_text := Value.from_f64(-0.0).to_primitive_string(mut vm)!
	assert zero_text.str() == '0'
	first := Value.from_string(&PrimitiveString{
		utf16: Utf16String{
			data: [u16(0xd800)]
		}
	})
	second := Value.from_string(&PrimitiveString{
		utf16: Utf16String{
			data: [u16(0xdc00)]
		}
	})
	joined := add(mut vm, first, second)!.as_string().utf16.data
	assert joined == [u16(0xd800), 0xdc00]
	assert is_strictly_equal(first, Value.from_string(&PrimitiveString{
		utf16: first.as_string().utf16.clone()
	}))
	assert is_strictly_equal(Value.from_i32(0), Value.from_f64(-0.0))
	assert !is_strictly_equal(Value.from_f64(math.nan()), Value.from_f64(math.nan()))
	assert !is_strictly_equal(one, Value.from_i32(1))
	assert is_loosely_equal(mut vm, one, Value.from_bool(true))!
	assert is_loosely_equal(mut vm, js_null(), js_undefined())!
	assert compare_primitive_values(mut vm, first, second)! == .less
	assert compare_primitive_values(mut vm, Value.from_f64(math.nan()), one)! == .unordered
}

fn test_symbol_conversion_and_objects_without_coercion_methods_throw_type_errors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	symbol := Value.from_symbol(Symbol.create(utf16_string('key'), .unique))
	if _ := symbol.to_number(mut vm) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	if _ := symbol.to_primitive_string(mut vm) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	object := Value.from_object(Object.create(vm.realm(), none))
	if _ := add(mut vm, object, Value.from_i32(1)) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
}

fn test_number_exponentiation_keeps_upstream_infinite_and_signed_zero_cases() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert math.is_inf(exp(mut vm, Value.from_f64(math.inf(-1)), Value.from_f64(0.5))!.number, 1)
	assert math.is_inf(exp(mut vm, Value.from_f64(math.inf(-1)), Value.from_i32(3))!.number, -1)
	assert math.is_inf(exp(mut vm, Value.from_f64(math.inf(-1)), Value.from_f64(math.inf(1)))!.number, 1)
	assert !math.signbit(exp(mut vm, Value.from_f64(math.inf(-1)), Value.from_f64(-0.5))!.number)
	assert math.signbit(exp(mut vm, Value.from_f64(math.inf(-1)), Value.from_i32(-3))!.number)
	assert !math.signbit(exp(mut vm, Value.from_f64(-0.0), Value.from_f64(0.5))!.number)
	assert math.signbit(exp(mut vm, Value.from_f64(-0.0), Value.from_i32(3))!.number)
	assert math.is_inf(exp(mut vm, Value.from_f64(-0.0), Value.from_f64(-0.5))!.number, 1)
	assert math.is_inf(exp(mut vm, Value.from_f64(-0.0), Value.from_i32(-3))!.number, -1)
	assert math.is_nan(exp(mut vm, Value.from_i32(-2), Value.from_f64(0.5))!.number)
}

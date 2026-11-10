module libjs

import math

fn string_units_call(mut vm VM, code_points bool, arguments []Value) !Value {
	function := NativeFunction.create_raw(mut vm, vm.realm(), vm.realm().function_prototype, if code_points {
		NativeFunctionPointer(string_constructor_from_code_point)
	} else {
		NativeFunctionPointer(string_constructor_from_char_code)
	}, 1, PropertyName.from_str(if code_points { 'fromCodePoint' } else { 'fromCharCode' }), none)
	return call(mut vm, Value.from_object(function.object), js_null(), arguments)
}

fn test_string_character_constructors_preserve_upstream_units_and_supplementary_pairs() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for code_points in [false, true] {
		assert string_units_call(mut vm, code_points, []Value{})!.as_string().is_empty()
		for argument in [Value.from_i32(0), Value.from_f64(-0.0),
			Value.from_bool(false), js_null()] {
			assert string_units_call(mut vm, code_points, [argument])!.as_string().utf16.data == [
				u16(0),
			]
		}
		for argument in [Value.from_i32(1), Value.from_bool(true)] {
			assert string_units_call(mut vm, code_points, [argument])!.as_string().utf16.data == [
				u16(1),
			]
		}
		assert string_units_call(mut vm, code_points, [Value.from_i32(65),
			Value.from_i32(66), Value.from_i32(67)])!.as_string().str() == 'ABC'
		assert string_units_call(mut vm, code_points, [Value.from_i32(228),
			Value.from_i32(246), Value.from_i32(252)])!.as_string().str() == 'äöü'
		assert string_units_call(mut vm, code_points, [Value.from_i32(0xd800),
			Value.from_i32(0xdc00), Value.from_i32(0xffff)])!.as_string().utf16.data == [
			u16(0xd800),
			0xdc00,
			0xffff,
		]
	}
	for argument in [js_undefined(), Value.from_f64(math.nan()),
		Value.from_f64(math.inf(1)), Value.from_f64(math.inf(-1))] {
		assert string_units_call(mut vm, false, [argument])!.as_string().utf16.data == [
			u16(0),
		]
	}
	for number in [-1.0, 65535.0, f64(0x123ffff), -1.9] {
		assert string_units_call(mut vm, false, [Value.from_f64(number)])!.as_string().utf16.data == [
			u16(0xffff),
		]
	}
	assert string_units_call(mut vm, true, [Value.from_i32(0x10000),
		Value.from_i32(0x1f600), Value.from_i32(0x10ffff)])!.as_string().utf16.data == [
		u16(0xd800),
		0xdc00,
		0xd83d,
		0xde00,
		0xdbff,
		0xdfff,
	]
}

@[heap]
struct StringUnitsLog {
mut:
	indices []int
}

fn test_string_character_constructors_convert_left_to_right_once_and_stop_on_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &StringUnitsLog{}
	mut arguments := []Value{}
	for index in 0 .. 3 {
		mut object := Object.create(vm.realm(), none)
		coercion := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [index, mut log] (mut vm VM) !Value {
			assert vm.argument(0).as_string().str() == 'number'
			log.indices << index
			if index == 1 { return throw_completion(Value.from_i32(77)) }
			return Value.from_i32(65 + index)
		}, 1, PropertyName.from_str('coerce'), none)
		object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(coercion.object), 7)
		arguments << Value.from_object(object)
	}
	for code_points in [false, true] {
		if _ := string_units_call(mut vm, code_points, arguments) {
			assert false
		} else {
			assert thrown_value(err).number == 77
		}
		assert log.indices == [0, 1]
		log.indices.clear()
		// Exercise the one-argument fromCharCode implementation as well.
		assert string_units_call(mut vm, code_points, arguments[..1])!.as_string().str() == 'A'
		assert log.indices == [0]
		log.indices.clear()
		integer := string_to_bigint(utf16_string('65')) or { panic('fixture') }
		for argument in [Value.from_symbol(Symbol.create(none, .unique)),
			Value.from_bigint(integer)] {
			if _ := string_units_call(mut vm, code_points, [argument]) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
		}
	}
	for number in [math.nan(), math.inf(1), math.inf(-1), -5.0, 1.5, f64(0x123ffff), f64(0x110000),
		4294967296.0, -4294967296.0, 4294967361.0, -4294967231.0, 9007199254740992.0] {
		if _ := string_units_call(mut vm, true, [Value.from_f64(number), arguments[2]]) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
			assert thrown_value(err).as_object().error_message()?.str() == 'Invalid code point ' +
				format_f64_value(number) +
				', must be an integer no less than 0 and no greater than 0x10FFFF'
		}
		assert log.indices.len == 0
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

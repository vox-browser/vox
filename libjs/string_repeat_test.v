module libjs

import math

fn string_repeat_call(mut vm VM, receiver Value, count Value) !Value {
	method := NativeFunction.create_raw(mut vm, vm.realm(), vm.realm().function_prototype,
		string_prototype_repeat, 1, PropertyName.from_str('repeat'), none)
	return call(mut vm, Value.from_object(method.object), receiver, [count])
}

fn test_string_repeat_retains_upstream_counts_utf16_and_overflow_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	text := Value.from_string(vm.create_string_from_str('foo'))
	for index, number in [0.0, 1.0, 2.0, 3.0, 3.1, 3.5, 3.9] {
		result := string_repeat_call(mut vm, text, Value.from_f64(number))!
		assert result.as_string().str() == ['', 'foo', 'foofoo', 'foofoofoo', 'foofoofoo',
			'foofoofoo', 'foofoofoo'][index]
	}
	for count in [js_undefined(), js_null(), Value.from_bool(false),
		Value.from_f64(math.nan()), Value.from_f64(-0.0), Value.from_f64(-0.9),
		Value.from_string(vm.empty_string())] {
		assert string_repeat_call(mut vm, text, count)!.as_string().is_empty()
	}
	assert string_repeat_call(mut vm, Value.from_i32(42), Value.from_bool(true))!.as_string().str() == '42'
	units := Value.from_string(vm.create_string(Utf16String.from_slice([u16(0xd800), 0, 0xdc00])))
	assert string_repeat_call(mut vm, units, Value.from_i32(3))!.as_string().utf16.data == [
		u16(0xd800),
		0,
		0xdc00,
		0xd800,
		0,
		0xdc00,
		0xd800,
		0,
		0xdc00,
	]
	assert string_repeat_call(mut vm, Value.from_string(vm.create_string_from_str('😀')),
		Value.from_i32(2))!.as_string().str() == '😀😀'
	for number in [9007199254740991.0, 9007199254740992.0, 1e300] {
		assert string_repeat_call(mut vm, Value.from_string(vm.empty_string()),
			Value.from_f64(number))!.as_string().is_empty()
	}
	for receiver in [text, Value.from_string(vm.empty_string())] {
		for index, number in [-1.0, math.inf(-1), math.inf(1)] {
			if _ := string_repeat_call(mut vm, receiver, Value.from_f64(number)) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .range_error
				assert thrown_value(err).as_object().error_message()?.str() == if index == 2 {
					'repeat count must be a finite number'
				} else {
					'repeat count must be a positive number'
				}
			}
		}
	}
	for number in [f64(0xffffffffff), math.pow(2, 64), 9007199254740992.0, 2147483648.0] {
		if _ := string_repeat_call(mut vm, text, Value.from_f64(number)) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'repeat count must not overflow'
		}
	}
	// Source-valid lengths above V's signed-int array capacity retain its guard.
	if _ := string_repeat_call(mut vm, Value.from_string(vm.create_string_from_str('a')),
		Value.from_f64(2147483648.0))
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .range_error
	}
}

@[heap]
struct StringRepeatLog {
mut:
	steps []int
}

fn test_string_repeat_coerces_receiver_then_count_once_and_restores_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &StringRepeatLog{}
	mut values := []Value{}
	for index in 0 .. 3 {
		mut object := Object.create(vm.realm(), none)
		converter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [index, mut log] (mut vm VM) !Value {
			assert vm.argument(0).as_string().str() == if index == 0 { 'string' } else { 'number' }
			log.steps << index
			if index == 2 { return throw_completion(Value.from_i32(77)) }
			if index == 0 { return Value.from_string(vm.create_string_from_str('ab')) }
			return Value.from_i32(2)
		}, 1, PropertyName.from_str('convert'), none)
		object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(converter.object), 7)
		values << Value.from_object(object)
	}
	assert string_repeat_call(mut vm, values[0], values[1])!.as_string().str() == 'abab'
	assert log.steps == [0, 1]
	log.steps.clear()
	if _ := string_repeat_call(mut vm, values[0], values[2]) {
		assert false
	} else {
		assert thrown_value(err).number == 77
	}
	assert log.steps == [0, 2]
	log.steps.clear()
	for receiver in [js_null(), js_undefined(), Value.from_symbol(Symbol.create(none, .unique))] {
		if _ := string_repeat_call(mut vm, receiver, values[2]) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	assert log.steps.len == 0
	for count in [Value.from_symbol(Symbol.create(none, .unique)),
		Value.from_bigint(string_to_bigint(utf16_string('2')) or { panic('invalid BigInt literal') })] {
		if _ := string_repeat_call(mut vm, values[0], count) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

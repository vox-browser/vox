module libjs

import math

fn number_string_call(mut vm VM, receiver Value, arguments []Value, value_of bool) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [value_of] (mut vm VM) !Value {
		if value_of { return number_prototype_value_of(mut vm) }
		return number_prototype_to_string(mut vm)
	}, 1, PropertyName.from_str('numberString'), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_number_radix_conversion_matches_all_upstream_integer_and_large_number_fixtures() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for row in $embed_file('testdata/number_radix_cases.tsv').to_string().split_into_lines() {
		if row == '' || row.starts_with('#') { continue
		 }
		parts := row.split('\t')
		number := if parts[0] == 'small' { 7857632.0 } else { 2.2171010912173817e51 }
		for sign in [f64(1), f64(-1)] {
			prefix := if sign < 0 { '-' } else { '' }
			text := number_string_call(mut vm, Value.from_f64(number * sign), [
				Value.from_i32(parts[1].int()),
			], false)!
			assert text.as_string().str() == prefix + parts[2], row
		}
	}
	assert number_string_call(mut vm, Value.from_f64(0.5), [Value.from_i32(2)], false)!.as_string().str() == '0.1'
	assert number_string_call(mut vm, Value.from_f64(-0.5), [
		Value.from_i32(16),
	], false)!.as_string().str() == '-0.8'
	assert number_string_call(mut vm, Value.from_i32(30), [Value.from_f64(10.9)], false)!.as_string().str() == '30'
}

fn test_number_value_of_and_to_string_retain_wrapper_brand_numeric_specials_and_coercion_order() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for number in [0.0, -0.0, 42.0, math.nan(), math.inf(1), math.inf(-1)] {
		value := Value.from_f64(number)
		wrapper := NumberObject.create(vm.realm(), number, parent)
		for receiver in [value, Value.from_object(wrapper.object)] {
			assert same_value(number_string_call(mut vm, receiver, [
				Value.from_symbol(Symbol.create(none, .unique)),
			], true)!, value)
			for radix in [js_undefined(), Value.from_i32(2), Value.from_i32(10),
				Value.from_i32(36)] {
				expected := if number == 42 && radix.is_number() && radix.number == 2 {
					'101010'
				} else if number == 42 && radix.is_number() && radix.number == 36 {
					'16'
				} else {
					format_f64_value(number)
				}
				assert number_string_call(mut vm, receiver, [radix], false)!.as_string().str() == expected
			}
		}
	}
	mut poison := Object.create(vm.realm(), none)
	thrower := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(77))
	}, 1, PropertyName.from_str('thrower'), none)
	poison.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(thrower.object), 7)
	branded_parent := NumberObject.create(vm.realm(), 42, parent).object
	mut spoof := Object.create(vm.realm(), branded_parent)
	spoof.class_name = 'NumberObject'
	for receiver in [js_undefined(), js_null(), Value.from_bool(true),
		Value.from_object(spoof), Value.from_string(vm.create_string_from_str('42')),
		Value.from_symbol(Symbol.create(none, .unique))] {
		for value_of in [false, true] {
			if _ := number_string_call(mut vm, receiver, [Value.from_object(poison)], value_of) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == 'Not an object of type Number'
			}
		}
	}
	if _ := number_string_call(mut vm, Value.from_f64(math.inf(1)), [
		Value.from_object(poison),
	], false)
	{
		assert false
	} else {
		assert thrown_value(err).number == 77
	}
	for radix in [Value.from_i32(1), Value.from_i32(37), Value.from_f64(math.inf(1)),
		js_null()] {
		if _ := number_string_call(mut vm, Value.from_f64(math.nan()), [radix], false) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

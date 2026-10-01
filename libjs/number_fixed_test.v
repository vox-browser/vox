module libjs

import math

fn number_fixed_call(mut vm VM, receiver Value, arguments []Value) !Value {
	function := NativeFunction.create_raw(mut vm, vm.realm(), vm.realm().function_prototype,
		number_prototype_to_fixed, 1, PropertyName.from_str('toFixed'), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_number_fixed_uses_exact_binary_value_and_half_up_rounding_at_upstream_boundaries() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	numbers := [0.0, -0.0, 12.81646112, 84.23, 3.00003, 0.00006, 1e21, -1e22, 1.5, math.pi, 123456.78,
		1.005, 2.55, 2.5, -2.5, math.f64_from_bits(1), -math.f64_from_bits(1)]
	digits := [5, 5, 3, 4, 5, 4, 5, 0, 30, 50, 50, 2, 1, 0, 0, 100, 100]
	texts := ['0.00000', '0.00000', '12.816', '84.2300', '3.00003', '0.0001', '1e+21', '-1e+22',
		'1.500000000000000000000000000000', '3.14159265358979311599796346854418516159057617187500',
		'123456.77999999999883584678173065185546875000000000000000', '1.00', '2.5', '3', '-3',
		'0.' + '0'.repeat(100), '-0.' + '0'.repeat(100)]
	parent := Object.create(vm.realm(), none)
	for index, number in numbers {
		wrapper := NumberObject.create(vm.realm(), number, parent)
		for receiver in [Value.from_f64(number), Value.from_object(wrapper.object)] {
			result := number_fixed_call(mut vm, receiver, [
				Value.from_i32(digits[index]),
			])!
			assert result.as_string().str() == texts[index], number.str()
		}
	}
	assert number_fixed_call(mut vm, Value.from_i32(1), [Value.from_i32(100)])!.as_string().str() ==
		'1.' + '0'.repeat(100)
	for digits_value in [js_undefined(), js_null(), Value.from_f64(math.nan())] {
		assert number_fixed_call(mut vm, Value.from_f64(1.1), [digits_value])!.as_string().str() == '1'
	}
	assert number_fixed_call(mut vm, Value.from_f64(30.521), [
		Value.from_f64(1.9),
	])!.as_string().str() == '30.5'
}

fn test_number_fixed_brand_and_digit_conversion_precede_range_and_nonfinite_fast_paths() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut poison := Object.create(vm.realm(), none)
	thrower := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		assert vm.argument(0).as_string().str() == 'number'
		return throw_completion(Value.from_i32(77))
	}, 1, PropertyName.from_str('thrower'), none)
	poison.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(thrower.object), 7)
	for receiver in [Value.from_bool(true), js_null(), Value.from_object(poison)] {
		if _ := number_fixed_call(mut vm, receiver, [Value.from_object(poison)]) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	for number in [math.nan(), math.inf(1), math.inf(-1), 0.0] {
		if _ := number_fixed_call(mut vm, Value.from_f64(number), [
			Value.from_object(poison),
		])
		{
			assert false
		} else {
			assert thrown_value(err).number == 77
		}
		for digits in [f64(-1), f64(101), math.inf(1), math.inf(-1)] {
			if _ := number_fixed_call(mut vm, Value.from_f64(number), [
				Value.from_f64(digits),
			])
			{
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .range_error
			}
		}
		if !Value.from_f64(number).is_finite_number() {
			assert number_fixed_call(mut vm, Value.from_f64(number), []Value{})!.as_string().str() == format_f64_value(number)
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

module libjs

import math

fn number_predicate_call(mut vm VM, index int, arguments []Value) !Value {
	behaviours := [NativeFunctionPointer(number_constructor_is_finite), number_constructor_is_integer,
		number_constructor_is_nan, number_constructor_is_safe_integer]
	function := NativeFunction.create_raw(mut vm, vm.realm(), vm.realm().function_prototype,
		behaviours[index], 1, PropertyName.from_str('predicate'), none)
	return call(mut vm, Value.from_object(function.object), js_null(), arguments)
}

fn test_number_predicates_retain_finite_integral_nan_and_safe_integer_boundaries() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for number in [0.0, -0.0, 1.0, -42.0, 2147483648.0, 9007199254740991.0, -9007199254740991.0] {
		value := Value.from_f64(number)
		assert value.is_finite_number() && value.is_integral_number() && !value.is_nan()
		for index in [0, 1, 3] {
			assert number_predicate_call(mut vm, index, [value])!.as_bool()
		}
		assert !number_predicate_call(mut vm, 2, [value])!.as_bool()
	}
	for number in [9007199254740992.0, -9007199254740992.0, 1e35, math.max_f64] {
		value := Value.from_f64(number)
		assert value.is_integral_number()
		assert number_predicate_call(mut vm, 1, [value])!.as_bool()
		assert !number_predicate_call(mut vm, 3, [value])!.as_bool()
	}
	for number in [1.23, math.f64_from_bits(1), -0.5] {
		value := Value.from_f64(number)
		assert value.is_finite_number() && !value.is_integral_number()
		assert number_predicate_call(mut vm, 0, [value])!.as_bool()
		assert !number_predicate_call(mut vm, 1, [value])!.as_bool()
		assert !number_predicate_call(mut vm, 3, [value])!.as_bool()
	}
	for number in [math.nan(), math.inf(1), math.inf(-1)] {
		value := Value.from_f64(number)
		assert !value.is_finite_number() && !value.is_integral_number()
		for index in [0, 1, 3] {
			assert !number_predicate_call(mut vm, index, [value])!.as_bool()
		}
		assert number_predicate_call(mut vm, 2, [value])!.as_bool() == math.is_nan(number)
	}
}

fn test_number_predicates_reject_other_tags_and_wrappers_without_coercing() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	coercion := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		assert false, 'Number static predicates must not coerce their argument'
		return Value.from_i32(42)
	}, 1, PropertyName.from_str('poison'), none)
	object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(coercion.object), 7)
	integer := string_to_bigint(utf16_string('42')) or { panic('fixture') }
	wrapper := NumberObject.create(vm.realm(), math.nan(), object)
	for value in [js_undefined(), js_null(), Value.from_bool(true),
		Value.from_string(vm.create_string_from_str('42')), Value.from_bigint(integer),
		Value.from_symbol(Symbol.create(none, .unique)), Value.from_object(object),
		Value.from_object(wrapper.object)] {
		assert !value.is_finite_number() && !value.is_integral_number() && !value.is_nan()
		for index in 0 .. 4 {
			assert !number_predicate_call(mut vm, index, [value])!.as_bool()
		}
	}
	for index in 0 .. 4 {
		assert !number_predicate_call(mut vm, index, []Value{})!.as_bool()
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

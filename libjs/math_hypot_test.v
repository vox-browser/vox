// SPDX-License-Identifier: BSD-2-Clause
// Regressions for Ladybird 85afacea93a8d132ae13f578a5e65816c00eb2b1.
module libjs

import math

fn call_hypot(mut vm VM, arguments []Value) !Value {
	function := vm.realm().math_object_record().get(mut vm, PropertyName.from_str('hypot'))!
	return call(mut vm, function, js_undefined(), arguments)
}

fn test_hypot_preserves_large_and_small_magnitudes_and_special_values() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for scale in [1e200, 1e-200] {
		for sign in [-1.0, 1.0] {
			result := call_hypot(mut vm, [Value.from_f64(sign * 3 * scale),
				Value.from_f64(4 * scale)])!.number
			assert math.abs(result / (5 * scale) - 1) < 1e-15
		}
	}
	for arguments in [ []Value{}, [Value.from_f64(-0.0)], [Value.from_f64(-0.0), Value.from_i32(0)] ] {
		result := call_hypot(mut vm, arguments)!.number
		assert result == 0 && !math.signbit(result)
	}
	assert math.is_nan(call_hypot(mut vm, [Value.from_f64(math.max_f64),
		Value.from_f64(math.max_f64), Value.from_f64(math.nan())])!.number)
	assert math.is_inf(call_hypot(mut vm, [Value.from_f64(math.nan()),
		Value.from_f64(math.inf(-1))])!.number, 1)
}

@[heap]
struct HypotConversionLog {
mut:
	indices []int
}

fn test_hypot_finishes_argument_conversion_before_special_value_checks() {
	mut vm := VM.create()
	context := create_simple_execution_context(mut vm)
	mut log := &HypotConversionLog{}
	mut arguments := []Value{}
	for index in 0 .. 3 {
		mut object := Object.create(vm.realm(), none)
		coercion := NativeFunction.create(mut vm, vm.realm(), none, fn [index, mut log] (mut vm VM) !Value {
			log.indices << index
			assert vm.argument(0).as_string().str() == 'number'
			if index == 2 { return throw_completion(Value.from_i32(99)) }
			return Value.from_f64(if index == 0 { math.inf(1) } else { math.nan() })
		}, 1, PropertyName.from_str('coercion'), none)
		object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(coercion.object), 7)
		arguments << Value.from_object(object)
	}
	if _ := call_hypot(mut vm, arguments) {
		assert false
	} else {
		assert thrown_value(err).as_i32() == 99
	}
	assert log.indices == [0, 1, 2]
	assert vm.running_execution_context() == context
	assert vm.interpreter_stack().depth() == 0
}

module libjs

import math

fn test_integer_length_and_index_conversions_normalize_zero_and_keep_infinities() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for number in [math.nan(), -0.0, 0.0, -0.5, 0.5] {
		integer := Value.from_f64(number).to_integer_or_infinity(mut vm)!
		assert integer == 0 && !math.signbit(integer)
		assert Value.from_f64(number).to_length(mut vm)! == 0
		assert Value.from_f64(number).to_index(mut vm)! == 0
	}
	assert Value.from_f64(-42.9).to_integer_or_infinity(mut vm)! == -42
	assert Value.from_f64(42.9).to_integer_or_infinity(mut vm)! == 42
	assert math.is_inf(to_integer_or_infinity(math.inf(1)), 1)
	assert math.is_inf(to_integer_or_infinity(math.inf(-1)), -1)
	assert Value.from_f64(math.inf(-1)).to_length(mut vm)! == 0
	assert Value.from_f64(math.inf(1)).to_length(mut vm)! == 9007199254740991
	assert js_undefined().to_index(mut vm)! == 0
	assert Value.from_f64(42.9).to_index(mut vm)! == 42
	assert Value.from_string(vm.create_string_from_str(' 42.9 ')).to_length(mut vm)! == 42
	for invalid in [-1.0, -42.9, math.inf(-1), math.inf(1), 9007199254740992.0] {
		if _ := Value.from_f64(invalid).to_index(mut vm) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
			assert thrown_value(err).as_object().error_message()? == ErrorType.invalid_index.message()
		}
	}
}

fn test_index_conversions_run_object_coercion_once_and_preserve_its_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	object.create_data_property(mut vm, PropertyName.from_str('calls'), Value.from_i32(0)) or {
		panic(err)
	}
	method := NativeFunction.create(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		assert vm.argument(0).as_string().str() == 'number'
		mut receiver := vm.this_value().as_object()
		calls := receiver.get(mut vm, PropertyName.from_str('calls'))!.number
		receiver.set(mut vm, PropertyName.from_str('calls'), Value.from_f64(calls + 1), .yes)!
		return Value.from_f64(42.9)
	}, 1, PropertyName.from_str('primitive'), none)
	object.create_data_property(mut vm,
		PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(method.object)) or { panic(err) }
	value := Value.from_object(object)
	assert value.to_integer_or_infinity(mut vm)! == 42
	assert value.to_length(mut vm)! == 42
	assert value.to_index(mut vm)! == 42
	assert object.get(mut vm, PropertyName.from_str('calls'))!.number == 3
	for primitive in [Value.from_symbol(Symbol.create_private()),
		Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') })] {
		if _ := primitive.to_length(mut vm) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	thrower := NativeFunction.create(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(17))
	}, 0, PropertyName.from_str('primitive'), none)
	object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(thrower.object), 7)
	if _ := value.to_index(mut vm) {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

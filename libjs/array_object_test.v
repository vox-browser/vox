module libjs

import math

fn test_array_creation_retains_sparse_length_and_exotic_identity() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	for length in [u64(0), 3, 0xffffffff] {
		array := ArrayObject.create(mut vm, vm.realm(), length, prototype)!
		mut object := array.object
		assert object.internal_get_prototype_of()? == prototype
		assert Value.from_object(object).is_array(mut vm)!
		assert object.properties.len == 0
		assert object.get(mut vm, PropertyName.from_str('length'))!.number == f64(length)
		descriptor := object.internal_get_own_property(PropertyName.from_str('length'))?
		assert descriptor.writable? && !descriptor.enumerable? && !descriptor.configurable?
		assert object.has_own_property(PropertyName.from_str('length'))
		assert object.has_property(PropertyName.from_str('length'))
		assert object.get_without_side_effects(PropertyName.from_str('length')).number == f64(length)
		assert !object.internal_delete(PropertyName.from_str('length'))
		assert object.own_property_keys().map(it.str()) == ['length']
	}
	if _ := ArrayObject.create(mut vm, vm.realm(), u64(0x100000000), prototype) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .range_error
	}
	for value in [js_undefined(), js_null(), Value.from_i32(1),
		Value.from_object(prototype)] {
		assert !value.is_array(mut vm)!
	}
	values := [Value.from_i32(17), js_undefined(), Value.from_i32(42)]
	array := ArrayObject.create_from(mut vm, vm.realm(), values, prototype)!
	assert create_list_from_array_like(mut vm, Value.from_object(array.object), unsafe { nil })! == values
	assert array.length == 3
	assert array.object.own_property_keys().map(it.str()) == ['0', '1', '2', 'length']
}

fn test_array_definitions_grow_length_only_for_successful_array_indices() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut prototype := Object.create(vm.realm(), none)
	array := ArrayObject.create(mut vm, vm.realm(), 0, prototype)!
	mut object := array.object
	assert object.create_data_property(mut vm, PropertyName.from_number(2), Value.from_i32(42))!
	assert array.length == 3
	assert !object.has_own_property(PropertyName.from_number(0))
	for name in ['01', '4294967295', '-1', 'later'] {
		assert object.create_data_property(mut vm, PropertyName.from_str(name), js_null())!
		assert array.length == 3
	}
	assert object.create_data_property(mut vm, PropertyName.from_symbol(Symbol.create(utf16_string('last'),
		.unique)), js_undefined())!
	assert object.own_property_keys().map(it.str()) == ['2', 'length', '01', '4294967295', '-1',
		'later', 'Symbol(last)']
	assert object.internal_delete(PropertyName.from_number(2))
	assert array.length == 3
	assert object.internal_define_own_property(mut vm, PropertyName.from_str('length'), PropertyDescriptor{
		writable: false
	})!
	assert !object.create_data_property(mut vm, PropertyName.from_number(3), js_null())!
	assert object.create_data_property(mut vm, PropertyName.from_number(1), js_null())!
	assert !object.internal_define_own_property(mut vm, PropertyName.from_str('length'), PropertyDescriptor{
		writable: true
	})!
	assert object.internal_define_own_property(mut vm, PropertyName.from_str('length'), PropertyDescriptor{
		value: Value.from_i32(3)
	})!
	assert !object.internal_define_own_property(mut vm, PropertyName.from_str('length'), PropertyDescriptor{
		value: Value.from_i32(4)
	})!
	assert object.internal_prevent_extensions()
	assert !object.create_data_property(mut vm, PropertyName.from_number(0), js_null())!
	assert object.internal_define_own_property(mut vm, PropertyName.from_number(1), PropertyDescriptor{
		value: Value.from_i32(17)
	})!
	assert array.length == 3
	// Inherited setters do not create an indexed entry or grow an array.
	prototype.define_native_accessor(mut vm, vm.realm(), PropertyName.from_number(13),
		unsafe { nil }, fn (mut vm VM) !Value {
		return js_undefined()
	}, attribute_configurable, vm.realm().function_prototype)
	object.set(mut vm, PropertyName.from_number(13), Value.from_i32(42), .yes)!
	assert array.length == 3 && !object.has_own_property(PropertyName.from_number(13))
	boundary := ArrayObject.create(mut vm, vm.realm(), 0, prototype)!
	mut boundary_object := boundary.object
	assert boundary_object.create_data_property(mut vm, PropertyName.from_number(0xfffffffe),
		js_null())!
	assert boundary.length == 0xffffffff && boundary_object.properties.len == 1
	assert boundary_object.internal_define_own_property(mut vm, PropertyName.from_str('length'), PropertyDescriptor{
		value: Value.from_i32(0)
	})!
	assert boundary.length == 0 && boundary_object.properties.len == 0
	getter := NativeFunction.create_raw(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return Value.from_i32(42)
	}, 0, PropertyName.from_str('get'), none)
	assert boundary_object.internal_define_own_property(mut vm, PropertyName.from_number(8), PropertyDescriptor{
		getter: Value.from_object(getter.object)
	})!
	assert boundary.length == 9
	assert boundary_object.get(mut vm, PropertyName.from_number(8))!.number == 42
}

fn test_array_shrink_failure_retains_the_highest_fixed_index_and_applies_readonly_length() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	array := ArrayObject.create(mut vm, vm.realm(), 10, prototype)!
	mut object := array.object
	for index in [u32(1), 4, 6, 8] {
		assert object.create_data_property(mut vm, PropertyName.from_number(index),
			Value.from_f64(f64(index)))!
	}
	for index in [u32(4), 6] {
		assert object.internal_define_own_property(mut vm, PropertyName.from_number(index), PropertyDescriptor{
			configurable: false
		})!
	}
	assert !object.internal_define_own_property(mut vm, PropertyName.from_str('length'), PropertyDescriptor{
		value:    Value.from_i32(2)
		writable: false
	})!
	assert array.length == 7 && !array.length_writable
	assert object.own_property_keys().map(it.str()) == ['1', '4', '6', 'length']
	assert !object.has_own_property(PropertyName.from_number(8))
	assert object.internal_get_own_property(PropertyName.from_str('length'))?.value?.number == 7
	assert !object.internal_define_own_property(mut vm, PropertyName.from_str('length'), PropertyDescriptor{
		value: Value.from_i32(10)
	})!
	// A nonextensible array may still grow its writable length, creating holes.
	other := ArrayObject.create(mut vm, vm.realm(), 0, prototype)!
	mut other_object := other.object
	assert other_object.internal_prevent_extensions()
	other_object.set(mut vm, PropertyName.from_str('length'), Value.from_i32(10), .yes)!
	assert other.length == 10 && other_object.properties.len == 0
}

fn test_array_length_validation_and_freezing_preserve_upstream_descriptor_rules() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	array := ArrayObject.create_from(mut vm, vm.realm(), [Value.from_i32(42)], prototype)!
	mut object := array.object
	length_key := PropertyName.from_str('length')
	for value in [Value.from_f64(0.5), Value.from_i32(-1), Value.from_f64(math.nan()),
		Value.from_f64(math.inf(1)), Value.from_f64(4294967296)] {
		if _ := object.internal_define_own_property(mut vm, length_key, PropertyDescriptor{
			value: value
		})
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
		}
		assert array.length == 1
	}
	for descriptor in [PropertyDescriptor{ configurable: true },
		PropertyDescriptor{ enumerable: true }, PropertyDescriptor{ getter: js_undefined() }] {
		assert !object.internal_define_own_property(mut vm, length_key, descriptor)!
	}
	assert object.set_integrity_level(mut vm, .frozen)!
	assert object.test_integrity_level(.frozen) && !array.length_writable
	if _ := object.set(mut vm, PropertyName.from_number(0), Value.from_i32(17), .yes) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	// A direct DefineOwnProperty still converts an invalid length before
	// rejecting a non-writable descriptor; ordinary Set rejects it earlier.
	if _ := object.internal_define_own_property(mut vm, length_key, PropertyDescriptor{
		value: Value.from_f64(1.5)
	})
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .range_error
	}
	zero := ArrayObject.create(mut vm, vm.realm(), 0, prototype)!
	mut zero_object := zero.object
	zero_object.set(mut vm, length_key, Value.from_f64(-0.0), .yes)!
	assert !math.signbit(zero_object.get(mut vm, length_key)!.number)
}

@[heap]
struct ArrayLengthCoercions {
mut:
	calls         int
	throw_on      int
	change_length bool
}

fn test_array_length_converts_twice_before_validation_and_propagates_each_abrupt_completion() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	mut array := ArrayObject.create(mut vm, vm.realm(), 2, prototype)!
	mut object := array.object
	mut state := &ArrayLengthCoercions{
		change_length: true
	}
	mut value_object := Object.create(vm.realm(), none)
	method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut state, mut array] (mut vm VM) !Value {
		state.calls++
		assert vm.argument(0).as_string().str() == 'number'
		if state.change_length && state.calls == 1 {
			mut object := array.object
			assert object.create_data_property(mut vm, PropertyName.from_number(6),
				Value.from_i32(17))!
		}
		if state.calls == state.throw_on { return throw_completion(Value.from_i32(17)) }
		return Value.from_i32(3)
	}, 1, PropertyName.from_str('coerce'), none)
	assert value_object.create_data_property(mut vm,
		PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(method.object))!
	value := Value.from_object(value_object)
	assert object.internal_define_own_property(mut vm, PropertyName.from_str('length'), PropertyDescriptor{
		value: value
	})!
	assert state.calls == 2 && array.length == 3
	assert !object.has_own_property(PropertyName.from_number(6))
	state.calls = 0
	state.change_length = false
	assert !object.internal_define_own_property(mut vm, PropertyName.from_str('length'), PropertyDescriptor{
		value:        value
		configurable: true
	})!
	assert state.calls == 2 && array.length == 3
	for throw_on in [1, 2] {
		state.calls = 0
		state.throw_on = throw_on
		if _ := object.internal_define_own_property(mut vm, PropertyName.from_str('length'), PropertyDescriptor{
			value: value
		})
		{
			assert false
		} else {
			assert thrown_value(err).number == 17
		}
		assert state.calls == throw_on && array.length == 3
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_compiled_array_property_updates_and_apply_use_exotic_dispatch() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	array := ArrayObject.create_from(mut vm, vm.realm(), [
		Value.from_string(vm.create_string_from_str('2a')),
		Value.from_i32(16),
	], prototype)!
	mut global := vm.get_global_object()
	assert global.create_data_property(mut vm, PropertyName.from_str('array'),
		Value.from_object(array.object))!
	for source, expected in {
		'parseInt.apply(null,array);':   '42'
		'array[4]=42; array.length;':    '5'
		'array.length=2; 4 in array;':   'false'
		'delete array.length;':          'false'
		'++array.length; array.length;': '3'
		'array.length=1; array[1];':     'undefined'
	} {
		mut script := Script.parse(source, vm.realm(), 'array.js', unsafe { nil })!
		assert vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })!.str() == expected
	}
	for source in ['array.length=1.5;', '"use strict"; delete array.length;'] {
		mut script := Script.parse(source, vm.realm(), 'array-error.js', unsafe { nil })!
		if _ := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 }) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? in [.type_error, .range_error]
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

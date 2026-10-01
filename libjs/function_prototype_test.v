module libjs

import math

fn invoke_function_method(mut vm VM, prototype &Object, name string, receiver Value, arguments []Value) !Value {
	method := prototype.get(mut vm, PropertyName.from_str(name))!
	return call(mut vm, method, receiver, arguments)
}

fn function_test_sum(mut vm VM) !Value {
	mut result := vm.this_value()
	for index in 0 .. vm.argument_count() {
		result = add(mut vm, result, vm.argument(index))!
	}
	return result
}

fn test_function_prototype_defines_methods_metadata_and_is_callable_without_running_context_changes() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	object_prototype := Object.create(vm.realm(), none)
	prototype := FunctionPrototype.create(mut vm, vm.realm(), object_prototype)
	assert prototype.object.internal_get_prototype_of()? == object_prototype
	assert prototype.object.own_property_keys().map(it.str()) == ['apply', 'bind', 'call', 'toString',
		'length', 'name', 'Symbol(Symbol.hasInstance)']
	assert prototype.object.get(mut vm, PropertyName.from_str('length'))!.number == 0
	assert prototype.object.get(mut vm, PropertyName.from_str('name'))!.as_string().is_empty()
	for name in ['apply', 'bind', 'call', 'toString'] {
		method := prototype.object.get(mut vm, PropertyName.from_str(name))!.as_object()
		assert method.internal_get_prototype_of()? == prototype.object
		assert method.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == name
		descriptor := prototype.object.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
	}
	has_instance :=
		prototype.object.internal_get_own_property(PropertyName.from_symbol(vm.well_known_symbol_has_instance()))?
	assert !has_instance.writable? && !has_instance.enumerable? && !has_instance.configurable?
	assert call(mut vm, Value.from_object(prototype.object), Value.from_i32(42), [
		js_null(),
	])!.is_undefined()
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_function_call_apply_and_bind_preserve_receiver_arguments_and_nested_binding() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	prototype := FunctionPrototype.create(mut vm, vm.realm(), none)
	target := NativeFunction.create(mut vm, vm.realm(), prototype.object, function_test_sum, 3,
		PropertyName.from_str('sum'), none)
	value := Value.from_object(target.object)
	assert invoke_function_method(mut vm, prototype.object, 'call', value, [
		Value.from_i32(1),
		Value.from_i32(20),
		Value.from_i32(21),
	])!.number == 42
	assert invoke_function_method(mut vm, prototype.object, 'call', value, []Value{})!.is_undefined()
	assert invoke_function_method(mut vm, prototype.object, 'apply', value, [
		Value.from_i32(42),
		js_null(),
	])!.number == 42
	mut arguments := Object.create(vm.realm(), none)
	arguments.create_data_property(PropertyName.from_str('length'), Value.from_i32(2))
	arguments.create_data_property(PropertyName.from_number(0), Value.from_i32(20))
	arguments.create_data_property(PropertyName.from_number(1), Value.from_i32(21))
	assert invoke_function_method(mut vm, prototype.object, 'apply', value, [
		Value.from_i32(1),
		Value.from_object(arguments),
	])!.number == 42
	bound := invoke_function_method(mut vm, prototype.object, 'bind', value, [
		Value.from_i32(1),
		Value.from_i32(20),
	])!
	assert bound.as_object().internal_get_prototype_of()? == prototype.object
	assert bound.as_object().get(mut vm, PropertyName.from_str('length'))!.number == 2
	assert bound.as_object().get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'bound sum'
	assert call(mut vm, bound, Value.from_i32(99), [Value.from_i32(21)])!.number == 42
	nested := invoke_function_method(mut vm, prototype.object, 'bind', bound, [
		Value.from_i32(99),
		Value.from_i32(21),
	])!
	assert nested.as_object().get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'bound bound sum'
	assert nested.as_object().get(mut vm, PropertyName.from_str('length'))!.number == 1
	assert call(mut vm, nested, js_null(), []Value{})!.number == 42
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_bind_uses_only_own_numeric_lengths_and_keeps_upstream_infinity_rules() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := FunctionPrototype.create(mut vm, vm.realm(), none)
	for length, expected in {
		4.9:          3.0
		-4.9:         0.0
		math.inf(1):  math.inf(1)
		math.inf(-1): 0.0
		math.nan():   0.0
	} {
		target := NativeFunction.create(mut vm, vm.realm(), prototype.object, function_test_sum, 0,
			PropertyName.from_str('sum'), none)
		mut object := target.object
		object.define_direct_property(PropertyName.from_str('length'), Value.from_f64(length), 7)
		bound := invoke_function_method(mut vm, prototype.object, 'bind',
			Value.from_object(object), [js_null(), Value.from_i32(1)])!
		assert bound.as_object().get(mut vm, PropertyName.from_str('length'))!.number == expected
	}
	target := NativeFunction.create(mut vm, vm.realm(), prototype.object, function_test_sum, 0,
		PropertyName.from_str('sum'), none)
	mut object := target.object
	object.define_direct_property(PropertyName.from_str('length'),
		Value.from_string(vm.create_string_from_str('42')), 7)
	object.define_direct_property(PropertyName.from_str('name'), Value.from_i32(42), 7)
	bound := invoke_function_method(mut vm, prototype.object, 'bind', Value.from_object(object),
		[]Value{})!
	assert bound.as_object().get(mut vm, PropertyName.from_str('length'))!.number == 0
	assert bound.as_object().get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'bound '
	assert object.internal_delete(PropertyName.from_str('length'))
	mut inherited := prototype.object
	inherited.define_direct_property(PropertyName.from_str('length'), Value.from_i32(42),
		attribute_configurable)
	without_own := invoke_function_method(mut vm, prototype.object, 'bind',
		Value.from_object(object), []Value{})!
	assert without_own.as_object().get(mut vm, PropertyName.from_str('length'))!.number == 0
}

@[heap]
struct BindReads {
mut:
	names []string
}

fn test_bind_length_and_name_accessors_run_in_order_and_preserve_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	prototype := FunctionPrototype.create(mut vm, vm.realm(), none)
	for failure in ['', 'length', 'name'] {
		mut reads := &BindReads{}
		target := NativeFunction.create(mut vm, vm.realm(), prototype.object, function_test_sum, 3,
			PropertyName.from_str('sum'), none)
		mut object := target.object
		for name in ['length', 'name'] {
			assert object.internal_delete(PropertyName.from_str(name))
			object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str(name), fn [mut reads, name, failure] (mut vm VM) !Value {
				reads.names << name
				if name == failure { return throw_completion(Value.from_i32(17)) }
				return if name == 'length' {
					Value.from_i32(3)
				} else {
					Value.from_string(vm.create_string_from_str('sum'))
				}
			}, unsafe { nil }, attribute_configurable, prototype.object)
		}
		if bound := invoke_function_method(mut vm, prototype.object, 'bind',
			Value.from_object(object), []Value{})
		{
			assert failure == ''
			assert bound.as_object().get(mut vm, PropertyName.from_str('length'))!.number == 3
		} else {
			assert failure != '' && thrown_value(err).number == 17
		}
		assert reads.names == if failure == 'length' {
			['length']
		} else {
			['length', 'name']
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_function_to_string_uses_source_text_or_initial_native_name_without_property_effects() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := FunctionPrototype.create(mut vm, vm.realm(), none)
	target := NativeFunction.create(mut vm, vm.realm(), prototype.object, function_test_sum, 0,
		PropertyName.from_str('original'), none)
	mut object := target.object
	object.define_direct_property(PropertyName.from_str('name'), Value.from_i32(42), 7)
	text := invoke_function_method(mut vm, prototype.object, 'toString', Value.from_object(object),
		[]Value{})!
	assert text.as_string().str() == 'function original() { [native code] }'
	bound := BoundFunction.create(vm.realm(), object, js_null(), []Value{})
	assert invoke_function_method(mut vm, prototype.object, 'toString',
		Value.from_object(bound.object), []Value{})!.as_string().str() == 'function () { [native code] }'
	object.function_source_text = utf16_string('function source() { return 42; }')
	assert invoke_function_method(mut vm, prototype.object, 'toString', Value.from_object(object),
		[]Value{})!.as_string().str() == 'function source() { return 42; }'
}

fn test_function_methods_reject_bad_receivers_and_apply_errors_before_calling_target() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	prototype := FunctionPrototype.create(mut vm, vm.realm(), none)
	for name in ['call', 'apply', 'bind', 'toString'] {
		if _ := invoke_function_method(mut vm, prototype.object, name, Value.from_i32(42),
			[]Value{})
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	target := NativeFunction.create(mut vm, vm.realm(), prototype.object, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(99))
	}, 0, PropertyName.from_str('target'), none)
	if _ := invoke_function_method(mut vm, prototype.object, 'apply',
		Value.from_object(target.object), [js_null(), Value.from_i32(42)])
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	mut array_like := Object.create(vm.realm(), none)
	array_like.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('length'), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(17))
	}, unsafe { nil }, 0, prototype.object)
	if _ := invoke_function_method(mut vm, prototype.object, 'apply',
		Value.from_object(target.object), [js_null(), Value.from_object(array_like)])
	{
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

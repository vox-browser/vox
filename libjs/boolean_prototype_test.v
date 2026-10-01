module libjs

fn boolean_test_method(mut vm VM, prototype &Object, name string, receiver Value) !Value {
	method := prototype.get(mut vm, PropertyName.from_str(name))!
	return call(mut vm, method, receiver, []Value{})
}

fn test_boolean_prototype_retains_false_data_and_native_method_descriptors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	object_prototype := Object.create(realm, none)
	prototype := BooleanPrototype.create(mut vm, realm, object_prototype)
	assert prototype.object.internal_get_prototype_of()? == object_prototype
	assert !prototype.object.boolean_object?.value
	assert !Value.from_object(prototype.object).is_function()
	assert prototype.object.own_property_keys().map(it.str()) == ['toString', 'valueOf']
	for name in ['toString', 'valueOf'] {
		descriptor := prototype.object.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.is_data_descriptor()
		assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
		method := descriptor.value?.as_object()
		assert method.internal_get_prototype_of()? == realm.function_prototype_record()
		assert method.get(mut vm, PropertyName.from_str('length'))!.number == 0
		assert method.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == name
	}
	assert !boolean_test_method(mut vm, prototype.object, 'valueOf', Value.from_object(prototype.object))!.as_bool()
	assert boolean_test_method(mut vm, prototype.object, 'toString', Value.from_object(prototype.object))!.as_string().str() == 'false'
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_boolean_methods_accept_primitives_and_boxed_values_and_preserve_conversion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	prototype := realm.boolean_prototype_record()
	for boolean in [false, true] {
		boxed := BooleanObject.create(realm, boolean)
		assert boxed.object.internal_get_prototype_of()? == prototype
		assert boxed.object.boolean_object? == boxed
		assert boxed.object.own_property_keys().len == 0
		for receiver in [Value.from_bool(boolean), Value.from_object(boxed.object)] {
			assert boolean_test_method(mut vm, prototype, 'valueOf', receiver)!.as_bool() == boolean
			assert boolean_test_method(mut vm, prototype, 'toString', receiver)!.as_string().str() == boolean.str()
		}
		value := Value.from_object(boxed.object)
		assert value.to_boolean()
		assert value.to_number(mut vm)!.number == if boolean { 1 } else { 0 }
		assert value.to_primitive_with_hint(mut vm, .number)! == Value.from_bool(boolean)
		text := value.to_primitive_string(mut vm)!
		assert text.str() == boolean.str()
	}
}

fn test_boolean_methods_reject_wrong_brands_without_coercing_and_restore_the_frame() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	prototype := realm.boolean_prototype_record()
	mut fake := Object.create(realm, prototype)
	fake.class_name = 'Boolean'
	coercion := NativeFunction.create(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(17))
	}, 1, PropertyName.from_str('coerce'), none)
	fake.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(coercion.object), 7)
	for receiver in [js_undefined(), js_null(), Value.from_i32(0),
		Value.from_string(vm.create_string_from_str('true')),
		Value.from_symbol(Symbol.create(none, .unique)), Value.from_object(fake)] {
		for name in ['toString', 'valueOf'] {
			if _ := boolean_test_method(mut vm, prototype, name, receiver) {
				assert false
			} else {
				error_value := thrown_value(err).as_object()
				assert error_value.error_kind()? == .type_error
				assert error_value.error_message()?.str() == 'Not an object of type Boolean'
			}
			assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
		}
	}
}

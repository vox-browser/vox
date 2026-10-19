module libjs

fn test_get_method_uses_primitive_receivers_and_distinguishes_nullish_and_noncallable_results() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	getter := fn [parent] (realm &Realm) &Object {
		return parent
	}
	prototypes := PrimitiveObjectPrototypes{
		number: getter
		bigint: getter
		string: getter
	}
	values := [Value.from_i32(42), Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') }),
		Value.from_string(vm.create_string_from_str('abc'))]
	for receiver in values {
		function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
			return js_undefined()
		}, 0, PropertyName.from_str('method'), none)
		bound := BoundFunction.create(vm.realm(), function.object, js_null(), []Value{})
		for result in [js_undefined(), js_null(), Value.from_i32(7),
			Value.from_object(function.object), Value.from_object(bound.object)] {
			parent.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('method'), fn [receiver, result] (mut vm VM) !Value {
				assert same_value(vm.this_value(), receiver)
				return result
			}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
			if actual := receiver.get_method_with_prototypes(mut vm,
				PropertyName.from_str('method'), prototypes)
			{
				assert result.is_nullish() || result.is_function()
				assert if result.is_nullish() {
					actual.is_undefined()
				} else {
					same_value(actual, result)
				}
			} else {
				assert result.number == 7
				assert thrown_value(err).as_object().error_message()?.str() == '7 is not a function'
			}
		}
	}
	parent.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('method'), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(99))
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	if _ := values[0].get_method_with_prototypes(mut vm, PropertyName.from_str('method'),
		prototypes)
	{
		assert false
	} else {
		assert thrown_value(err).number == 99
	}
	for nullish in [js_null(), js_undefined()] {
		if _ := nullish.get_method_with_prototypes(mut vm, PropertyName.from_str('method'),
			prototypes)
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'ToObject on null or undefined'
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_get_v_and_invoke_preserve_primitive_receiver_for_prototype_accessors_and_methods() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut parent := Object.create(realm, none)
	getter := fn [parent] (realm &Realm) &Object {
		return parent
	}
	prototypes := PrimitiveObjectPrototypes{
		number: getter
		bigint: getter
		string: getter
	}
	values := [Value.from_i32(42), Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') }),
		Value.from_string(vm.create_string_from_str('abc')), Value.from_bool(true),
		Value.from_symbol(vm.well_known_symbol_iterator())]
	for value in values {
		mut prototype := if value.is_boolean() {
			realm.boolean_prototype_record()
		} else if value.is_symbol() {
			realm.symbol_prototype_record()
		} else {
			parent
		}
		function := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [value] (mut vm VM) !Value {
			assert same_value(vm.this_value(), value)
			assert vm.argument_count() == 2 && vm.argument(0).number == 1
				&& vm.argument(1).number == 2
			return Value.from_i32(99)
		}, 2, PropertyName.from_str('test'), none)
		prototype.define_native_accessor(mut vm, realm, PropertyName.from_str('test'), fn [value, function] (mut vm VM) !Value {
			assert same_value(vm.this_value(), value)
			return Value.from_object(function.object)
		}, unsafe { nil }, attribute_configurable, realm.function_prototype)
		method := value.get_with_prototypes(mut vm, PropertyName.from_str('test'), prototypes)!
		assert voidptr(method.as_object()) == voidptr(function.object)
		result := value.invoke_with_prototypes(mut vm, PropertyName.from_str('test'), [
			Value.from_i32(1),
			Value.from_i32(2),
		], prototypes)!
		assert result.number == 99
	}
	length := values[2].get_with_prototypes(mut vm, PropertyName.from_str('length'), prototypes)!
	assert length.number == 3
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_get_v_and_invoke_object_identity_nullish_lookup_and_call_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [object] (mut vm VM) !Value {
		assert voidptr(vm.this_value().as_object()) == voidptr(object) && vm.argument_count() == 0
		return Value.from_i32(42)
	}, 0, PropertyName.from_str('test'), none)
	object.define_direct_property(PropertyName.from_str('test'),
		Value.from_object(function.object), 7)
	value := Value.from_object(object)
	result :=
		value.invoke_with_prototypes(mut vm, PropertyName.from_str('test'), []Value{}, PrimitiveObjectPrototypes{})!
	assert result.number == 42
	for nullish in [js_null(), js_undefined()] {
		if _ := nullish.get_with_prototypes(mut vm, PropertyName.from_str('x'), PrimitiveObjectPrototypes{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'ToObject on null or undefined'
		}
	}
	for property in [js_undefined(), js_null(), Value.from_i32(7)] {
		object.define_direct_property(PropertyName.from_str('bad'), property, 7)
		if _ := value.invoke_with_prototypes(mut vm, PropertyName.from_str('bad'), []Value{}, PrimitiveObjectPrototypes{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('throw'), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(99))
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	if _ := value.invoke_with_prototypes(mut vm, PropertyName.from_str('throw'), []Value{}, PrimitiveObjectPrototypes{}) {
		assert false
	} else {
		assert thrown_value(err).number == 99
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

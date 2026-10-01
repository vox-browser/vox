module libjs

fn test_throw_type_error_function_is_nonextensible_with_fixed_empty_metadata() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	prototype := FunctionPrototype.create(mut vm, vm.realm(), none)
	thrower := create_throw_type_error_function(mut vm, vm.realm(), prototype.object)
	assert !thrower.internal_is_extensible()
	assert thrower.internal_get_prototype_of()? == prototype.object
	for name in ['length', 'name'] {
		descriptor := thrower.internal_get_own_property(PropertyName.from_str(name))?
		assert !descriptor.writable? && !descriptor.enumerable? && !descriptor.configurable?
	}
	assert thrower.get(mut vm, PropertyName.from_str('length'))!.number == 0
	assert thrower.get(mut vm, PropertyName.from_str('name'))!.as_string().is_empty()
	if _ := call(mut vm, Value.from_object(thrower), js_null(), [
		Value.from_i32(42)])
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
		assert thrown_value(err).as_object().error_message()? == ErrorType.restricted_function_properties_access.message()
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_restricted_function_properties_share_thrower_getters_and_setters_and_remain_configurable() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	prototype := FunctionPrototype.create(mut vm, vm.realm(), none)
	thrower := create_throw_type_error_function(mut vm, vm.realm(), prototype.object)
	mut object := prototype.object
	object.add_restricted_function_properties(thrower)
	target := NativeFunction.create(mut vm, vm.realm(), object, fn (mut vm VM) !Value {
		return js_undefined()
	}, 0, PropertyName.from_str('target'), none)
	mut function := target.object
	for name in ['caller', 'arguments'] {
		key := PropertyName.from_str(name)
		descriptor := object.internal_get_own_property(key)?
		assert descriptor.is_accessor_descriptor() && !descriptor.enumerable?
			&& descriptor.configurable?
		assert descriptor.getter?.as_object() == thrower
			&& descriptor.setter?.as_object() == thrower
		if _ := function.get(mut vm, key) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
		if _ := function.set(mut vm, key, Value.from_i32(42), .no) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
		assert !function.has_own_property(key)
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
		assert object.internal_delete(key)
		assert function.get(mut vm, key)!.is_undefined()
	}
}

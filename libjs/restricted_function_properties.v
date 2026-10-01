module libjs

// Runtime/Intrinsics.cpp::%ThrowTypeError% and AddRestrictedFunctionProperties.
pub fn create_throw_type_error_function(mut vm VM, realm &Realm, function_prototype &Object) &Object {
	function := NativeFunction.create_raw(mut vm, realm, function_prototype, fn (mut vm VM) !Value {
		return vm.throw_error_type(.type_error, .restricted_function_properties_access)
	}, 0, PropertyName.from_str(''), none)
	mut object := function.object
	object.define_direct_property(PropertyName.from_str('length'), Value.from_i32(0), 0)
	object.define_direct_property(PropertyName.from_str('name'),
		Value.from_string(vm.empty_string()), 0)
	assert object.internal_prevent_extensions()
	return object
}

pub fn (mut object Object) add_restricted_function_properties(thrower &Object) {
	assert thrower.callable != none
	for name in ['caller', 'arguments'] {
		object.define_direct_accessor(PropertyName.from_str(name), thrower, thrower,
			attribute_configurable)
	}
}

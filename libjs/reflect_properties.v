module libjs

// Runtime/ReflectObject.cpp property native bodies. Unlike Object constructor
// operations, Reflect requires an object target without primitive boxing.

pub fn reflect_define_property(mut vm VM) !Value {
	target := vm.argument(0)
	property_key := vm.argument(1)
	attributes := vm.argument(2)
	if !target.is_object() { return vm.throw_error_type(.type_error, .not_an_object, target.str()) }
	key := property_key.to_property_key(mut vm)!
	descriptor := to_property_descriptor(mut vm, attributes)!
	mut object := target.as_object()
	return Value.from_bool(object.internal_define_own_property(mut vm, key, descriptor)!)
}

pub fn reflect_delete_property(mut vm VM) !Value {
	target := vm.argument(0)
	property_key := vm.argument(1)
	if !target.is_object() { return vm.throw_error_type(.type_error, .not_an_object, target.str()) }
	key := property_key.to_property_key(mut vm)!
	mut object := target.as_object()
	return Value.from_bool(object.internal_delete(key))
}

pub fn reflect_get(mut vm VM) !Value {
	target := vm.argument(0)
	property_key := vm.argument(1)
	mut receiver := vm.argument(2)
	if !target.is_object() { return vm.throw_error_type(.type_error, .not_an_object, target.str()) }
	key := property_key.to_property_key(mut vm)!
	if vm.argument_count() < 3 { receiver = target }
	return target.as_object().internal_get(mut vm, key, receiver)
}

pub fn reflect_get_own_property_descriptor(mut vm VM, object_prototype ?&Object) !Value {
	target := vm.argument(0)
	property_key := vm.argument(1)
	if !target.is_object() { return vm.throw_error_type(.type_error, .not_an_object, target.str()) }
	key := property_key.to_property_key(mut vm)!
	descriptor := target.as_object().internal_get_own_property(key)
	return from_property_descriptor(mut vm, descriptor, object_prototype)
}

pub fn reflect_has(mut vm VM) !Value {
	target := vm.argument(0)
	property_key := vm.argument(1)
	if !target.is_object() { return vm.throw_error_type(.type_error, .not_an_object, target.str()) }
	key := property_key.to_property_key(mut vm)!
	return Value.from_bool(target.as_object().internal_has_property(key))
}

pub fn reflect_set(mut vm VM) !Value {
	target := vm.argument(0)
	property_key := vm.argument(1)
	value := vm.argument(2)
	mut receiver := vm.argument(3)
	if !target.is_object() { return vm.throw_error_type(.type_error, .not_an_object, target.str()) }
	key := property_key.to_property_key(mut vm)!
	if vm.argument_count() < 4 { receiver = target }
	mut object := target.as_object()
	return Value.from_bool(object.internal_set(mut vm, key, value, receiver)!)
}

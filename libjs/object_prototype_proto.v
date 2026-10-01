module libjs

// ObjectPrototype.cpp::proto_getter, 20.1.3.8.1 get Object.prototype.__proto__.
pub fn object_prototype_proto_getter(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	object := vm.this_value().to_object_with_prototypes(mut vm, prototypes)!
	prototype := object.internal_get_prototype_of() or { return js_null() }
	return Value.from_object(prototype)
}

// ObjectPrototype.cpp::proto_setter, 20.1.3.8.2 set Object.prototype.__proto__.
pub fn object_prototype_proto_setter(mut vm VM) !Value {
	prototype := vm.argument(0)
	value := require_object_coercible(mut vm, vm.this_value())!
	if !prototype.is_object() && !prototype.is_null() { return js_undefined() }
	if !value.is_object() { return js_undefined() }
	mut object := value.as_object()
	mut proposed := ?&Object(none)
	if prototype.is_object() { proposed = prototype.as_object() }
	if !object.internal_set_prototype_of(proposed) {
		return vm.throw_error_type(.type_error, .object_set_prototype_of_returned_false)
	}
	return js_undefined()
}

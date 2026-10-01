module libjs

// ArrayPrototype.cpp::to_string, shared verbatim by TypedArrayPrototype's
// toString property. The retained Object intrinsic function is an explicit
// dependency; a mutable Object.prototype.toString property is not consulted.
pub fn array_prototype_to_string(mut vm VM, prototypes PrimitiveObjectPrototypes, object_to_string_getter IntrinsicPrototypeGetter) !Value {
	realm := vm.realm()
	array := vm.this_value().to_object_with_prototypes(mut vm, prototypes)!
	mut function := array.get(mut vm, PropertyName.from_str('join'))!
	if !function.is_function() {
		function = Value.from_object(object_to_string_getter(realm))
	}
	return call(mut vm, function, Value.from_object(array), []Value{})
}

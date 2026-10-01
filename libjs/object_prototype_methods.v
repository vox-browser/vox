module libjs

// Runtime/ObjectPrototype.cpp native bodies. Number/BigInt/String prototype
// dependencies stay explicit until the complete realm intrinsic graph exists.
// The toString body and ObjectPrototype record are separate pending slices.

// 20.1.3.2 Object.prototype.hasOwnProperty ( V ).
pub fn object_prototype_has_own_property(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	key := vm.argument(0).to_property_key(mut vm)!
	object := vm.this_value().to_object_with_prototypes(mut vm, prototypes)!
	return Value.from_bool(object.has_own_property(key))
}

// 20.1.3.3 Object.prototype.isPrototypeOf ( V ).
pub fn object_prototype_is_prototype_of(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	argument := vm.argument(0)
	if !argument.is_object() { return Value.from_bool(false) }
	mut object := argument.as_object()
	this_object := vm.this_value().to_object_with_prototypes(mut vm, prototypes)!
	for {
		object = object.internal_get_prototype_of() or { return Value.from_bool(false) }
		if same_value(Value.from_object(this_object), Value.from_object(object)) {
			return Value.from_bool(true)
		}
	}
	return Value.from_bool(false)
}

// 20.1.3.4 Object.prototype.propertyIsEnumerable ( V ).
pub fn object_prototype_property_is_enumerable(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	key := vm.argument(0).to_property_key(mut vm)!
	object := vm.this_value().to_object_with_prototypes(mut vm, prototypes)!
	descriptor := object.internal_get_own_property(key) or { return Value.from_bool(false) }
	return Value.from_bool(descriptor.enumerable or { false })
}

// 20.1.3.5 Object.prototype.toLocaleString ( [ reserved1 [ , reserved2 ] ] ).
pub fn object_prototype_to_locale_string(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	return vm.this_value().invoke_with_prototypes(mut vm, PropertyName.from_str('toString'),
		[]Value{}, prototypes)
}

// 20.1.3.7 Object.prototype.valueOf ( ).
pub fn object_prototype_value_of(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	return Value.from_object(vm.this_value().to_object_with_prototypes(mut vm, prototypes)!)
}

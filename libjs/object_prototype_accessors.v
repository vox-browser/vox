module libjs

// ObjectPrototype.cpp Annex B __defineGetter__/__defineSetter__ and
// __lookupGetter__/__lookupSetter__. The descriptor lookup never invokes the
// accessor it returns, and a data descriptor stops the prototype-chain walk.
pub fn object_prototype_define_getter(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	property := vm.argument(0)
	getter := vm.argument(1)
	mut object := vm.this_value().to_object_with_prototypes(mut vm, prototypes)!
	if !getter.is_function() {
		return vm.throw_error_type(.type_error, .not_a_function, getter.str())
	}
	descriptor := PropertyDescriptor{
		getter:       getter
		enumerable:   true
		configurable: true
	}
	key := property.to_property_key(mut vm)!
	object.define_property_or_throw(mut vm, key, descriptor)!
	return js_undefined()
}

pub fn object_prototype_define_setter(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	property := vm.argument(0)
	setter := vm.argument(1)
	mut object := vm.this_value().to_object_with_prototypes(mut vm, prototypes)!
	if !setter.is_function() {
		return vm.throw_error_type(.type_error, .not_a_function, setter.str())
	}
	descriptor := PropertyDescriptor{
		setter:       setter
		enumerable:   true
		configurable: true
	}
	key := property.to_property_key(mut vm)!
	object.define_property_or_throw(mut vm, key, descriptor)!
	return js_undefined()
}

pub fn object_prototype_lookup_getter(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	property := vm.argument(0)
	mut object := vm.this_value().to_object_with_prototypes(mut vm, prototypes)!
	key := property.to_property_key(mut vm)!
	for {
		if descriptor := object.internal_get_own_property(key) {
			if descriptor.is_accessor_descriptor() { return descriptor.getter or { js_undefined() } }
			return js_undefined()
		}
		object = object.internal_get_prototype_of() or { return js_undefined() }
	}
	return js_undefined()
}

pub fn object_prototype_lookup_setter(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	property := vm.argument(0)
	mut object := vm.this_value().to_object_with_prototypes(mut vm, prototypes)!
	key := property.to_property_key(mut vm)!
	for {
		if descriptor := object.internal_get_own_property(key) {
			if descriptor.is_accessor_descriptor() { return descriptor.setter or { js_undefined() } }
			return js_undefined()
		}
		object = object.internal_get_prototype_of() or { return js_undefined() }
	}
	return js_undefined()
}

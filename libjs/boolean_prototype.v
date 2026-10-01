module libjs

// Runtime/BooleanPrototype.{h,cpp}. %Object.prototype% is supplied explicitly
// while the rest of the intrinsic graph is translated.
@[heap]
pub struct BooleanPrototype {
pub:
	object &Object
}

pub fn BooleanPrototype.create(mut vm VM, realm &Realm, object_prototype ?&Object) &BooleanPrototype {
	boolean := BooleanObject.create_with_prototype(realm, false, object_prototype)
	mut object := boolean.object
	for name, behaviour in {
		'toString': NativeFunctionPointer(boolean_prototype_to_string)
		'valueOf': NativeFunctionPointer(boolean_prototype_value_of)
	} {
		function := NativeFunction.create_raw(mut vm, realm, realm.function_prototype,
			behaviour, 0, PropertyName.from_str(name), none)
		object.define_direct_property(PropertyName.from_str(name), Value.from_object(function.object),
			attribute_writable | attribute_configurable)
	}
	return &BooleanPrototype{object: object}
}

// thisBooleanValue is a brand check; it never invokes conversion hooks.
fn this_boolean_value(mut vm VM, value Value) !bool {
	if value.is_boolean() { return value.as_bool() }
	if value.is_object() {
		if boolean := value.as_object().boolean_object { return boolean.value }
	}
	return vm.throw_error_type(.type_error, .not_an_object_of_type, 'Boolean')
}

fn boolean_prototype_to_string(mut vm VM) !Value {
	boolean := this_boolean_value(mut vm, vm.this_value())!
	return Value.from_string(vm.create_string_from_str(if boolean { 'true' } else { 'false' }))
}

fn boolean_prototype_value_of(mut vm VM) !Value {
	return Value.from_bool(this_boolean_value(mut vm, vm.this_value())!)
}

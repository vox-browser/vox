module libjs

// Runtime/ReflectObject.cpp prototype/extensibility native bodies.
pub fn reflect_get_prototype_of(mut vm VM) !Value {
	target := vm.argument(0)
	if !target.is_object() { return vm.throw_error_type(.type_error, .not_an_object, target.str()) }
	prototype := target.as_object().internal_get_prototype_of() or { return js_null() }
	return Value.from_object(prototype)
}

pub fn reflect_is_extensible(mut vm VM) !Value {
	target := vm.argument(0)
	if !target.is_object() { return vm.throw_error_type(.type_error, .not_an_object, target.str()) }
	return Value.from_bool(target.as_object().internal_is_extensible())
}

pub fn reflect_prevent_extensions(mut vm VM) !Value {
	target := vm.argument(0)
	if !target.is_object() { return vm.throw_error_type(.type_error, .not_an_object, target.str()) }
	mut object := target.as_object()
	return Value.from_bool(object.internal_prevent_extensions())
}

pub fn reflect_set_prototype_of(mut vm VM) !Value {
	target := vm.argument(0)
	prototype := vm.argument(1)
	if !target.is_object() { return vm.throw_error_type(.type_error, .not_an_object, target.str()) }
	if !prototype.is_object() && !prototype.is_null() {
		return vm.throw_error_type(.type_error, .object_prototype_wrong_type)
	}
	mut proposed := ?&Object(none)
	if prototype.is_object() { proposed = prototype.as_object() }
	mut object := target.as_object()
	return Value.from_bool(object.internal_set_prototype_of(proposed))
}

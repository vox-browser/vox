module libjs

// Runtime/PropertyKey.h::to_value. Numeric keys become cached decimal strings;
// symbol identity and every string's UTF-16 code units are retained.
pub fn (key PropertyName) to_value(mut vm VM) Value {
	if key.is_string() { return Value.from_string(vm.create_string(key.as_string())) }
	if key.is_symbol() {
		assert !key.as_symbol().is_private()
		return Value.from_symbol(key.as_symbol())
	}
	return Value.from_string(vm.create_string_from_unsigned_integer(u64(key.number)))
}

// Runtime/ReflectObject.cpp::own_keys. The pending Array intrinsic is supplied
// explicitly; ArrayCreate/CreateArrayFromList produce a real array exotic record.
pub fn reflect_own_keys(mut vm VM, array_prototype &Object) !Value {
	target := vm.argument(0)
	if !target.is_object() { return vm.throw_error_type(.type_error, .not_an_object, target.str()) }
	keys := target.as_object().own_property_keys()
	mut values := []Value{cap: keys.len}
	for key in keys {
		values << key.to_value(mut vm)
	}
	return Value.from_object(ArrayObject.create_from(mut vm, vm.realm(), values, array_prototype)!.object)
}

module libjs

// TypedArrayPrototype.cpp::callback_from_args. Preserve the distinction
// between an absent callback and a present non-callable value.
fn typed_array_callback_from_args(mut vm VM, prototype_name string) !&Object {
	if vm.argument_count() < 1 {
		return vm.throw_error_type(.type_error, .typed_array_prototype_one_arg, prototype_name)
	}
	callback := vm.argument(0)
	if !callback.is_function() {
		return vm.throw_error_type(.type_error, .not_a_function, callback.str())
	}
	return callback.as_object()
}

// Native bodies retain the initial length witness and read each element live.
pub fn typed_array_prototype_every(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	this_arg := vm.argument(1)
	array := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, array.object, .seq_cst)!
	length := typed_array_length(record)
	callback := typed_array_callback_from_args(mut vm, 'every')!
	for k := u32(0); k < length; k++ {
		value := array.object.get(mut vm, PropertyName.from_number(k))!
		result := call(mut vm, Value.from_object(callback), this_arg, [value, Value.from_f64(f64(k)),
			Value.from_object(array.object)])!
		if !result.to_boolean() { return Value.from_bool(false) }
	}
	return Value.from_bool(true)
}

pub fn typed_array_prototype_some(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	this_arg := vm.argument(1)
	array := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, array.object, .seq_cst)!
	length := typed_array_length(record)
	callback := typed_array_callback_from_args(mut vm, 'some')!
	for k := u32(0); k < length; k++ {
		value := array.object.get(mut vm, PropertyName.from_number(k))!
		result := call(mut vm, Value.from_object(callback), this_arg, [value, Value.from_f64(f64(k)),
			Value.from_object(array.object)])!
		if result.to_boolean() { return Value.from_bool(true) }
	}
	return Value.from_bool(false)
}

pub fn typed_array_prototype_for_each(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	this_arg := vm.argument(1)
	array := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, array.object, .seq_cst)!
	length := typed_array_length(record)
	callback := typed_array_callback_from_args(mut vm, 'forEach')!
	for k := u32(0); k < length; k++ {
		value := array.object.get(mut vm, PropertyName.from_number(k))!
		call(mut vm, Value.from_object(callback), this_arg, [value, Value.from_f64(f64(k)),
			Value.from_object(array.object)])!
	}
	return js_undefined()
}

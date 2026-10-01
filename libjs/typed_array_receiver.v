module libjs

// TypedArray.cpp::typed_array_from. ToObject precedes the brand check; nullish
// inputs retain its own TypeError rather than the TypedArray brand error.
pub fn typed_array_from(mut vm VM, value Value, prototypes PrimitiveObjectPrototypes) !&TypedArray {
	object := value.to_object_with_prototypes(mut vm, prototypes)!
	return object.typed_array or {
		return vm.throw_error_type(.type_error, .not_an_object_of_type, 'TypedArray')
	}
}

// TypedArrayPrototype.cpp::typed_array_from_this.
fn typed_array_from_this(mut vm VM, prototypes PrimitiveObjectPrototypes) !&TypedArray {
	return typed_array_from(mut vm, vm.this_value(), prototypes)
}

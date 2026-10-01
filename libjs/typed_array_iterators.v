module libjs

// TypedArrayPrototype.cpp::entries/keys/values. The ArrayIterator intrinsic
// dependency stays explicit until the complete TypedArray graph is installed.
pub fn typed_array_prototype_entries(mut vm VM, prototypes PrimitiveObjectPrototypes, iterator_prototype &Object) !Value {
	realm := vm.realm()
	array := typed_array_from_this(mut vm, prototypes)!
	validate_typed_array(mut vm, array.object, .seq_cst)!
	iterator := ArrayIterator.create(realm, Value.from_object(array.object), .key_and_value,
		iterator_prototype)
	return Value.from_object(iterator.object)
}

pub fn typed_array_prototype_keys(mut vm VM, prototypes PrimitiveObjectPrototypes, iterator_prototype &Object) !Value {
	realm := vm.realm()
	array := typed_array_from_this(mut vm, prototypes)!
	validate_typed_array(mut vm, array.object, .seq_cst)!
	iterator := ArrayIterator.create(realm, Value.from_object(array.object), .key,
		iterator_prototype)
	return Value.from_object(iterator.object)
}

pub fn typed_array_prototype_values(mut vm VM, prototypes PrimitiveObjectPrototypes, iterator_prototype &Object) !Value {
	realm := vm.realm()
	array := typed_array_from_this(mut vm, prototypes)!
	validate_typed_array(mut vm, array.object, .seq_cst)!
	iterator := ArrayIterator.create(realm, Value.from_object(array.object), .value,
		iterator_prototype)
	return Value.from_object(iterator.object)
}

module libjs

// TypedArrayPrototype.cpp::Direction, FoundValue and FindViaPredicate.
enum TypedArrayFindDirection {
	ascending
	descending
}

struct TypedArrayFoundValue {
	index ?u32
	value Value
}

fn (found TypedArrayFoundValue) index_to_value() Value {
	index := found.index or { return Value.from_i32(-1) }
	return Value.from_f64(f64(index))
}

fn typed_array_find_via_predicate(mut vm VM, array &TypedArray, length u32, direction TypedArrayFindDirection, this_arg Value, prototype_name string) !TypedArrayFoundValue {
	predicate := typed_array_callback_from_args(mut vm, prototype_name)!
	// Visit the snapshot range lazily: an early match must not allocate an
	// index list proportional to the view's length.
	for visited := u32(0); visited < length; visited++ {
		k := if direction == .ascending { visited } else { length - 1 - visited }
		value := array.object.get(mut vm, PropertyName.from_number(k))!
		result := call(mut vm, Value.from_object(predicate), this_arg, [value, Value.from_f64(f64(k)),
			Value.from_object(array.object)])!
		if result.to_boolean() { return TypedArrayFoundValue{
				index: k
				value: value
			} }
	}
	return TypedArrayFoundValue{
		index: none
		value: js_undefined()
	}
}

pub fn typed_array_prototype_find(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	this_arg := vm.argument(1)
	array := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, array.object, .seq_cst)!
	length := typed_array_length(record)
	found := typed_array_find_via_predicate(mut vm, array, length, .ascending, this_arg, 'find')!
	return found.value
}

pub fn typed_array_prototype_find_index(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	this_arg := vm.argument(1)
	array := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, array.object, .seq_cst)!
	length := typed_array_length(record)
	found := typed_array_find_via_predicate(mut vm, array, length, .ascending, this_arg,
		'findIndex')!
	return found.index_to_value()
}

pub fn typed_array_prototype_find_last(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	this_arg := vm.argument(1)
	array := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, array.object, .seq_cst)!
	length := typed_array_length(record)
	found := typed_array_find_via_predicate(mut vm, array, length, .descending, this_arg,
		'findLast')!
	return found.value
}

pub fn typed_array_prototype_find_last_index(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	this_arg := vm.argument(1)
	array := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, array.object, .seq_cst)!
	length := typed_array_length(record)
	found := typed_array_find_via_predicate(mut vm, array, length, .descending, this_arg,
		'findLastIndex')!
	return found.index_to_value()
}

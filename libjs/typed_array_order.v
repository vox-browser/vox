module libjs

// TypedArrayPrototype.cpp::reverse. Reads/writes use numeric elements, matching
// the active source body rather than treating reversal as a raw byte operation.
pub fn typed_array_prototype_reverse(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	array := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, array.object, .seq_cst)!
	length := typed_array_length(record)
	middle := length / 2
	mut object := array.object
	for lower := u32(0); lower != middle; lower++ {
		upper := length - lower - 1
		low_key := PropertyName.from_number(lower)
		high_key := PropertyName.from_number(upper)
		low := object.get(mut vm, low_key)!
		high := object.get(mut vm, high_key)!
		object.set(mut vm, low_key, high, .yes)!
		object.set(mut vm, high_key, low, .yes)!
	}
	return Value.from_object(object)
}

// TypedArrayPrototype.cpp::sort. Validate callback before receiver, gather all
// elements before comparing, then write the sorted snapshot into live indices.
pub fn typed_array_prototype_sort(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	function := vm.argument(0)
	if !function.is_undefined() && !function.is_function() {
		return vm.throw_error_type(.type_error, .not_a_function, function.str())
	}
	array := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, array.object, .seq_cst)!
	length := typed_array_length(record)
	compare_function := if function.is_undefined() { ?&Object(none) } else { function.as_object() }
	compare := fn [compare_function] (mut vm VM, x Value, y Value) !f64 {
		return compare_typed_array_elements(mut vm, x, y, compare_function)
	}
	sorted := sort_indexed_properties(mut vm, array.object, u64(length), compare, .read_through_holes)!
	mut object := array.object
	for index in 0 .. length {
		object.set(mut vm, PropertyName.from_number(index), sorted[int(index)], .yes)!
	}
	return Value.from_object(object)
}

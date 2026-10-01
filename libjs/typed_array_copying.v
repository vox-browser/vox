module libjs

// TypedArrayPrototype.cpp::to_reversed/to_sorted/with. Creation uses the
// current realm's same-type intrinsic dependency, without a species lookup.
pub fn typed_array_prototype_to_reversed(mut vm VM, prototypes PrimitiveObjectPrototypes, constructor_getter TypedArrayIntrinsicConstructorGetter) !Value {
	source := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, source.object, .seq_cst)!
	length := typed_array_length(record)
	array := typed_array_create_same_type(mut vm, source, [
		Value.from_f64(f64(length)),
	], constructor_getter)!
	mut object := array.object
	for k := u32(0); k < length; k++ {
		value := source.object.get(mut vm, PropertyName.from_number(length - k - 1))!
		object.set(mut vm, PropertyName.from_number(k), value, .yes)!
	}
	return Value.from_object(object)
}

pub fn typed_array_prototype_to_sorted(mut vm VM, prototypes PrimitiveObjectPrototypes, constructor_getter TypedArrayIntrinsicConstructorGetter) !Value {
	function := vm.argument(0)
	if !function.is_undefined() && !function.is_function() {
		return vm.throw_error_type(.type_error, .not_a_function, function.str())
	}
	source := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, source.object, .seq_cst)!
	length := typed_array_length(record)
	array := typed_array_create_same_type(mut vm, source, [
		Value.from_f64(f64(length)),
	], constructor_getter)!
	compare_function := if function.is_undefined() { ?&Object(none) } else { function.as_object() }
	compare := fn [compare_function] (mut vm VM, x Value, y Value) !f64 {
		return compare_typed_array_elements(mut vm, x, y, compare_function)
	}
	sorted := sort_indexed_properties(mut vm, source.object, u64(length), compare,
		.read_through_holes)!
	mut object := array.object
	for k := u32(0); k < length; k++ {
		object.set(mut vm, PropertyName.from_number(k), sorted[int(k)], .yes)!
	}
	return Value.from_object(object)
}

pub fn typed_array_prototype_with(mut vm VM, prototypes PrimitiveObjectPrototypes, constructor_getter TypedArrayIntrinsicConstructorGetter) !Value {
	index := vm.argument(0)
	value := vm.argument(1)
	source := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, source.object, .seq_cst)!
	length := typed_array_length(record)
	relative := index.to_integer_or_infinity(mut vm)!
	actual := if relative >= 0 { relative } else { f64(length) + relative }
	numeric := if source.content_type() == .bigint {
		Value.from_bigint(value.to_bigint(mut vm)!)
	} else {
		value.to_number(mut vm)!
	}
	canonical := CanonicalIndex.from_double(mut vm, .index, actual)!
	if !is_valid_integer_index(source, canonical) {
		return vm.throw_error_type(.range_error, .typed_array_invalid_integer_index,
			format_f64_value(actual))
	}
	array := typed_array_create_same_type(mut vm, source, [
		Value.from_f64(f64(length)),
	], constructor_getter)!
	mut object := array.object
	for k := u32(0); k < length; k++ {
		value_from := if f64(k) == actual {
			numeric
		} else {
			source.object.get(mut vm, PropertyName.from_number(k))!
		}
		object.set(mut vm, PropertyName.from_number(k), value_from, .yes)!
	}
	return Value.from_object(object)
}

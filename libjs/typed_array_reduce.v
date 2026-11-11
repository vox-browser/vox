module libjs

// TypedArrayPrototype.cpp::reduce/reduce_right. Argument presence selects the
// initial accumulator; an explicitly supplied undefined is an initial value.
pub fn typed_array_prototype_reduce(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	initial_value := vm.argument(1)
	array := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, array.object, .seq_cst)!
	length := typed_array_length(record)
	callback := typed_array_callback_from_args(mut vm, 'reduce')!
	if length == 0 && vm.argument_count() <= 1 {
		return vm.throw_error_type(.type_error, .reduce_no_initial)
	}
	mut k := u32(0)
	mut accumulator := js_undefined()
	if vm.argument_count() > 1 {
		accumulator = initial_value
	} else {
		accumulator = array.object.get(mut vm, PropertyName.from_number(k))!
		k++
	}
	for k < length {
		value := array.object.get(mut vm, PropertyName.from_number(k))!
		accumulator = call(mut vm, Value.from_object(callback), js_undefined(), [
			accumulator,
			value,
			Value.from_f64(f64(k)),
			Value.from_object(array.object),
		])!
		k++
	}
	return accumulator
}

pub fn typed_array_prototype_reduce_right(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	initial_value := vm.argument(1)
	array := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, array.object, .seq_cst)!
	length := typed_array_length(record)
	callback := typed_array_callback_from_args(mut vm, 'reduceRight')!
	if length == 0 && vm.argument_count() <= 1 {
		return vm.throw_error_type(.type_error, .reduce_no_initial)
	}
	// The exclusive end represents the exhausted range without a signed -1
	// sentinel, including views longer than INT32_MAX.
	mut end := length
	mut accumulator := js_undefined()
	if vm.argument_count() > 1 {
		accumulator = initial_value
	} else {
		end--
		accumulator = array.object.get(mut vm, PropertyName.from_number(end))!
	}
	for end > 0 {
		end--
		k := end
		value := array.object.get(mut vm, PropertyName.from_number(k))!
		accumulator = call(mut vm, Value.from_object(callback), js_undefined(), [
			accumulator,
			value,
			Value.from_f64(f64(k)),
			Value.from_object(array.object),
		])!
	}
	return accumulator
}

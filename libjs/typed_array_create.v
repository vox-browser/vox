module libjs

// TypedArray.cpp::TypedArrayCreate. Retain the numeric argument before calling
// arbitrary construction, then validate both the brand/bounds and minimum size.
pub fn typed_array_create(mut vm VM, constructor &Object, arguments []Value) !&TypedArray {
	first := if arguments.len == 1 && arguments[0].is_number() {
		?f64(arguments[0].number)
	} else {
		none
	}
	object := construct(mut vm, Value.from_object(constructor), arguments, none)!
	record := validate_typed_array(mut vm, object, .seq_cst)!
	if requested := first {
		if is_typed_array_out_of_bounds(record) {
			return vm.throw_error_type(.type_error, .buffer_out_of_bounds, 'TypedArray')
		}
		if f64(typed_array_length(record)) < requested {
			return vm.throw_error_type(.type_error, .invalid_length, 'typed array')
		}
	}
	return object.typed_array or { panic('validated TypedArray has no slots') }
}

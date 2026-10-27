module libjs

// TypedArrayPrototype.cpp::join. UTF-16 code-unit assembly replaces the AK
// builder, preserving separator conversion before all live element reads.
pub fn typed_array_prototype_join(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	separator := vm.argument(0)
	array := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, array.object, .seq_cst)!
	length := typed_array_length(record)
	sep := if separator.is_undefined() {
		utf16_string(',')
	} else {
		separator.to_primitive_string(mut vm)!.utf16
	}
	mut builder := []u16{}
	mut result_length := uint(0)
	for k := u32(0); k < length; k++ {
		if k > 0 {
			result_length = checked_js_string_length_sum(mut vm, result_length, uint(sep.len()),
				.string_size_must_not_overflow)!
			// V's flattened string storage has a signed-int array length.
			if result_length > 0x7fffffff {
				return vm.throw_error_type(.range_error, .string_size_must_not_overflow)
			}
			builder << sep.data
		}
		element := array.object.get(mut vm, PropertyName.from_number(k))!
		next := if element.is_undefined() {
			Utf16String{}
		} else {
			element.to_primitive_string(mut vm)!.utf16
		}
		result_length = checked_js_string_length_sum(mut vm, result_length, uint(next.len()),
			.string_size_must_not_overflow)!
		if result_length > 0x7fffffff {
			return vm.throw_error_type(.range_error, .string_size_must_not_overflow)
		}
		builder << next.data
	}
	return Value.from_string(vm.create_string(Utf16String{ data: builder }))
}

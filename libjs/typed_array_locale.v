module libjs

// TypedArrayPrototype.cpp::to_locale_string. Number/BigInt locale builtins
// remain dependencies, supplied through their intrinsic prototype getters.
pub fn typed_array_prototype_to_locale_string(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	locales := vm.argument(0)
	options := vm.argument(1)
	array := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, array.object, .seq_cst)!
	length := typed_array_length(record)
	mut builder := []u16{}
	mut result_length := uint(0)
	for k := u32(0); k < length; k++ {
		if k > 0 {
			result_length = checked_js_string_length_sum(mut vm, result_length, 1,
				.string_size_must_not_overflow)!
			if result_length > 0x7fffffff {
				return vm.throw_error_type(.range_error, .string_size_must_not_overflow)
			}
			builder << u16(`,`)
		}
		element := array.object.get(mut vm, PropertyName.from_number(k))!
		if !element.is_nullish() {
			value := element.invoke_with_prototypes(mut vm,
				PropertyName.from_str('toLocaleString'), [locales, options], prototypes)!
			text := value.to_primitive_string(mut vm)!.utf16
			result_length = checked_js_string_length_sum(mut vm, result_length, uint(text.len()),
				.string_size_must_not_overflow)!
			if result_length > 0x7fffffff {
				return vm.throw_error_type(.range_error, .string_size_must_not_overflow)
			}
			builder << text.data
		}
	}
	return Value.from_string(vm.create_string(Utf16String{ data: builder }))
}

module libjs

import math

// Runtime/StringPrototype.cpp::repeat and AK::Utf16StringBuilder::append_repeated.
pub fn string_prototype_repeat(mut vm VM) !Value {
	text := string_primitive_from(mut vm)!
	n := vm.argument(0).to_integer_or_infinity(mut vm)!
	if n < 0 { return vm.throw_error_type(.range_error, .string_repeat_count_must_be, 'positive') }
	if math.is_inf(n, 1) {
		return vm.throw_error_type(.range_error, .string_repeat_count_must_be, 'finite')
	}
	if n == 0 || text.is_empty() { return Value.from_string(vm.empty_string()) }
	if n > 9007199254740991.0 {
		return vm.throw_error_type(.range_error, .string_repeat_count_must_not_overflow)
	}
	count := uint(n)
	length := checked_js_string_length_product(mut vm, uint(text.utf16.len()), count,
		.string_repeat_count_must_not_overflow)!
	// The existing flattened V storage uses a signed-int array length.
	if length > 0x7fffffff {
		return vm.throw_error_type(.range_error, .string_repeat_count_must_not_overflow)
	}
	mut units := []u16{}
	for _ in 0 .. int(count) {
		units << text.utf16.data
	}
	return Value.from_string(vm.create_string(Utf16String{ data: units }))
}

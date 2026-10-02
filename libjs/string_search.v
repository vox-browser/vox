module libjs

import math

// Runtime/StringPrototype.cpp::StringIndexOf and AK/Utf16View.h's code-unit
// substring search. The flattened V storage uses the same ordered comparisons.
pub fn string_index_of(text Utf16String, search Utf16String, from_index usize) ?usize {
	length := usize(text.len())
	search_length := usize(search.len())
	if search_length == 0 && from_index <= length { return from_index }
	if search_length > length || from_index > length - search_length { return none }
	for index in int(from_index) .. int(length - search_length) + 1 {
		if utf16_equals(text.data[index..index + search.len()], search.data) { return usize(index) }
	}
	return none
}

pub fn string_last_index_of(text Utf16String, search Utf16String, from_index usize) ?usize {
	assert from_index <= usize(text.len()) && usize(search.len()) <= usize(text.len()) - from_index
	for index := int(from_index); index >= 0; index-- {
		if utf16_equals(text.data[index..index + search.len()], search.data) { return usize(index) }
	}
	return none
}

pub fn string_prototype_index_of(mut vm VM) !Value {
	text := string_primitive_from(mut vm)!
	search := vm.argument(0).to_primitive_string(mut vm)!
	mut start := usize(0)
	if vm.argument_count() > 1 {
		position := vm.argument(1).to_integer_or_infinity(mut vm)!
		start = usize(math.min(math.max(position, 0), text.length_in_utf16_code_units()))
	}
	if index := string_index_of(text.utf16, search.utf16, start) {
		return Value.from_f64(f64(index))
	}
	return Value.from_i32(-1)
}

pub fn string_prototype_last_index_of(mut vm VM) !Value {
	text := string_primitive_from(mut vm)!
	search := vm.argument(0).to_primitive_string(mut vm)!
	position := vm.argument(1).to_number(mut vm)!
	pos := if position.is_nan() { math.inf(1) } else { position.to_integer_or_infinity(mut vm)! }
	length := text.length_in_utf16_code_units()
	search_length := search.length_in_utf16_code_units()
	if length < search_length { return Value.from_i32(-1) }
	start := usize(math.min(math.max(pos, 0), length - search_length))
	if index := string_last_index_of(text.utf16, search.utf16, start) {
		return Value.from_f64(f64(index))
	}
	return Value.from_i32(-1)
}

module libjs

import math

// Runtime/StringPrototype.cpp::slice. Clamp relative offsets in double space
// before narrowing them, and keep all boundaries in UTF-16 code units.
pub fn string_prototype_slice(mut vm VM) !Value {
	start_value := vm.argument(0)
	end_value := vm.argument(1)
	text := string_primitive_from(mut vm)!
	length := f64(text.length_in_utf16_code_units())
	mut start := start_value.to_integer_or_infinity(mut vm)!
	if math.is_inf(start, -1) {
		start = 0
	} else if start < 0 {
		start = math.max(length + start, 0)
	} else {
		start = math.min(start, length)
	}
	mut end := length
	if !end_value.is_undefined() {
		end = end_value.to_integer_or_infinity(mut vm)!
		if math.is_inf(end, -1) {
			end = 0
		} else if end < 0 {
			end = math.max(length + end, 0)
		} else {
			end = math.min(end, length)
		}
	}
	if start >= end { return Value.from_string(vm.empty_string()) }
	return Value.from_string(vm.create_string(Utf16String.from_slice(text.utf16.data[int(start)..int(end)])))
}

pub fn string_prototype_substring(mut vm VM) !Value {
	text := string_primitive_from(mut vm)!
	length := f64(text.length_in_utf16_code_units())
	start := vm.argument(0).to_integer_or_infinity(mut vm)!
	end := if vm.argument(1).is_undefined() {
		length
	} else {
		vm.argument(1).to_integer_or_infinity(mut vm)!
	}
	final_start := int(math.min(math.max(start, 0), length))
	final_end := int(math.min(math.max(end, 0), length))
	from := if final_start < final_end { final_start } else { final_end }
	to := if final_start > final_end { final_start } else { final_end }
	return Value.from_string(vm.create_string(Utf16String.from_slice(text.utf16.data[from..to])))
}

// Annex B StringPrototype::substr: its second argument is a length. Clamp the
// end to the string's size before converting to the native slice index type.
pub fn string_prototype_substr(mut vm VM) !Value {
	text := string_primitive_from(mut vm)!
	size := text.length_in_utf16_code_units()
	mut start := vm.argument(0).to_integer_or_infinity(mut vm)!
	if math.is_inf(start, -1) {
		start = 0
	} else if start < 0 {
		start = math.max(size + start, 0)
	} else {
		start = math.min(start, size)
	}
	length_value := vm.argument(1)
	mut length := if length_value.is_undefined() {
		f64(size)
	} else {
		length_value.to_integer_or_infinity(mut vm)!
	}
	length = math.min(math.max(length, 0), size)
	end := int(math.min(start + length, f64(size)))
	if start >= end { return Value.from_string(vm.empty_string()) }
	return Value.from_string(vm.create_string(Utf16String.from_slice(text.utf16.data[int(start)..end])))
}

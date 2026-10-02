module libjs

import math

// Runtime/StringPrototype.cpp::primitive_string_from and this_string_value.
// Generic character methods coerce once; toString/valueOf require an own brand.
fn string_primitive_from(mut vm VM) !&PrimitiveString {
	value := require_object_coercible(mut vm, vm.this_value())!
	return value.to_primitive_string(mut vm)
}

fn this_string_value(mut vm VM, value Value) !&PrimitiveString {
	if value.is_string() { return value.as_string() }
	if value.is_object() {
		if wrapper := value.as_object().string_object { return wrapper.value }
	}
	return vm.throw_error_type(.type_error, .not_an_object_of_type, 'String')
}

pub fn string_prototype_to_string(mut vm VM) !Value {
	return Value.from_string(this_string_value(mut vm, vm.this_value())!)
}

pub fn string_prototype_value_of(mut vm VM) !Value {
	return Value.from_string(this_string_value(mut vm, vm.this_value())!)
}

// Runtime/StringPrototype.h::CodePoint and StringPrototype.cpp::CodePointAt.
pub struct StringCodePoint {
pub:
	is_unpaired_surrogate bool
	code_point            u32
	code_unit_count       int
}

pub fn string_code_point_at(text Utf16String, position int) StringCodePoint {
	assert position >= 0 && position < text.len()
	first := text.data[position]
	if !is_utf16_high_surrogate(first) && !is_utf16_low_surrogate(first) {
		return StringCodePoint{
			code_point:      u32(first)
			code_unit_count: 1
		}
	}
	if is_utf16_low_surrogate(first) || position + 1 == text.len() {
		return StringCodePoint{
			is_unpaired_surrogate: true
			code_point:            u32(first)
			code_unit_count:       1
		}
	}
	second := text.data[position + 1]
	if !is_utf16_low_surrogate(second) {
		return StringCodePoint{
			is_unpaired_surrogate: true
			code_point:            u32(first)
			code_unit_count:       1
		}
	}
	return StringCodePoint{
		code_point:      0x10000 + (u32(first - 0xd800) << 10) + u32(second - 0xdc00)
		code_unit_count: 2
	}
}

pub fn string_prototype_at(mut vm VM) !Value {
	text := string_primitive_from(mut vm)!
	length := text.length_in_utf16_code_units()
	relative_index := vm.argument(0).to_integer_or_infinity(mut vm)!
	if math.is_inf(relative_index, 0) { return js_undefined() }
	index := if relative_index >= 0 { relative_index } else { length + relative_index }
	if index < 0 || index >= length { return js_undefined() }
	return Value.from_string(vm.create_string(Utf16String{ data: [text.utf16.data[int(index)]] }))
}

pub fn string_prototype_char_at(mut vm VM) !Value {
	text := string_primitive_from(mut vm)!
	position := vm.argument(0).to_integer_or_infinity(mut vm)!
	if position < 0 || position >= text.length_in_utf16_code_units() {
		return Value.from_string(vm.empty_string())
	}
	return Value.from_string(vm.create_string(Utf16String{ data: [text.utf16.data[int(position)]] }))
}

pub fn string_prototype_char_code_at(mut vm VM) !Value {
	text := string_primitive_from(mut vm)!
	position := vm.argument(0).to_integer_or_infinity(mut vm)!
	if position < 0 || position >= text.length_in_utf16_code_units() {
		return Value.from_f64(math.nan())
	}
	return Value.from_i32(int(text.utf16.data[int(position)]))
}

pub fn string_prototype_code_point_at(mut vm VM) !Value {
	text := string_primitive_from(mut vm)!
	position := vm.argument(0).to_integer_or_infinity(mut vm)!
	if position < 0 || position >= text.length_in_utf16_code_units() { return js_undefined() }
	return Value.from_i32(int(string_code_point_at(text.utf16, int(position)).code_point))
}

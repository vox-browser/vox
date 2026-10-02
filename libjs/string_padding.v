module libjs

pub enum StringPadPlacement {
	start
	end
}

// Runtime/StringPrototype.cpp::pad_string (StringPad). The builder and substring
// view are represented by existing flat V code-unit arrays.
pub fn string_pad(mut vm VM, text &PrimitiveString, max_length Value, fill_string Value, placement StringPadPlacement) !Value {
	int_max_length := max_length.to_length(mut vm)!
	string_length := u64(text.length_in_utf16_code_units())
	if int_max_length <= string_length { return Value.from_string(text) }
	filler := if fill_string.is_undefined() {
		utf16_string(' ')
	} else {
		fill_string.to_primitive_string(mut vm)!.utf16
	}
	if filler.is_empty() { return Value.from_string(text) }
	fill_length := int_max_length - string_length
	// V's flattened storage cannot represent a result beyond signed-int length.
	// Keep both source early returns and all conversions before this boundary.
	if int_max_length > 0x7fffffff {
		return vm.throw_error_type(.range_error, .string_size_must_not_overflow)
	}
	fill_code_units := u64(filler.len())
	mut truncated_filler := []u16{}
	for _ in 0 .. int(fill_length / fill_code_units) {
		truncated_filler << filler.data
	}
	truncated_filler << filler.data[..int(fill_length % fill_code_units)]
	mut units := []u16{}
	if placement == .start {
		units << truncated_filler
		units << text.utf16.data
	} else {
		units << text.utf16.data
		units << truncated_filler
	}
	return Value.from_string(vm.create_string(Utf16String{ data: units }))
}

pub fn string_prototype_pad_start(mut vm VM) !Value {
	max_length := vm.argument(0)
	fill_string := vm.argument(1)
	text := string_primitive_from(mut vm)!
	return string_pad(mut vm, text, max_length, fill_string, .start)
}

pub fn string_prototype_pad_end(mut vm VM) !Value {
	max_length := vm.argument(0)
	fill_string := vm.argument(1)
	text := string_primitive_from(mut vm)!
	return string_pad(mut vm, text, max_length, fill_string, .end)
}

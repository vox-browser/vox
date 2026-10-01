module libjs

// AK/UnicodeUtils.h::code_point_to_utf16. Surrogate code points are retained as
// individual units; supplementary scalar values emit the high/low pair.
fn append_utf16_code_point(mut units []u16, code_point u32) {
	if code_point <= 0xffff {
		units << u16(code_point)
	} else {
		value := code_point - 0x10000
		units << u16(0xd800 + (value >> 10))
		units << u16(0xdc00 + (value & 0x3ff))
	}
}

// Runtime/StringConstructor.cpp::from_char_code_impl, its one-argument path.
pub fn string_from_char_code_impl(mut vm VM, code_unit Value) !Value {
	unit := code_unit.to_u16(mut vm)!
	return Value.from_string(vm.create_string(Utf16String{ data: [unit] }))
}

pub fn string_constructor_from_char_code(mut vm VM) !Value {
	if vm.argument_count() == 1 { return string_from_char_code_impl(mut vm, vm.argument(0)) }
	mut units := []u16{cap: int(vm.argument_count())}
	for index in 0 .. vm.argument_count() {
		units << vm.argument(index).to_u16(mut vm)!
	}
	return Value.from_string(vm.create_string(Utf16String{ data: units }))
}

// Runtime/StringConstructor.cpp::from_code_point. Preserve the pinned body's
// ToInt32 before the range check, including wrapping integral values wider than
// 32 bits; this source behavior is not a standards-conformance claim.
pub fn string_constructor_from_code_point(mut vm VM) !Value {
	mut units := []u16{cap: int(vm.argument_count())}
	for index in 0 .. vm.argument_count() {
		number := vm.argument(index).to_number(mut vm)!
		if !number.is_integral_number() {
			return vm.throw_error_type(.range_error, .invalid_code_point, number.str())
		}
		code_point := number.to_i32(mut vm)!
		if code_point < 0 || code_point > 0x10ffff {
			return vm.throw_error_type(.range_error, .invalid_code_point, number.str())
		}
		append_utf16_code_point(mut units, u32(code_point))
	}
	return Value.from_string(vm.create_string(Utf16String{ data: units }))
}

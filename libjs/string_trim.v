module libjs

// StringPrototype.h::whitespace_character_code_units, exactly the pinned list.
const string_trim_whitespace = [u16(0x0009), 0x000a, 0x000b, 0x000c, 0x000d, 0x0020, 0x00a0, 0x1680,
	0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006, 0x2007, 0x2008, 0x2009, 0x200a, 0x2028,
	0x2029, 0x202f, 0x205f, 0x3000, 0xfeff]

pub enum StringTrimMode {
	start
	end
	both
}

// StringPrototype.cpp::TrimString and AK::Utf16View::trim. V's flat storage
// copies the resulting view; no UTF-8 conversion or broader whitespace class.
pub fn trim_string(mut vm VM, value Value, where StringTrimMode) !Utf16String {
	input := require_object_coercible(mut vm, value)!
	text := input.to_primitive_string(mut vm)!
	mut start := 0
	mut length := text.length_in_utf16_code_units()
	if where in [.start, .both] {
		for length > 0 && text.utf16.data[start] in string_trim_whitespace {
			start++
			length--
		}
	}
	if where in [.end, .both] {
		for length > 0 && text.utf16.data[start + length - 1] in string_trim_whitespace {
			length--
		}
	}
	return Utf16String.from_slice(text.utf16.data[start..start + length])
}

pub fn string_prototype_trim(mut vm VM) !Value {
	return Value.from_string(vm.create_string(trim_string(mut vm, vm.this_value(), .both)!))
}

pub fn string_prototype_trim_start(mut vm VM) !Value {
	return Value.from_string(vm.create_string(trim_string(mut vm, vm.this_value(), .start)!))
}

pub fn string_prototype_trim_end(mut vm VM) !Value {
	return Value.from_string(vm.create_string(trim_string(mut vm, vm.this_value(), .end)!))
}

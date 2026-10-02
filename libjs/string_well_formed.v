module libjs

// AK::Utf16View::validate and Utf16StringData::to_well_formed use simdutf.
// Translate simdutf 7.4.0 src/scalar/utf16.h's native-endian validate and
// to_well_formed_utf16 paths over V's flattened native code-unit storage.
// Copyright 2021 The simdutf authors. See licenses/simdutf-MIT.txt.
fn (text Utf16String) is_well_formed() bool {
	mut position := 0
	for position < text.len() {
		word := text.data[position]
		if (word & 0xf800) == 0xd800 {
			if position + 1 >= text.len() { return false }
			diff := u16(word - 0xd800)
			if diff > 0x3ff { return false }
			diff2 := u16(text.data[position + 1] - 0xdc00)
			if diff2 > 0x3ff { return false }
			position += 2
		} else {
			position++
		}
	}
	return true
}

fn (text Utf16String) to_well_formed() Utf16String {
	// AK::Utf16String::to_well_formed retains already-valid storage.
	if text.is_well_formed() { return text }
	mut units := []u16{len: text.len()}
	mut high_surrogate_prev := false
	for index, unit in text.data {
		high_surrogate := is_utf16_high_surrogate(unit)
		low_surrogate := is_utf16_low_surrogate(unit)
		if high_surrogate_prev && !low_surrogate { units[index - 1] = 0xfffd }
		units[index] = if !high_surrogate_prev && low_surrogate { u16(0xfffd) } else { unit }
		high_surrogate_prev = high_surrogate
	}
	if high_surrogate_prev { units[units.len - 1] = 0xfffd }
	return Utf16String{
		data: units
	}
}

pub fn string_prototype_is_well_formed(mut vm VM) !Value {
	text := string_primitive_from(mut vm)!
	return Value.from_bool(text.utf16.is_well_formed())
}

pub fn string_prototype_to_well_formed(mut vm VM) !Value {
	text := string_primitive_from(mut vm)!
	return Value.from_string(vm.create_string(text.utf16.to_well_formed()))
}

module libjs

// Runtime/StringPrototype.cpp::to_lowercase and to_uppercase. Locale-list
// processing for their locale variants remains a separate Intl dependency.
pub fn string_prototype_to_lowercase(mut vm VM) !Value {
	text := string_primitive_from(mut vm)!
	if string_case_is_unchanged_ascii(text.utf16, false) {
		return Value.from_string(text)
	}
	return Value.from_string(vm.create_string(unicode_string_case(text.utf16, false)))
}

pub fn string_prototype_to_uppercase(mut vm VM) !Value {
	text := string_primitive_from(mut vm)!
	if string_case_is_unchanged_ascii(text.utf16, true) {
		return Value.from_string(text)
	}
	return Value.from_string(vm.create_string(unicode_string_case(text.utf16, true)))
}

// ASCII strings whose letters already have the requested case retain their
// primitive cell and avoid allocating and hashing another copy.
fn string_case_is_unchanged_ascii(text Utf16String, uppercase bool) bool {
	for unit in text.as_slice() {
		if unit > 0x7f { return false }
		if uppercase {
			if unit >= 0x61 && unit <= 0x7a { return false }
		} else if unit >= 0x41 && unit <= 0x5a {
			return false
		}
	}
	return true
}

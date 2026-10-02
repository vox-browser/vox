module libjs

// LibUnicode/Normalize.h and Normalize.cpp::normalization_form_from_string.
pub enum StringNormalizationForm {
	nfd
	nfc
	nfkd
	nfkc
}

fn string_normalization_form_from_string(form Utf16String) StringNormalizationForm {
	if form == utf16_string('NFD') { return .nfd }
	if form == utf16_string('NFC') { return .nfc }
	if form == utf16_string('NFKD') { return .nfkd }
	if form == utf16_string('NFKC') { return .nfkc }
	panic('Unreachable normalization form')
}

// Runtime/StringPrototype.cpp::normalize. Receiver conversion precedes form
// conversion/validation, including for an empty input string.
pub fn string_prototype_normalize(mut vm VM) !Value {
	text := string_primitive_from(mut vm)!
	form_value := vm.argument(0)
	form := if form_value.is_undefined() {
		utf16_string('NFC')
	} else {
		form_value.to_primitive_string(mut vm)!.utf16
	}
	if form !in [utf16_string('NFC'), utf16_string('NFD'), utf16_string('NFKC'),
		utf16_string('NFKD')] {
		return vm.throw_error_type(.range_error, .invalid_normalization_form, form.str())
	}
	return Value.from_string(vm.create_string(unicode_string_normalize(text.utf16,
		string_normalization_form_from_string(form))))
}

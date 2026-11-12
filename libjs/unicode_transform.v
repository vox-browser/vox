module libjs

import vunicode

// ECMAScript default casing is locale independent.
// LibUnicode/Utf16String.cpp and AK::Utf16View's ASCII conversion bodies.
// Default String casing uses Unicode root mappings, independent of host locale.
fn unicode_string_case(text Utf16String, uppercase bool) Utf16String {
	if text.data.all(it <= 0x7f) {
		mut units := []u16{cap: text.len()}
		for unit in text.data {
			units << if uppercase && unit >= 0x61 && unit <= 0x7a {
				unit - 0x20
			} else if !uppercase && unit >= 0x41 && unit <= 0x5a {
				unit + 0x20
			} else {
				unit
			}
		}
		return Utf16String{
			data: units
		}
	}
	return Utf16String.from_slice(vunicode.map_case(text.data, '', if uppercase {
		.uppercase
	} else {
		.lowercase
	}).units)
}

module libjs

import vunicode

fn regex_unicode_property_strings(property u32) [][]u32 {
	if !regex_unicode_is_ecma262_string_property(property) { return [][]u32{} }
	mut result := vunicode.property_singletons(property)
	result << vunicode.property_strings(property)
	return result
}

// unicode_get_string_property_data's query/short-buffer boundary. A zero-length
// output performs the source's null-pointer query without changing any storage.
pub fn regex_get_string_property_data_into(name string, mut output []u32) u32 {
	property := regex_unicode_property_from_string(name) or { return 0 }
	if !regex_unicode_is_ecma262_string_property(property) { return 0 }
	strings := regex_unicode_property_strings(property)
	mut multiple := [][]u32{}
	for points in strings {
		if points.len > 1 { multiple << points }
	}
	mut needed := u32(1)
	for points in multiple {
		needed += 1 + u32(points.len)
	}
	if output.len == 0 || u32(output.len) < needed { return needed }
	output[0] = u32(multiple.len)
	mut offset := 1
	for points in multiple {
		output[offset] = u32(points.len)
		offset++
		for point in points {
			output[offset] = point
			offset++
		}
	}
	return needed
}

// LibUnicode/Rust/src/character_types.rs::get_string_property_data.
pub fn regex_get_string_property_data(name string) []u32 {
	mut query := []u32{}
	needed := regex_get_string_property_data_into(name, mut query)
	if needed == 0 { return []u32{} }
	if needed > 0x7fffffff { panic('Unicode string property exceeds V array capacity') }
	mut output := []u32{len: int(needed)}
	written := regex_get_string_property_data_into(name, mut output)
	if written == 0 || written > needed { return []u32{} }
	return output[..int(written)]
}

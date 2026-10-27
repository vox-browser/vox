module libjs

#flag -I @DIR
#include "regex_unicode_property.h"

fn C.vox2_regex_u_getBinaryPropertySet(property int, status &int) &C.Vox2UnicodePropertySet
fn C.vox2_regex_uset_getItemCount(set &C.Vox2UnicodePropertySet) int

// LibUnicode/CharacterTypes.cpp::get_property_strings. Code-point arrays
// replace its UTF-8 String intermediary before the FFI packs the same points.
fn regex_unicode_property_strings(property u32) [][]u32 {
	mut result := [][]u32{}
	if !regex_unicode_is_ecma262_string_property(property) { return result }
	mut status := 0
	set := C.vox2_regex_u_getBinaryPropertySet(int(property), &status)
	if status > 0 || unsafe { set == nil } { return result }
	// This frozen set belongs to ICU; callers must not close or modify it.
	range_count := C.vox2_regex_uset_getRangeCount(set)
	for index in 0 .. range_count {
		range := regex_unicode_property_set_range(set, index)
		for point := range.start; point <= range.end; point++ {
			result << [point]
		}
	}
	for index in range_count .. C.vox2_regex_uset_getItemCount(set) {
		mut start := 0
		mut end := 0
		status = 0
		length := C.vox2_regex_uset_getItem(set, index, &start, &end, unsafe { nil }, 0, &status)
		assert length >= 0 && (status <= 0 || status == int(C.U_BUFFER_OVERFLOW_ERROR))
		mut units := []u16{len: length}
		status = 0
		// The ICU extraction supplies the actual string units; production
		// assertion elimination must not remove this second call.
		written := C.vox2_regex_uset_getItem(set, index, &start, &end, units.data, units.len, &status)
		assert written == length
		assert status <= 0
		input := RegexInput(RegexUtf16Input{
			units: units
		})
		mut points := []u32{}
		for position := uint(0); position < input.len(); position += regex_code_point_len(true,
			input, position) {
			points << regex_decode_code_point(true, input, position)
		}
		result << points
	}
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

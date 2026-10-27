// SPDX-License-Identifier: BSD-2-Clause
// LibUnicode/CharacterTypes.cpp's C exports: route native Rust calls through
// the existing source-translated V Unicode operations and actual ICU ABI.
module libregex

import libjs

fn unicode_abi_string(data &u8, length uint) string {
	if length == 0 { return '' }
	return unsafe { data.vbytes(int(length)).bytestr() }
}

fn unicode_abi_optional_string(data &u8, length uint) ?string {
	if isnil(data) { return none }
	return unicode_abi_string(data, length)
}

@[export: 'unicode_property_matches']
fn native_property_matches(point u32, name &u8, name_length uint, value &u8, value_length uint) bool {
	return libjs.regex_property_matches(point, unicode_abi_string(name, name_length), unicode_abi_optional_string(value, value_length))
}

@[export: 'unicode_property_matches_case_insensitive']
fn native_property_matches_case_insensitive(point u32, name &u8, name_length uint, value &u8, value_length uint) bool {
	return libjs.regex_property_matches_case_insensitive(point, unicode_abi_string(name, name_length), unicode_abi_optional_string(value, value_length))
}

@[export: 'unicode_property_all_case_equivalents_match']
fn native_property_all_case_equivalents_match(point u32, name &u8, name_length uint, value &u8, value_length uint) bool {
	return libjs.regex_property_all_case_equivalents_match(point, unicode_abi_string(name, name_length), unicode_abi_optional_string(value, value_length))
}

@[export: 'unicode_resolve_property']
fn native_resolve_property(name &u8, name_length uint, value &u8, value_length uint, kind &u8, id &u32) bool {
	property := libjs.regex_resolve_property(unicode_abi_string(name, name_length), unicode_abi_optional_string(value, value_length)) or { return false }
	unsafe {
		*kind = u8(property.kind)
		*id = property.id
	}
	return true
}

@[export: 'unicode_resolved_property_matches']
fn native_resolved_property_matches(point u32, kind u8, id u32) bool {
	property_kind := libjs.regex_property_kind_from_u8(kind) or { return false }
	return libjs.regex_resolved_property_matches(point, libjs.RegexResolvedProperty{ kind: property_kind, id: id })
}

@[export: 'unicode_code_point_has_space_separator_general_category']
fn native_has_space_separator(point u32) bool {
	return libjs.regex_has_space_separator_category(point)
}

@[export: 'unicode_code_point_has_identifier_start_property']
fn native_has_identifier_start(point u32) bool {
	return libjs.regex_has_identifier_start_property(point)
}

@[export: 'unicode_code_point_has_identifier_continue_property']
fn native_has_identifier_continue(point u32) bool {
	return libjs.regex_has_identifier_continue_property(point)
}

@[export: 'unicode_is_string_property']
fn native_is_string_property(name &u8, name_length uint) bool {
	return libjs.regex_is_string_property(unicode_abi_string(name, name_length))
}

@[export: 'unicode_is_valid_ecma262_property']
fn native_is_valid_property(name &u8, name_length uint, value &u8, value_length uint) bool {
	return libjs.regex_is_valid_ecma262_property(unicode_abi_string(name, name_length), unicode_abi_optional_string(value, value_length))
}

@[export: 'unicode_get_string_property_data']
fn native_get_string_property_data(name &u8, name_length uint, output &u32, capacity u32) u32 {
	mut span := []u32{len: int(capacity)}
	needed := libjs.regex_get_string_property_data_into(unicode_abi_string(name, name_length), mut span)
	if needed > 0 && needed <= capacity {
		unsafe { C.memcpy(output, span.data, uint(needed) * sizeof(u32)) }
	}
	return needed
}

@[export: 'unicode_simple_case_fold']
fn native_simple_case_fold(point u32, unicode_mode bool) u32 {
	return libjs.regex_canonicalize(point, unicode_mode)
}

@[export: 'unicode_code_point_matches_range_ignoring_case']
fn native_range_ignoring_case(point u32, start u32, end u32, unicode_mode bool) bool {
	return libjs.regex_code_point_matches_range_ignoring_case(point, start, end, unicode_mode)
}

@[export: 'unicode_get_case_closure']
fn native_get_case_closure(point u32, output &u32, capacity u32) u32 {
	mut span := []u32{len: int(capacity)}
	written := libjs.regex_get_case_closure(point, mut span)
	if written > 0 { unsafe { C.memcpy(output, span.data, written * sizeof(u32)) } }
	return u32(written)
}

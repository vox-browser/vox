// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Actual JavaScriptCore primitive-string projection for the source
// HTML/StructuredSerialize codec. UTF-8 diagnostics are never the string ABI.
module browserjs

import libjs


fn C.JSStringGetLength(string_value voidptr) uint
fn C.JSStringGetCharactersPtr(string_value voidptr) &u16

pub fn (runtime &Runtime) native_utf16_string(value voidptr) !libjs.Utf16String {
	runtime.require_javascript_value_context()!
	if value == unsafe { nil } || !C.JSValueIsString(runtime.context, value) {
		return error('TypeError: UTF16 projection requires an actual string primitive')
	}
	mut exception := unsafe { nil }
	text := C.JSValueToStringCopy(runtime.context, value, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	if text == unsafe { nil } { return error('JavaScriptCore string projection failed') }
	defer { C.JSStringRelease(text) }
	length := C.JSStringGetLength(text)
	if length > uint(2147483647) { return error('JavaScriptCore string does not fit the source V code-unit span') }
	characters := C.JSStringGetCharactersPtr(text)
	mut units := []u16{len: int(length)}
	for index in 0 .. units.len { units[index] = unsafe { characters[index] } }
	// Source Utf16String::from_utf16 preserves raw units, including lone
	// surrogates, and compresses all-ASCII input regardless of its length.
	return libjs.utf16_string_from_code_units(units)
}

pub fn (mut runtime Runtime) javascript_utf16_string(text libjs.Utf16String) !voidptr {
	runtime.require_javascript_value_context()!
	units := text.code_units()
	actual_text := C.JSStringCreateWithCharacters(units.data, uint(units.len))
	if actual_text == unsafe { nil } { return error('JavaScriptCore string creation failed') }
	defer { C.JSStringRelease(actual_text) }
	actual_value := C.JSValueMakeString(runtime.context, actual_text)
	return runtime.retain_javascript_value(actual_value)
}

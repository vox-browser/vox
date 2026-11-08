module browserjs

import libjs

// Store DOMString keys as WTF-8 internally and reconstruct their raw UTF-16
// at the JS boundary. UTF-8 C strings replace lone surrogates and truncate NUL.
fn (runtime &Runtime) indexed_db_dom_string(value voidptr) !string {
	mut exception := unsafe { nil }
	text := C.vox_jsc_JSValueToStringCopy(runtime.context, value, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	if text == unsafe { nil } { return error('Failed to convert IndexedDB DOMString') }
	defer { C.JSStringRelease(text) }
	length := C.JSStringGetLength(text)
	mut units := []u16{len: int(length)}
	C.vox_jsc_copy_string_characters(text, units.data, length)
	return libjs.utf16_string_from_code_units(units).str()
}

fn (runtime &Runtime) indexed_db_string(value string) voidptr {
	units := libjs.utf16_string_from_utf8_without_validation(value).code_units()
	text := C.JSStringCreateWithCharacters(units.data, uint(units.len))
	defer { C.JSStringRelease(text) }
	return C.vox_jsc_JSValueMakeString(runtime.context, text)
}

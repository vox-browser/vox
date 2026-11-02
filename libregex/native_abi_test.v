module libregex

import libjs

fn native_abi_compile_error(pattern libjs.Utf16String) string {
	if mut compiled := CompiledRustRegex.compile(pattern, ECMAScriptCompileFlags{unicode: true}) {
		compiled.destroy()
		assert false, 'invalid pattern unexpectedly compiled'
		return ''
	} else {
		return err.msg()
	}
}

fn test_native_compile_error_strings_outlive_rust_buffers() {
	ascii := libjs.utf16_string('[z-a]')
	utf16 := libjs.utf16_string('[é-a]')
	assert ascii.has_ascii_storage()
	assert !utf16.has_ascii_storage()
	// Each compile copies the error message and frees its native buffer. Keep
	// earlier messages alive while subsequent errors reuse native allocations.
	mut messages := []string{}
	for _ in 0 .. 32 {
		messages << native_abi_compile_error(ascii)
		messages << native_abi_compile_error(utf16)
	}
	for index, message in messages {
		expected := if index % 2 == 0 {
			"invalid character range 'z'-'a'"
		} else {
			"invalid character range 'é'-'a'"
		}
		assert message == expected
	}
}

fn test_native_compile_ascii_preserves_optional_error_outputs() {
	pattern := 'a'
	invalid := '['
	sentinel := 'unchanged'
	mut error_data := sentinel.str
	mut error_length := uint(123)
	handle := C.vox_rust_regex_compile_ascii(pattern.str, uint(pattern.len), C.RustRegexFlags{},
		&error_data, &error_length)
	assert !isnil(handle)
	C.rust_regex_free(handle)
	assert voidptr(error_data) == voidptr(sentinel.str)
	assert error_length == 123
	assert isnil(C.vox_rust_regex_compile_ascii(invalid.str, uint(invalid.len), C.RustRegexFlags{},
		unsafe { nil }, &error_length))
	assert error_length == 123
	assert isnil(C.vox_rust_regex_compile_ascii(invalid.str, uint(invalid.len), C.RustRegexFlags{},
		&error_data, unsafe { nil }))
	assert voidptr(error_data) == voidptr(sentinel.str)
}

fn test_native_compile_utf16_preserves_optional_error_outputs() {
	pattern := [u16(0x00e9)]
	invalid := [u16(0x005b)]
	sentinel := 'unchanged'
	mut error_data := sentinel.str
	mut error_length := uint(456)
	handle := C.vox_rust_regex_compile(pattern.data, uint(pattern.len), C.RustRegexFlags{},
		&error_data, &error_length)
	assert !isnil(handle)
	C.rust_regex_free(handle)
	assert voidptr(error_data) == voidptr(sentinel.str)
	assert error_length == 456
	assert isnil(C.vox_rust_regex_compile(invalid.data, uint(invalid.len), C.RustRegexFlags{},
		unsafe { nil }, &error_length))
	assert error_length == 456
	assert isnil(C.vox_rust_regex_compile(invalid.data, uint(invalid.len), C.RustRegexFlags{},
		&error_data, unsafe { nil }))
	assert voidptr(error_data) == voidptr(sentinel.str)
}

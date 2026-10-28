module libjs

// LibUnicode/Normalize.cpp::normalizer_for_form and its UTF-16 normalize body.
// C API capacity preflight replaces the C++ UnicodeString output allocation;
// ICU failure keeps the exact original UTF-16 contents, as upstream does.
fn unicode_string_normalize(text Utf16String, form StringNormalizationForm) Utf16String {
	mut status := i32(0)
	normalizer := match form {
		.nfd { C.unorm2_getNFDInstance(&status) }
		.nfc { C.unorm2_getNFCInstance(&status) }
		.nfkd { C.unorm2_getNFKDInstance(&status) }
		.nfkc { C.unorm2_getNFKCInstance(&status) }
	}

	if status > 0 { return text }
	assert normalizer != unsafe { nil }
	if text.is_empty() { return text }
	mut normalize_status := i32(0)
	length := C.unorm2_normalize(normalizer, text.data.data, i32(text.len()), unsafe { nil }, 0,
		&normalize_status)
	if length < 0 || (normalize_status > 0 && normalize_status != C.U_BUFFER_OVERFLOW_ERROR) {
		return text
	}
	mut units := []u16{len: length}
	normalize_status = 0
	written := C.unorm2_normalize(normalizer, text.data.data, i32(text.len()), units.data, i32(units.len),
		&normalize_status)
	if normalize_status > 0 { return text }
	assert written >= 0 && written <= units.len
	return Utf16String.from_slice(units[..written])
}

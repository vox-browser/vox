module browserjs

import libjs

fn C.JSStringIsEqual(left voidptr, right voidptr) bool

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn assert_source_string_units(text voidptr, expected []u16) {
	assert text != unsafe { nil }
	assert int(C.JSStringGetLength(text)) == expected.len
	characters := C.JSStringGetCharactersPtr(text)
	for index, unit in expected {
		assert unsafe { characters[index] } == unit
	}
}

fn test_native_source_strings_match_the_existing_decoder_and_empty_string_identity() {
	sources := ['', 'ASCII source', '日本語 Ελληνικά 😀 é', '\xef\xbb\xbfBOM',
		[u8(`A`), 0, `B`].bytestr(), [u8(0x80)].bytestr(), [u8(0xe2), 0x82].bytestr(),
		[u8(0xed), 0xa0, 0x80].bytestr(), [u8(0xed), 0xbf, 0xbf].bytestr(),
		[u8(0xf4), 0x90, 0x80, 0x80].bytestr(), '😀 café '.repeat(10000)]
	for source in sources {
		units := libjs.utf16(source)
		expected := C.JSStringCreateWithCharacters(units.data, uint(units.len))
		actual := js_source_string(source)
		assert_source_string_units(actual, units)
		assert C.JSStringIsEqual(actual, expected)
		C.JSStringRelease(actual)
		C.JSStringRelease(expected)
	}
	for fallback in ['', '\xef\xbb\xbfBOM', [u8(0x80)].bytestr(), [u8(0xed), 0xa0, 0x80].bytestr()] {
		assert C.vox_browserjs_source_utf8_string(fallback.str, uint(fallback.len)) == unsafe { nil }
	}
	for valid in ['ASCII source', '日本語 😀', [u8(`A`), 0, `B`].bytestr()] {
		text := C.vox_browserjs_source_utf8_string(valid.str, uint(valid.len))
		assert_source_string_units(text, libjs.utf16(valid))
		C.JSStringRelease(text)
	}
}

fn test_native_source_strings_own_their_storage_after_the_input_is_released() {
	for input in ['日本語 😀 source', [u8(`A`), 0, `B`].bytestr(), '\xef\xbb\xbfsource',
		[u8(0xed), 0xa0, 0x80].bytestr()] {
		mut source := input.clone()
		expected := libjs.utf16(source)
		actual := js_source_string(source)
		unsafe { source.free() }
		for _ in 0 .. 3 {
			$if gcboehm ? {
				C.GC_gcollect()
			}
			assert_source_string_units(actual, expected)
		}
		C.JSStringRelease(actual)
	}
}

fn test_native_source_conversion_preserves_actual_script_nuls_and_supplementary_text() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	source := '"A' + [u8(0)].bytestr() + '😀B"'
	actual := runtime.evaluate_host_value(source)!
	assert runtime.native_utf16_string(actual)!.code_units() == [u16(`A`), 0, 0xd83d, 0xde00, u16(`B`)]
	assert runtime.evaluate_host('\xef\xbb\xbf"BOM preserved"')! == 'BOM preserved'
	assert runtime.evaluate_host('40 + 2')! == '42'
}

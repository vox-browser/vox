module dom

import platform

fn test_utf16_length_matches_legacy_decoding_without_allocating_valid_text() {
	for text in ['', 'ascii', 'é中😀𐀀', '\x00é\r\n', '\xed\xa0\x80', '\xf0\x9f', '\x80x'] {
		mut expected := 0
		for scalar in text.runes() { expected += if u32(scalar) > 0xffff { 2 } else { 1 } }
		assert utf16_code_unit_length(text) == expected
	}
	text := 'ascii é中😀'.repeat(4096)
	before := platform.thread_arena_usage().used
	mut length := 0
	for _ in 0 .. 64 { length = utf16_code_unit_length(text) }
	after := platform.thread_arena_usage().used
	assert length == 10 * 4096
	$if prealloc { assert after == before }
}

fn test_whole_character_data_replacement_keeps_range_updates_and_unicode_normalization() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut text := document.create_text_node('before😀')
	mut range := document.create_range()
	range.set_start(text.as_node(), 2)!
	range.set_end(text.as_node(), 8)!
	text.set_data('中😀after')
	assert text.data() == '中😀after'
	assert text.length() == 8
	assert range.start_offset() == 0 && range.end_offset() == 0
	// Partial replacements still split UTF-16 surrogate pairs as before.
	text.replace_data(2, 0, 'X')!
	assert text.data() == '中�X�after'
	text.set_data('\xed\xa0\x80')
	assert text.data() == string_from_utf16_code_units(utf16_code_units_from_string('\xed\xa0\x80'))
}

fn test_whole_character_data_replacement_retains_only_owned_utf8_payload() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut text := document.create_text_node('')
	value := 'Text 中😀'.repeat(8192)
	text.set_data('warm')
	before := platform.thread_arena_usage().used
	text.set_data(value)
	after := platform.thread_arena_usage().used
	assert text.data() == value
	assert voidptr(text.data().str) != voidptr(value.str)
	$if prealloc { assert after - before < value.len + 4096 }
}

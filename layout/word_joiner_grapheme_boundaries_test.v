module layout

// The pinned V13 segmenter classifies U+2060 as Control (range U+2060..2064).
// Only U+2060 is admitted; every non-simple neighbor retains whole-string fallback.
fn word_joiner_reference_boundaries(text string) []int {
	mut result := [0]
	mut offset := 0
	for cluster in text.graphemes() {
		offset += utf16_length_for_line_box(cluster)
		result << offset
	}
	return result
}

fn word_joiner_existing_simple_scalars() []rune {
	mut result := []rune{}
	for bounds in [[0, 0x80], [0xa0, 0x300], [0x400, 0x483], [0x48a, 0x530],
		[0x2000, 0x200c], [0x2010, 0x202a]] {
		for scalar in bounds[0] .. bounds[1] {
			result << rune(scalar)
		}
	}
	return result
}

fn test_word_joiner_all_new_ordered_pairs_match_pinned_v13() {
	scalars := word_joiner_existing_simple_scalars()
	assert scalars.len == 1071
	assert text_boundary_grapheme_break_property(rune(0x2060)) == .control
	mut pair_count := 0
	mut other_count := 0
	mut control_count := 0
	mut ep_count := 0
	for scalar in scalars {
		property := text_boundary_grapheme_break_property(scalar)
		assert property in [.other, .control, .cr, .lf]
		if property == .other { other_count++ }
		if property == .control { control_count++ }
		if text_boundary_is_extended_pictographic(scalar) {
			assert scalar in [rune(0xa9), 0xae]
			ep_count++
		}
		for points in [[scalar, rune(0x2060)], [rune(0x2060), scalar]] {
			text := points.string()
			assert text_grapheme_boundaries(text) == [0, 1, 2]
			assert text_grapheme_boundaries(text) == word_joiner_reference_boundaries(text)
			pair_count++
		}
	}
	text := [rune(0x2060), 0x2060].string()
	assert text_grapheme_boundaries(text) == [0, 1, 2]
	assert text_grapheme_boundaries(text) == word_joiner_reference_boundaries(text)
	pair_count++
	assert pair_count == 2143
	assert other_count == 1034
	assert control_count == 35
	assert ep_count == 2
}

fn test_word_joiner_simple_sequences_keep_crlf_and_ep_control_boundaries() {
	for scalar in word_joiner_existing_simple_scalars() {
		points := [rune(0x2060), scalar, rune(0x2060), scalar, rune(0x2060)]
		text := points.string()
		assert text_grapheme_boundaries(text) == [0, 1, 2, 3, 4, 5]
		assert text_grapheme_boundaries(text) == word_joiner_reference_boundaries(text)
	}
	for points in [[rune(0x2060), 0x0d, 0x0a, 0x2060], [rune(0x0d), 0x2060, 0x0a],
		[rune(0x0d), 0x0a, 0x2060, 0x0d, 0x0a], [rune(0xa9), 0x2060, 0xae, 0x2060, 0xa9],
		[rune(0x2060), 0x2060, 0x2060, 0x0d, 0x0a, 0x2060]] {
		text := points.string()
		assert text_grapheme_boundaries(text) == word_joiner_reference_boundaries(text)
	}
	assert text_grapheme_boundaries([rune(0x2060), 0x0d, 0x0a, 0x2060].string()) == [
		0,
		1,
		3,
		4,
	]
	assert text_grapheme_boundaries([rune(0x0d), 0x2060, 0x0a].string()) == [0, 1, 2, 3]
	assert text_grapheme_boundaries([rune(0x0d), 0x0a, 0x2060, 0x0d, 0x0a].string()) == [
		0,
		2,
		3,
		5,
	]
}

fn test_word_joiner_complex_neighbors_preserve_whole_string_fallback_and_v13_quirks() {
	for neighbor in [rune(0x0600), 0x0308, 0x0483, 0x0487, 0x0488, 0x0489, 0x200d, 0xfe0f, 0x1f1e6,
		0x1100, 0x0903, 0x094d, 0x1f6d1, 0x10ffff, 0x2061, 0x2064, 0xfffd] {
		for points in [[rune(0x2060), neighbor], [neighbor, rune(0x2060)],
			[rune(0x61), 0x2060, neighbor, 0x2060, 0x430],
			[rune(0x0600), neighbor, 0x2060, 0x0d,
				0x0a]] {
			text := points.string()
			assert text_grapheme_boundaries(text) == word_joiner_reference_boundaries(text)
		}
	}
	// Existing V13 checks Prepend before the current Control property.
	assert text_grapheme_boundaries([rune(0x0600), 0x2060].string()) == [0, 2]
	assert text_grapheme_boundaries([rune(0x2060), 0x0600, 0x2060].string()) == [0, 1, 3]
	for text in ['👩‍👩‍👧‍👦⁠Русский', '🇷🇺⁠🇺🇦', 'а́⁠б',
		'क्‍ष⁠क्‌ष', '🛑́‍🛑⁠🛑‍🛑', [rune(0x1100), 0x1160, 0x11a8,
			0x2060].string()] {
		assert text_grapheme_boundaries(text) == word_joiner_reference_boundaries(text)
	}
	for bytes in [[u8(0xff), 0xe2, 0x81, 0xa0], [u8(0xe2), 0x81, 0xa0, 0xc0, 0xaf],
		[u8(0xed), 0xa0, 0x80, 0xe2, 0x81, 0xa0]] {
		text := bytes.bytestr()
		assert text_grapheme_boundaries(text) == word_joiner_reference_boundaries(text)
	}
}

fn test_word_joiner_actual_russian_title_keeps_owned_utf16_boundaries() {
	text := 'Вы обосрали мой любимый сыр! Ламбер, ну какого чёрта!⁠⁠10'
	expected := word_joiner_reference_boundaries(text)
	assert expected.len == text.runes().len + 1
	mut first := text_grapheme_boundaries(text)
	second := text_grapheme_boundaries(text)
	assert first == expected
	assert second == expected
	assert first.last() == utf16_length_for_line_box(text)
	assert voidptr(first.data) != voidptr(second.data)
	first[1] = 99
	assert second == expected
	for _ in 0 .. 3 {
		gc_collect()
	}
	assert second == expected
}

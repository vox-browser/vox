module layout

import strconv

fn general_reference_boundaries(text string) []int {
	mut result := [0]
	mut offset := 0
	for cluster in text.graphemes() {
		offset += utf16_length_for_line_box(cluster)
		result << offset
	}
	return result
}

fn assert_general_boundary_differential(text string) {
	expected := general_reference_boundaries(text)
	assert general_text_grapheme_boundaries(text.runes()) == expected
	assert text_grapheme_boundaries(text) == expected
}

fn test_general_grapheme_corpus_retains_all_current_v13_results_and_its_three_deviations() {
	// The three baseline differences are preserved, not silently repaired here:
	// U+0600 Prepend glues to CR, LF, and Control because V13 checks Prepend first.
	corpus := $embed_file('testdata/GraphemeBreakTest-13.0.0.txt').to_string()
	mut case_count := 0
	mut deviations := []int{}
	for line in corpus.split_into_lines() {
		body := line.all_before('#').trim_space()
		if body == '' { continue
		 }
		mut code_points := []rune{}
		mut official := []int{}
		mut offset := 0
		for token in body.fields() {
			if token == '÷' {
				official << offset
				continue
			}
			if token == '×' { continue
			 }
			code_point := rune(strconv.parse_uint(token, 16, 32) or { panic(err) })
			code_points << code_point
			offset += if code_point > 0xffff { 2 } else { 1 }
		}
		case_count++
		text := code_points.string()
		baseline := general_reference_boundaries(text)
		assert general_text_grapheme_boundaries(code_points) == baseline
		assert text_grapheme_boundaries(text) == baseline
		if baseline != official { deviations << case_count }
	}
	assert case_count == 602
	assert deviations == [207, 209, 211]
}

fn test_general_grapheme_class_triples_and_state_resets_match_v13() {
	classes := [rune(0x61), 0x0d, 0x0a, 0x01, 0x0308, 0x1f1e6, 0x1f1e7, 0x0600, 0x0903, 0x1100,
		0x1160, 0x11a8, 0xac00, 0xac01, 0x200d, 0x1f6d1, 0xfe0f, 0x2060, 0x094d, 0x1f3fb]
	for first in classes {
		for second in classes {
			for third in classes {
				assert_general_boundary_differential([first, second, third].string())
			}
		}
	}
	for text in ['🇦🇧🇨🇩🇪a🇫🇬🇭', '🛑́‍🛑a‍🛑',
		'🛑‍a🛑́‍🛑', 'á́‍🛑', 'ᄀ가ᅡᆨᆨ각각ᆨ', [
			rune(0x600),
			0x0d,
			0x0a,
			0x41,
		].string(),
		'क्‍षक्‌षक्‌' + [rune(0x0d), 0x0a].string() + 'ष', 'а⁠⁠10'] {
		assert_general_boundary_differential(text)
	}
	assert text_grapheme_boundaries([rune(0x600), 0x0d, 0x0a].string()) == [0, 3]
}

fn test_general_grapheme_property_range_edges_match_v13() {
	tables := [text_boundary_grapheme_control_ranges, text_boundary_grapheme_extend_ranges,
		text_boundary_grapheme_spacing_mark_ranges, text_boundary_grapheme_prepend_ranges,
		text_boundary_grapheme_extended_pictographic_ranges]
	for table in tables {
		for index in 0 .. table.len / 8 {
			edge := text_boundary_grapheme_range_value(table, index)
			for delta in [-1, 0, 1] {
				value := i64(edge) + delta
				if value < 0 || value > 0x10ffff || (value >= 0xd800 && value <= 0xdfff) { continue
				 }
				code_point := rune(value)
				for context in [[rune(0x61), code_point, rune(0x0308), rune(0x62)],
					[rune(0x0600), code_point, rune(0x0a)],
					[rune(0x1f6d1), rune(0x0308), rune(0x200d),
						code_point],
					[rune(0x1f1e6), code_point, rune(0x1f1e7)]] {
					assert_general_boundary_differential(context.string())
				}
			}
		}
	}
}

fn test_general_grapheme_supplementary_and_invalid_utf8_keep_decoder_offsets() {
	for text in ['', 'a😀b', '𐀀𐀁a', '👩‍👩‍👧‍👦', 'а\r\n😀б', 'а⁠⁠10'] {
		assert_general_boundary_differential(text)
	}
	inputs := [[u8(0xff)], [u8(0x80), 0x80], [u8(0xc0), 0xaf],
		[u8(0xed), 0xa0, 0x80], [u8(0xf4), 0x90, 0x80, 0x80],
		[u8(0xf5), 0x80, 0x80, 0x80], [u8(0xe2), 0x82], [u8(0xf0), 0x9f],
		[u8(0x61), 0xc0, 0xaf, 0x62], [u8(0xff), 0xcc, 0x81, 0x61]]
	for input in inputs {
		text := input.bytestr()
		assert_general_boundary_differential(text)
		decoded := text.runes()
		mut length := 0
		for code_point in decoded {
			length += if code_point > 0xffff { 2 } else { 1 }
		}
		result := general_text_grapheme_boundaries(decoded)
		assert result.last() == length
	}
	assert text_grapheme_boundaries([u8(0xed), 0xa0, 0x80].bytestr()) == [0, 1, 2, 3]
	assert text_grapheme_boundaries([u8(0xff), 0xcc, 0x81, 0x61].bytestr()) == [0, 2, 3]
	assert text_grapheme_boundaries('a😀b') == [0, 1, 3, 4]
}

fn test_general_grapheme_outputs_are_owned_and_survive_gc_and_input_mutation() {
	mut input := [rune(0x1f1e6), rune(0x1f1e7), rune(0x61)]
	mut first := general_text_grapheme_boundaries(input)
	second := general_text_grapheme_boundaries(input)
	assert first == [0, 4, 5]
	assert voidptr(first.data) != voidptr(second.data)
	input[0] = rune(0x61)
	assert first == [0, 4, 5]
	first[1] = 99
	assert second == [0, 4, 5]
	for _ in 0 .. 3 {
		gc_collect()
	}
	assert second == [0, 4, 5]
	assert general_text_grapheme_boundaries(input) == [0, 1, 3, 4]
	mut empty := general_text_grapheme_boundaries([]rune{})
	other_empty := general_text_grapheme_boundaries([]rune{})
	empty[0] = 7
	assert other_empty == [0]
}

fn test_general_grapheme_russian_word_joiners_and_complex_neighbors_keep_boundaries() {
	for text in [
		'Вы обосрали мой любимый сыр! Ламбер, ну какого чёрта!⁠⁠10',
		'Привет, мир! 👩‍👩‍👧‍👦 🇷🇺 Ёжик⁠⁠2',
		'Русский Latin –’ а́б' + [rune(0x0d), 0x0a].string() + '😀 next',
		[rune(0x600), 0x01].string(),
		[rune(0x600), 0x0a].string(),
		[rune(0x600), 0x0d].string(),
	] {
		assert_general_boundary_differential(text)
	}
}

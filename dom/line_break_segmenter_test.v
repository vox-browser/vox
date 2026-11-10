module dom

// 文文文文文文 followed by the code point under test and 字字, as in the WPT
// css-text-line-break-* pages. Reports whether a line may start with it.
fn line_break_test_breaks_before(code_point rune, mode LineBreakMode) bool {
	text := '文文文文文文${code_point.str()}字字'
	segmenter := Segmenter{
		segmented_text:  text
		granularity:     .line
		line_break_mode: mode
	}
	return 6 in segmenter.boundaries()
}

fn test_line_segmenter_breaks_between_ideographs_but_not_before_closing_punctuation() {
	segmenter := Segmenter{
		segmented_text: '日本語。字'
		granularity:    .line
	}
	assert segmenter.boundaries() == [0, 1, 2, 4, 5]
}

fn test_line_segmenter_uses_utf16_offsets_for_supplementary_ideographs() {
	segmenter := Segmenter{
		segmented_text: '𠀀𠀀'
		granularity:    .line
	}
	assert segmenter.boundaries() == [0, 2, 4]
}

fn test_strict_line_breaking_keeps_conditional_japanese_starters_with_the_previous_character() {
	for code_point in [rune(0x3041), 0x30a1, 0x30fc, 0x31f0, 0xff67, 0xff70] {
		assert !line_break_test_breaks_before(code_point, .strict)
		assert line_break_test_breaks_before(code_point, .normal)
		assert line_break_test_breaks_before(code_point, .loose)
		assert line_break_test_breaks_before(code_point, .loose_japanese)
		assert line_break_test_breaks_before(code_point, .loose_chinese)
	}
}

fn test_loose_line_breaking_allows_breaks_before_iteration_marks() {
	for code_point in [rune(0x3005), 0x303b, 0x309d, 0x309e, 0x30fd, 0x30fe] {
		assert !line_break_test_breaks_before(code_point, .normal)
		assert line_break_test_breaks_before(code_point, .loose)
		assert line_break_test_breaks_before(code_point, .loose_japanese)
		assert line_break_test_breaks_before(code_point, .loose_chinese)
	}
}

fn test_loose_chinese_and_japanese_line_breaking_allows_breaks_before_centered_punctuation_and_postfixes() {
	// Centered punctuation, CJK hyphens, and postfix characters.
	for code_point in [rune(0x30fb), 0xff1a, 0xff1b, 0xff65, 0x203c, 0x2047, 0x2048, 0x2049,
		0xff01, 0xff1f, 0x301c, 0x30a0, 0x00b0, 0x2030, 0x2032, 0x2033, 0x2035, 0x2103, 0x2109,
		0xfe6a, 0xff05, 0xffe0] {
		assert !line_break_test_breaks_before(code_point, .normal)
		assert !line_break_test_breaks_before(code_point, .loose)
		assert line_break_test_breaks_before(code_point, .loose_japanese)
		assert line_break_test_breaks_before(code_point, .loose_chinese)
	}
}

fn test_line_segmenter_clone_keeps_line_break_mode() {
	segmenter := &Segmenter{
		granularity:     .line
		line_break_mode: .loose_japanese
	}
	assert segmenter.clone().line_break_mode == .loose_japanese
}

fn test_line_break_language_reads_the_script_subtag_before_the_language() {
	for tag, expected in {
		'ko-Hani':             LineBreakLanguage.chinese
		'ja-Latn':             .other
		'zh-Latn':             .other
		'ja-Hans':             .chinese
		'zh-Hira':             .japanese
		'en-Jpan':             .japanese
		'en-Hant':             .chinese
		'en-Hanb':             .chinese
		'en-Bopo':             .chinese
		'en-Hrkt':             .japanese
		'en-Kana':             .japanese
		'ja-Hang':             .other
		'zh-Zzzz':             .other
		'JA-hAnS':             .chinese
		'zh-cmn-Jpan':         .japanese
		'ja-abc-def-ghi-Hans': .chinese
		'yue-Hant':            .chinese
	} {
		assert LineBreakLanguage.from_tag(tag) == expected, tag
	}
}

fn test_line_break_language_ignores_scripts_outside_the_script_position() {
	for tag, expected in {
		'ja':             LineBreakLanguage.japanese
		'ja-JP':          .japanese
		'JA-jp':          .japanese
		'zh':             .chinese
		'zh-Hant-TW':     .chinese
		'ja-x-Latn':      .japanese
		'ja-u-ca-hans':   .japanese
		'ja-JP-Latn':     .japanese
		'ja-1996-Latn':   .japanese
		'ja-fonipa-Latn': .japanese
		'de':             .other
		'en-x-Jpan':      .other
		'en-u-ca-jpan':   .other
		'abcd-xyz-Jpan':  .other
		'x-Jpan':         .other
		'jあ-Jpan':        .other
		'japanesee-Jpan': .other
		'':               .other
	} {
		assert LineBreakLanguage.from_tag(tag) == expected, tag
	}
}

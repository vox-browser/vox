module main

import dom
import html
import layout

// css/css-text/i18n/*/css-text-line-break-*: the box holds 文文文文文文, so
// the character under test either starts the second line (test and ref with
// <br> after the sixth 文 agree) or pulls the sixth 文 down with it (the ref
// with <br> after the fifth 文 agrees).
// The box holds exactly six 文 in whatever face the test environment selects,
// whose advance need not be 1em.
fn line_break_layout_box_width(language string) int {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}
		span{font-size:20px;line-height:20px;display:inline-block}</style>
		<span id="probe" lang="${language}">文文文文文文</span>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	element := document.get_element_by_id('probe') or { panic('missing probe') }
	return html.html_element_offset_width(unsafe { &dom.HTMLElement(element) }) + 2
}

fn line_break_layout_offsets(language string, line_break string, character string) (int, int, int) {
	width := line_break_layout_box_width(language)
	mut document := html.parse_document('<!doctype html><style>body{margin:0}
		div{font-size:20px;line-height:20px;width:${width}px}</style>
		<div lang="${language}" style="line-break:${line_break}">文文文文文文${character}字<span id="test">字</span></div>
		<div lang="${language}">文文文文文文<br>${character}字<span id="sixth">字</span></div>
		<div lang="${language}">文文文文文<br>文${character}字<span id="fifth">字</span></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	mut offsets := []int{}
	for id in ['test', 'sixth', 'fifth'] {
		element := document.get_element_by_id(id) or { panic('missing ${id}') }
		offsets << html.html_element_offset_left(unsafe { &dom.HTMLElement(element) })
	}
	return offsets[0], offsets[1], offsets[2]
}

fn line_break_layout_breaks_before(language string, line_break string, character string) bool {
	test, sixth, fifth := line_break_layout_offsets(language, line_break, character)
	assert sixth != fifth
	assert test == sixth || test == fifth, '${language} ${line_break} ${character}: ${test} ${sixth} ${fifth}'
	return test == sixth
}

fn test_line_break_strictness_decides_whether_small_kana_start_a_line() {
	for language in ['ja', 'zh', 'de', ''] {
		for character in ['ぁ', 'ー', 'ｧ'] {
			assert !line_break_layout_breaks_before(language, 'auto', character)
			assert !line_break_layout_breaks_before(language, 'strict', character)
			assert line_break_layout_breaks_before(language, 'normal', character)
			assert line_break_layout_breaks_before(language, 'loose', character)
		}
	}
}

fn test_loose_line_breaking_before_centered_punctuation_and_postfixes_needs_chinese_or_japanese() {
	for character in ['・', '：', '！', '％', '￠', '〜'] {
		for language in ['ja', 'zh', 'zh-Hant', 'en-Jpan'] {
			assert line_break_layout_breaks_before(language, 'loose', character), language
			assert !line_break_layout_breaks_before(language, 'normal', character), language
		}
		for language in ['de', ''] {
			assert !line_break_layout_breaks_before(language, 'loose', character), language
		}
	}
	// Iteration marks only need loose line breaking.
	for language in ['ja', 'de', ''] {
		assert line_break_layout_breaks_before(language, 'loose', '々')
		assert !line_break_layout_breaks_before(language, 'normal', '々')
	}
}

fn test_line_break_anywhere_wraps_inside_words() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}
		span{font:20px/20px monospace;display:inline-block}</style>
		<div style="width:0"><span id="anywhere" style="line-break:anywhere">abc-def</span>
		<span id="auto">abc-def</span><span id="char">a</span></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	mut widths := map[string]int{}
	for id in ['anywhere', 'auto', 'char'] {
		element := document.get_element_by_id(id) or { panic('missing ${id}') }
		widths[id] = html.html_element_offset_width(unsafe { &dom.HTMLElement(element) })
	}
	assert widths['anywhere'] == widths['char']
	assert widths['auto'] > widths['char'] * 3
}

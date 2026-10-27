module layout

import css
import dom
import html
import math
import platform

// Keep the original scan and allocation path independent of the cached fact.
fn safe_line_ascii_scan_oracle(node &Node, start int, length int,
	run &platform.GlyphRun) ?f32 {
	if run.font().font_rendering_policy != .chromium || run.text_type() != .ltr
		|| run.face() != .document {
		return none
	}
	text_node := node.as_text_node() or { return none }
	text := text_node.text_for_rendering()
	if !text.is_ascii() { return none }
	context := chromium_collapsed_context_text(text_node, text)
	if context.source_offsets.len > 0 { return none }
	letter := f32(resolved_text_spacing_for_node(node, .letter_spacing).to_double())
	word := f32(resolved_text_spacing_for_node(node, .word_spacing).to_double())
	return platform.shaped_text_safe_break_width(letter, word, context.text, start, length,
		run.font())
}

fn safe_line_ascii_verify_ranges(text_node &TextNode, expected string) {
	rendered := text_node.text_for_rendering()
	assert rendered == expected
	assert text_node.rendered_text_is_ascii_ == expected.is_ascii()
	node := unsafe { &Node(text_node) }
	font := &platform.Font{ family: 'Arial', point_size: 20, font_rendering_policy: .chromium }
	letter := f32(resolved_text_spacing_for_node(node, .letter_spacing).to_double())
	word := f32(resolved_text_spacing_for_node(node, .word_spacing).to_double())
	run := platform.shape_text_with_spacing(0, letter, word, rendered, font, .ltr).glyph_run
	mut accepted := 0
	for start in -1 .. rendered.len + 2 {
		for length in 0 .. rendered.len + 2 {
			expected_width := safe_line_ascii_scan_oracle(node, start, length, run)
			actual := chromium_cached_safe_line_end(node, start, length, run)
			if width := expected_width {
				assert math.f32_bits(actual or { panic('cached ASCII range rejected') }) == math.f32_bits(width)
				accepted++
			} else {
				assert actual == none
			}
		}
	}
	if expected.is_ascii() && expected.len > 0 && !expected.contains('  ') {
		assert accepted > 0
	}
}

fn test_safe_line_ascii_cache_follows_transformed_source_ranges() {
	mut document := html.parse_document('<!doctype html><p id="target" style="text-transform:uppercase">aß😀bc</p>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	target := document.get_element_by_id('target') or { panic('missing target') }
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(target, none))
	mut parent := BlockContainer.new(document, none, style)
	mut text := TextNode.new_generated(document, 'aß😀bc')
	parent.append_child(unsafe { &Node(text) })
	for range in [[1, 1], [1, 3], [4, 2], [2, 2], [0, 0]] {
		text.source_range_start_ = range[0]
		text.source_range_length_ = range[1]
		text.invalidate_text_for_rendering()
		expected := match range[0] {
			1 {
				if range[1] == 1 { 'SS' } else { 'SS😀' }
			}
			4 { 'BC' }
			2 { '😀' }
			else { '' }
		}
		safe_line_ascii_verify_ranges(text, expected)
	}
}

fn test_safe_line_ascii_cache_follows_live_dom_mutations() {
	mut document := html.parse_document('<!doctype html><p id="target">AV To Wa</p>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 300, 100) or { panic('missing layout') }
	assert result.root.is_viewport()
	target := document.get_element_by_id('target') or { panic('missing target') }
	mut source := (target.first_child() or { panic('missing text') }).as_character_data() or { panic('not text') }
	bridge := source.layout_node() or { panic('missing boundary') }
	text := unsafe { &TextNode(bridge.layout_handle) }
	for value in ['AV To Wa', 'é To', 'SS To', '👩‍💻', '', 'AV  To', 'A\tTo\nWa', 'a\u0301',
		'AV To Wa'] {
		source.set_data(value)
		safe_line_ascii_verify_ranges(text, value.replace('\t', ' ').replace('\n', ' '))
	}
}

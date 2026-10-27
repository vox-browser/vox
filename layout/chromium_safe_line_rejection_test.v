module layout

import css
import dom
import math
import platform

// Preserve the allocation-based eligibility rule as an independent oracle.
fn safe_line_reject_allocation_oracle(node &Node, start int, length int,
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

fn test_safe_line_source_map_rejection_matches_allocation_oracle() {
	font := &platform.Font{ family: 'Arial', point_size: 20, font_rendering_policy: .chromium }
	mut accepted := 0
	mut source_maps := 0
	mut preserved_spaces := 0
	for mode in ['normal', 'nowrap', 'pre', 'pre-wrap', 'pre-line', 'break-spaces'] {
		for text in ['AV To Wa', 'AV  To Wa', '  AV   To  ', 'AV\t  To\n Wa', 'Тест  To', '  '] {
			mut document := dom.Document.create(dom.url_about_blank())
			defer { document.finalize() }
			document.set_font_rendering_policy(.chromium)
			mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
			element.set_attribute_value('style', 'display:block;font:20px Arial;white-space:${mode};letter-spacing:0.25px;word-spacing:1px')
			computer := css.css_style_computer_for(document)
			style := computer.compute_style(dom.AbstractElement.new(element, none))
			mut container := BlockContainer.new(document, none, style)
			text_node := TextNode.new(document, document.create_text_node(text).as_node(), text)
			container.append_child(unsafe { &Node(text_node) })
			node := unsafe { &Node(text_node) }
			rendered := text_node.text_for_rendering()
			context := chromium_collapsed_context_text(text_node, rendered)
			if context.source_offsets.len > 0 { source_maps++ }
			if rendered.contains('  ') && context.source_offsets.len == 0 { preserved_spaces++ }
			letter := f32(resolved_text_spacing_for_node(node, .letter_spacing).to_double())
			word := f32(resolved_text_spacing_for_node(node, .word_spacing).to_double())
			run := platform.shape_text_with_spacing(0, letter, word, rendered, font, .ltr).glyph_run
			for start in -1 .. rendered.len + 2 {
				for length in 0 .. rendered.len + 2 {
					expected := safe_line_reject_allocation_oracle(node, start, length, run)
					actual := chromium_cached_safe_line_end(node, start, length, run)
					if width := expected {
						assert math.f32_bits(actual or { panic('eligible range rejected') }) == math.f32_bits(width)
						accepted++
					} else {
						assert actual == none
					}
				}
			}
		}
	}
	assert accepted > 0
	assert source_maps > 0
	assert preserved_spaces > 0
}

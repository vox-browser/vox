module layout

import css
import dom
import math
import platform

fn inline_context_test_style(document &dom.Document, declarations string) &css.ComputedProperties {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', declarations)
	computer := css.css_style_computer_for(document)
	return computer.compute_style(dom.AbstractElement.new(element, none))
}

fn test_inline_formatting_context_wraps_words_into_line_boxes() {
	document := dom.Document.create(dom.url_about_blank())
	style := inline_context_test_style(document,
		'display:block; width:80px; font:20px/24px SerenitySans')
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	dom_text := document.create_text_node('four four four')
	text_node := TextNode.new(document, dom_text.as_node(), 'four four four')
	container.append_child(unsafe { &Node(text_node) })
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	styled := unsafe { &Node(container) }.as_node_with_style() or { panic('style') }
	mut used := state.get_mutable(styled)
	used.set_content_width(CSSPixels.new(80))
	result := run_inline_formatting_context(mut state, container, mut used, .normal, AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(80)),
		AvailableSize.make_indefinite()))
	assert used.line_boxes.len == 3
	assert result.automatic_content_height.to_double() == 72
	for line in used.line_boxes {
		assert line.fragments_.len == 1
		assert line.fragments_[0].text() or { '' } == 'four'
	}
}

fn test_inline_formatting_context_collapses_source_indentation() {
	document := dom.Document.create(dom.url_about_blank())
	style := inline_context_test_style(document,
		'display:block; width:300px; font:20px/24px SerenitySans')
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	first_dom_text := document.create_text_node('Hello   ')
	second_dom_text := document.create_text_node('   world')
	first := TextNode.new(document, first_dom_text.as_node(), 'Hello   ')
	second := TextNode.new(document, second_dom_text.as_node(), '   world')
	container.append_child(unsafe { &Node(first) })
	container.append_child(unsafe { &Node(second) })
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	styled := unsafe { &Node(container) }.as_node_with_style() or { panic('style') }
	mut used := state.get_mutable(styled)
	used.set_content_width(CSSPixels.new(300))
	run_inline_formatting_context(mut state, container, mut used, .normal, AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(300)),
		AvailableSize.make_indefinite()))
	assert used.line_boxes.len == 1
	assert used.line_boxes[0].inline_length().to_double() == 112.890625
}

fn run_overflow_wrap_test(document &dom.Document, declaration string, text string,
	available_width AvailableSize) (&LayoutState, &UsedValues, InlineFormattingResult) {
	style := inline_context_test_style(document,
		'display:block; width:50px; font:20px/24px SerenitySans; ${declaration}')
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	dom_text := document.create_text_node(text)
	text_node := TextNode.new(document, dom_text.as_node(), text)
	container.append_child(unsafe { &Node(text_node) })
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	styled := unsafe { &Node(container) }.as_node_with_style() or { panic('style') }
	mut used := state.get_mutable(styled)
	used.set_content_width(CSSPixels.new(50))
	result := run_inline_formatting_context(mut state, container, mut used, .normal,
		AvailableSpace.new(available_width, AvailableSize.make_indefinite()))
	return state, used, result
}

fn test_inline_formatting_context_overflow_wrap_splits_at_grapheme_boundaries() {
	document := dom.Document.create(dom.url_about_blank())
	_, normal, _ := run_overflow_wrap_test(document, 'overflow-wrap:normal', 'abcdefghij',
		AvailableSize.make_definite(CSSPixels.new(50)))
	assert normal.line_boxes.len == 1
	assert normal.line_boxes[0].inline_length().to_double() > 50
	_, break_word, _ := run_overflow_wrap_test(document, 'overflow-wrap:break-word',
		'abcdefghij', AvailableSize.make_definite(CSSPixels.new(50)))
	assert break_word.line_boxes.len > 1
	for line in break_word.line_boxes {
		assert line.inline_length().to_double() <= 50
	}

	_, anywhere, _ := run_overflow_wrap_test(document, 'overflow-wrap:anywhere', 'abcádefghij',
		AvailableSize.make_definite(CSSPixels.new(50)))
	assert anywhere.line_boxes.len > 1
	mut rendered := ''
	for line in anywhere.line_boxes {
		assert line.inline_length().to_double() <= 50
		for fragment in line.fragments_ {
			part := fragment.text() or { '' }
			assert !part.starts_with('́')
			rendered += part
		}
	}
	assert rendered == 'abcádefghij'
}

fn test_inline_formatting_context_overflow_wrap_intrinsic_difference() {
	document := dom.Document.create(dom.url_about_blank())
	_, anywhere, anywhere_result := run_overflow_wrap_test(document, 'overflow-wrap:anywhere',
		'abcdefghij', AvailableSize.make_min_content())
	_, break_word, break_word_result := run_overflow_wrap_test(document,
		'overflow-wrap:break-word', 'abcdefghij', AvailableSize.make_min_content())
	assert anywhere.line_boxes.len == 10
	assert break_word.line_boxes.len == 1
	assert anywhere_result.automatic_content_width.to_double()
		< break_word_result.automatic_content_width.to_double()
}

fn test_inline_formatting_context_wraps_after_preserved_tab() {
	document := dom.Document.create(dom.url_about_blank())
	_, used, _ := run_overflow_wrap_test(document,
		'white-space:pre; text-wrap:wrap; tab-size:50px', '\tA',
		AvailableSize.make_definite(CSSPixels.new(50)))
	assert used.line_boxes.len == 2
	assert used.line_boxes[0].fragments().map(it.text() or { '' }) == ['\t']
	assert used.line_boxes[1].fragments().map(it.text() or { '' }) == ['A']
}

fn test_text_overflow_ellipsis_uses_the_containing_block_style_for_nested_inline_text() {
	document := dom.Document.create(dom.url_about_blank())
	container_style := inline_context_test_style(document,
		'display:block; width:75px; overflow:hidden; white-space:nowrap; text-overflow:ellipsis; font:16px/16px SerenitySans')
	inline_style := inline_context_test_style(document,
		'display:inline; white-space:nowrap; font:16px/16px SerenitySans')
	mut container := BlockContainer.new(document, none, container_style)
	container.set_children_are_inline(true)
	mut inline_node := InlineNode.new(document, none, inline_style)
	dom_text := document.create_text_node('This text gets an ellipsis')
	text_node := TextNode.new(document, dom_text.as_node(), 'This text gets an ellipsis')
	inline_node.append_child(unsafe { &Node(text_node) })
	container.append_child(unsafe { &Node(inline_node) })
	assign_layout_indexes(unsafe { &Node(container) })

	mut state := LayoutState.new()
	styled := unsafe { &Node(container) }.as_node_with_style() or { panic('style') }
	mut used := state.get_mutable(styled)
	used.set_content_width(CSSPixels.new(75))
	run_inline_formatting_context(mut state, container, mut used, .normal, AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(75)),
		AvailableSize.make_indefinite()))

	assert used.line_boxes.len == 1
	assert used.line_boxes[0].inline_length().to_double() == 75
	assert used.line_boxes[0].fragments_.len == 1
	glyph_run := used.line_boxes[0].fragments_[0].glyph_run() or { panic('glyph run') }
	assert glyph_run.glyphs_.len > 1
	assert glyph_run.glyphs_.last().code_point == u32(0x2026)
	assert glyph_run.bounding_box() == platform.glyph_run_bounding_box(glyph_run.font(),
		glyph_run.glyphs(), glyph_run.face())
	assert glyph_run.glyph_positions().len == glyph_run.glyphs().len * 2
}

fn test_text_overflow_ellipsis_preserves_preceding_inline_fragments() {
	document := dom.Document.create(dom.url_about_blank())
	container_style := inline_context_test_style(document,
		'display:block; width:75px; overflow:hidden; white-space:nowrap; text-overflow:ellipsis; font:16px/16px SerenitySans')
	inline_style := inline_context_test_style(document,
		'display:inline; white-space:nowrap; font:16px/16px SerenitySans')
	mut container := BlockContainer.new(document, none, container_style)
	container.set_children_are_inline(true)

	mut first_inline := InlineNode.new(document, none, inline_style)
	first_dom_text := document.create_text_node('Bold')
	first_text := TextNode.new(document, first_dom_text.as_node(), 'Bold')
	first_inline.append_child(unsafe { &Node(first_text) })
	container.append_child(unsafe { &Node(first_inline) })

	mut second_inline := InlineNode.new(document, none, inline_style)
	second_dom_text := document.create_text_node(' then more text here')
	second_text := TextNode.new(document, second_dom_text.as_node(), ' then more text here')
	second_inline.append_child(unsafe { &Node(second_text) })
	container.append_child(unsafe { &Node(second_inline) })

	mut third_inline := InlineNode.new(document, none, inline_style)
	third_dom_text := document.create_text_node(' hidden tail')
	third_text := TextNode.new(document, third_dom_text.as_node(), ' hidden tail')
	third_inline.append_child(unsafe { &Node(third_text) })
	container.append_child(unsafe { &Node(third_inline) })
	assign_layout_indexes(unsafe { &Node(container) })

	mut state := LayoutState.new()
	styled := unsafe { &Node(container) }.as_node_with_style() or { panic('style') }
	mut used := state.get_mutable(styled)
	used.set_content_width(CSSPixels.new(75))
	run_inline_formatting_context(mut state, container, mut used, .normal, AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(75)),
		AvailableSize.make_indefinite()))

	assert used.line_boxes.len == 1
	assert used.line_boxes[0].fragments_.len == 3
	assert used.line_boxes[0].fragments_[0].text() or { '' } == 'Bold'
	second_run := used.line_boxes[0].fragments_[1].glyph_run() or { panic('second glyph run') }
	assert second_run.glyphs_.last().code_point == u32(0x2026)
	assert !used.line_boxes[0].fragments_[1].is_fully_truncated()
	assert used.line_boxes[0].fragments_[2].is_fully_truncated()
}

// Blink's LineTruncator styles the text-overflow ellipsis with the block
// container: GitHub's gray commit links end in a dark ellipsis, and a block
// with a larger font draws a larger ellipsis after smaller inline text.
fn test_chromium_text_overflow_ellipsis_is_a_block_styled_item_after_the_truncated_text() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	container_style := inline_context_test_style(document,
		'display:block; width:75px; overflow:hidden; white-space:nowrap; text-overflow:ellipsis; font:24px/30px SerenitySans; color:rgb(255,0,0)')
	inline_style := inline_context_test_style(document,
		'display:inline; white-space:nowrap; font:14px/16px SerenitySans; color:rgb(0,0,255)')
	mut container := BlockContainer.new(document, none, container_style)
	container.set_children_are_inline(true)
	mut inline_node := InlineNode.new(document, none, inline_style)
	dom_text := document.create_text_node('This text gets an ellipsis')
	text_node := TextNode.new(document, dom_text.as_node(), 'This text gets an ellipsis')
	inline_node.append_child(unsafe { &Node(text_node) })
	container.append_child(unsafe { &Node(inline_node) })
	assign_layout_indexes(unsafe { &Node(container) })

	mut state := LayoutState.new()
	styled := unsafe { &Node(container) }.as_node_with_style() or { panic('style') }
	mut used := state.get_mutable(styled)
	used.set_content_width(CSSPixels.new(75))
	run_inline_formatting_context(mut state, container, mut used, .normal, AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(75)),
		AvailableSize.make_indefinite()))

	assert used.line_boxes.len == 1
	line := used.line_boxes[0]
	assert line.inline_length().to_double() == 75
	assert line.fragments_.len == 2
	text_fragment := line.fragments_[0]
	ellipsis := line.fragments_[1]
	text_run := text_fragment.glyph_run() or { panic('text run') }
	assert text_run.glyphs_.len > 1
	assert text_run.glyphs_.last().code_point != u32(0x2026)
	assert ellipsis.is_block_ellipsis()
	assert ellipsis.text() or { '' } == '…'
	assert voidptr(ellipsis.style_source()) == voidptr(unsafe { &Node(container) })
	ellipsis_run := ellipsis.glyph_run() or { panic('ellipsis run') }
	assert ellipsis_run.font().point_size == 24
	assert ellipsis.inline_offset() == text_fragment.inline_offset().plus(text_fragment.inline_length())
	assert ellipsis.inline_offset().plus(ellipsis.inline_length()).raw_value() <= CSSPixels.new(75).raw_value()
	// Both items share the line's baseline.
	assert ellipsis.block_offset().plus(ellipsis.baseline()) == text_fragment.block_offset().plus(text_fragment.baseline())
}

fn chromium_ellipsis_test_line(width int) (LineBox, &BlockContainer) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	container_style := inline_context_test_style(document,
		'display:block; width:${width}px; overflow:hidden; white-space:nowrap; text-overflow:ellipsis; font:16px/16px SerenitySans; color:rgb(255,0,0)')
	inline_style := inline_context_test_style(document,
		'display:inline; white-space:nowrap; font:16px/16px SerenitySans; color:rgb(0,0,255)')
	mut container := BlockContainer.new(document, none, container_style)
	container.set_children_are_inline(true)
	for text in ['and uint (', '#31234)'] {
		mut inline_node := InlineNode.new(document, none, inline_style)
		dom_text := document.create_text_node(text)
		text_node := TextNode.new(document, dom_text.as_node(), text)
		inline_node.append_child(unsafe { &Node(text_node) })
		container.append_child(unsafe { &Node(inline_node) })
	}
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	styled := unsafe { &Node(container) }.as_node_with_style() or { panic('style') }
	mut used := state.get_mutable(styled)
	used.set_content_width(CSSPixels.new(width))
	run_inline_formatting_context(mut state, container, mut used, .normal, AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)),
		AvailableSize.make_indefinite()))
	return used.line_boxes[0], container
}

// GitHub's file rows: when the overflowing link cannot keep a character next
// to the ellipsis, Blink hides it and truncates the preceding text so the
// ellipsis fits after it, instead of keeping that text whole.
fn test_chromium_text_overflow_hides_items_that_cannot_keep_a_character() {
	wide, _ := chromium_ellipsis_test_line(1000)
	first_width := wide.fragments_[0].inline_length().to_double()
	width := int(math.ceil(first_width)) + 4
	line, container := chromium_ellipsis_test_line(width)
	desc := line.fragments_.map('${it.text() or { "" }}@${it.inline_offset().to_double()}+${it.inline_length().to_double()} hidden=${it.is_fully_truncated()} ell=${it.is_block_ellipsis()}').join(' | ')
	assert line.fragments_.len == 3, 'width ${width} first ${first_width}: ${desc}'
	text := line.fragments_[0]
	ellipsis := line.fragments_[1]
	link := line.fragments_[2]
	assert !text.is_fully_truncated()
	assert link.is_fully_truncated(), 'width ${width} first ${first_width}: ${desc}'
	assert text.inline_length().to_double() < first_width
	assert ellipsis.is_block_ellipsis()
	assert voidptr(ellipsis.style_source()) == voidptr(unsafe { &Node(container) })
	assert ellipsis.inline_offset() == text.inline_offset().plus(text.inline_length())
	assert ellipsis.inline_offset().plus(ellipsis.inline_length()).raw_value() <= CSSPixels.new(width).raw_value()
}

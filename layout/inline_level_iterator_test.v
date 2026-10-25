module layout

import css
import dom

fn test_chromium_whitespace_lookahead_stops_at_a_hyphen_break() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	style := inline_iterator_test_style(document, 'div', 'display:block;font:16px Arial')
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	dom_text := document.create_text_node('end. -word')
	container.append_child(unsafe { &Node(TextNode.new(document, dom_text.as_node(), 'end. -word')) })
	_, mut iterator := make_inline_iterator(document, container, 300)
	for {
		item := iterator.next() or { panic('whitespace') }
		if !item.is_collapsible_whitespace { continue }
		sequence := iterator.next_non_whitespace_sequence_items()
		assert sequence.len == 1
		assert sequence[0].length_in_node == 1
		assert iterator.next_non_whitespace_sequence_width() == sequence[0].border_box_width()
		break
	}
}

fn inline_iterator_test_style(document &dom.Document, tag string, declarations string) &css.ComputedProperties {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', tag) or {
		panic('${err}')
	}
	element.set_attribute_value('style', declarations)
	computer := css.css_style_computer_for(document)
	return computer.compute_style(dom.AbstractElement.new(element, none))
}

fn make_inline_iterator(document &dom.Document, container &BlockContainer, width f64) (&LayoutState, &InlineLevelIterator) {
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	container_style := unsafe { &Node(container) }.as_node_with_style() or { panic('style') }
	mut container_values := state.get_mutable(container_style)
	container_values.set_content_width(CSSPixels.nearest_value_for(width))
	container_values.set_content_height(CSSPixels.new(100))
	iterator := InlineLevelIterator.new(mut state, container, container_values, .normal, AvailableSpace.new(AvailableSize.make_definite(CSSPixels.nearest_value_for(width)), AvailableSize.make_definite(CSSPixels.new(100))), none)
	_ = document
	return state, iterator
}

fn test_inline_level_iterator_generates_text_and_collapsible_space_items() {
	document := dom.Document.create(dom.url_about_blank())
	style := inline_iterator_test_style(document, 'div', 'display:block; font:20px SerenitySans; white-space-collapse:collapse')
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	dom_text := document.create_text_node('one   two')
	text_node := TextNode.new(document, dom_text.as_node(), 'one   two')
	container.append_child(unsafe { &Node(text_node) })
	_, mut iterator := make_inline_iterator(document, container, 300)
	first := iterator.next() or { panic('first') }
	space := iterator.next() or { panic('space') }
	second := iterator.next() or { panic('second') }
	assert first.type_ == .text
	assert first.length_in_node == 3
	assert first.width.to_double() == 35.875
	assert space.is_collapsible_whitespace
	assert space.width.to_double() == 10
	assert second.offset_in_node == 6
	assert iterator.next() == none
}

fn test_inline_level_iterator_applies_word_spacing_and_retains_shaped_whitespace() {
	document := dom.Document.create(dom.url_about_blank())
	style := inline_iterator_test_style(document, 'div', 'display:block; font:20px SerenitySans; word-spacing:6px')
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	dom_text := document.create_text_node('a b')
	text_node := TextNode.new(document, dom_text.as_node(), 'a b')
	container.append_child(unsafe { &Node(text_node) })
	_, mut iterator := make_inline_iterator(document, container, 300)
	_ = iterator.next() or { panic('first word') }
	space := iterator.next() or { panic('space') }
	assert space.width.to_double() == 16
	assert space.trailing_whitespace.length_in_code_units == 1
	assert space.trailing_whitespace.inline_size.to_double() == 16
}

fn test_inline_level_iterator_carries_nested_inline_edges_to_text() {
	document := dom.Document.create(dom.url_about_blank())
	container_style := inline_iterator_test_style(document, 'div', 'display:block')
	inline_style := inline_iterator_test_style(document, 'span', 'display:inline; margin-left:3px; border-left:2px solid; padding-left:4px; padding-right:5px')
	mut container := BlockContainer.new(document, none, container_style)
	container.set_children_are_inline(true)
	mut inline_node := InlineNode.new(document, none, inline_style)
	dom_text := document.create_text_node('x')
	text_node := TextNode.new(document, dom_text.as_node(), 'x')
	inline_node.append_child(unsafe { &Node(text_node) })
	container.append_child(unsafe { &Node(inline_node) })
	_, mut iterator := make_inline_iterator(document, container, 300)
	item := iterator.next() or { panic('text') }
	assert item.margin_start.to_double() == 3
	assert item.border_start.to_double() == 2
	assert item.padding_start.to_double() == 4
	assert item.padding_end.to_double() == 5
}

fn test_inline_level_iterator_emits_forced_break() {
	document := dom.Document.create(dom.url_about_blank())
	container_style := inline_iterator_test_style(document, 'div', 'display:block')
	break_style := inline_iterator_test_style(document, 'br', 'display:inline')
	mut container := BlockContainer.new(document, none, container_style)
	container.set_children_are_inline(true)
	mut break_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'br') or {
		panic('${err}')
	}
	break_node := BreakNode.new(document, break_element.as_node(), break_style)
	container.append_child(unsafe { &Node(break_node) })
	_, mut iterator := make_inline_iterator(document, container, 300)
	assert (iterator.next() or { panic('break') }).type_ == .forced_break
}

fn test_inline_level_iterator_does_not_carry_break_edges_to_the_next_line() {
	document := dom.Document.create(dom.url_about_blank())
	container_style := inline_iterator_test_style(document, 'div', 'display:block')
	break_style := inline_iterator_test_style(document, 'br',
		'display:inline; border-left:3px solid; padding-left:4px')
	mut container := BlockContainer.new(document, none, container_style)
	container.set_children_are_inline(true)
	mut break_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'br') or {
		panic('${err}')
	}
	break_node := BreakNode.new(document, break_element.as_node(), break_style)
	text := document.create_text_node('next')
	text_node := TextNode.new(document, text.as_node(), 'next')
	container.append_child(unsafe { &Node(break_node) })
	container.append_child(unsafe { &Node(text_node) })
	_, mut iterator := make_inline_iterator(document, container, 300)
	assert (iterator.next() or { panic('break') }).type_ == .forced_break
	next := iterator.next() or { panic('text after break') }
	assert next.type_ == .text
	assert next.border_start.to_double() == 0
	assert next.padding_start.to_double() == 0
}

fn test_inline_level_iterator_preserves_ltr_shaping_across_neutral_punctuation() {
	document := dom.Document.create(dom.url_about_blank())
	style := inline_iterator_test_style(document, 'div',
		'display:block; text-align:justify; font:20px SerenitySans')
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	dom_text := document.create_text_node("'full-justified'")
	text_node := TextNode.new(document, dom_text.as_node(), "'full-justified'")
	container.append_child(unsafe { &Node(text_node) })
	_, mut iterator := make_inline_iterator(document, container, 300)
	assert iterator.is_unidirectional_left_to_right
	first := iterator.next() or { panic('first punctuation run') }
	second := iterator.next() or { panic('second punctuation run') }
	assert first.length_in_node == 6
	assert second.length_in_node == 10
	assert (first.glyph_run or { panic('first glyph run') }).text_type() == .ltr
	assert (second.glyph_run or { panic('second glyph run') }).text_type() == .ltr
	assert iterator.next() == none

	mut mixed_container := BlockContainer.new(document, none, style)
	mixed_container.set_children_are_inline(true)
	mixed_dom_text := document.create_text_node('א-a')
	mixed_text := TextNode.new(document, mixed_dom_text.as_node(), 'א-a')
	mixed_container.append_child(unsafe { &Node(mixed_text) })
	_, mixed_iterator := make_inline_iterator(document, mixed_container, 300)
	assert !mixed_iterator.is_unidirectional_left_to_right
}

fn inline_isolate_test_iterator(document &dom.Document, declarations string) &InlineLevelIterator {
	style := inline_iterator_test_style(document, 'div', 'display:block; font:20px SerenitySans')
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	mut inline_node := InlineNode.new(document, none, inline_iterator_test_style(document, 'div',
		declarations))
	dom_text := document.create_text_node('x')
	inline_node.append_child(unsafe { &Node(TextNode.new(document, dom_text.as_node(), 'x')) })
	container.append_child(unsafe { &Node(inline_node) })
	dom_after := document.create_text_node(' to view.')
	container.append_child(unsafe { &Node(TextNode.new(document, dom_after.as_node(), ' to view.')) })
	_, iterator := make_inline_iterator(document, container, 400)
	return iterator
}

// The UA style sheet isolates every div and every element with a dir
// attribute. 4chan's inline OP post is such a div; under the Chromium policy an
// LTR isolate of LTR text keeps its paragraph unidirectional, so " to view."
// still kerns its "w.". The LibWeb policy keeps upstream's classification.
fn test_inline_level_iterator_keeps_chromium_ltr_isolates_unidirectional() {
	mut document := dom.Document.create(dom.url_about_blank())
	assert !inline_isolate_test_iterator(document, 'display:inline; unicode-bidi:isolate').is_unidirectional_left_to_right
	document.set_font_rendering_policy(.chromium)
	assert inline_isolate_test_iterator(document, 'display:inline; unicode-bidi:isolate').is_unidirectional_left_to_right
	assert !inline_isolate_test_iterator(document, 'display:inline; unicode-bidi:embed').is_unidirectional_left_to_right
	assert !inline_isolate_test_iterator(document, 'display:inline; unicode-bidi:isolate; direction:rtl').is_unidirectional_left_to_right
}

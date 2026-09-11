module layout

import css
import dom

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

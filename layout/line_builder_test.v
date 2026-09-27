module layout

import css
import dom
import platform

fn line_builder_test_style(document &dom.Document, declarations string) &css.ComputedProperties {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', declarations)
	computer := css.css_style_computer_for(document)
	return computer.compute_style(dom.AbstractElement.new(element, none))
}

fn test_line_builder_wraps_and_aligns_fragments() {
	document := dom.Document.create(dom.url_about_blank())
	style := line_builder_test_style(document,
		'display:block; width:100px; font-size:20px; line-height:24px; text-align:center')
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	dom_text := document.create_text_node('abcdefgh')
	text_node := TextNode.new(document, dom_text.as_node(), 'abcdefgh')
	container.append_child(unsafe { &Node(text_node) })
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	container_styled := unsafe { &Node(container) }.as_node_with_style() or { panic('style') }
	mut values := state.get_mutable(container_styled)
	values.set_content_width(CSSPixels.new(100))
	font := &platform.Font{
		family:     'Test'
		point_size: 20
	}
	run_a := platform.shape_text(0, 0, 'abcd', font, .ltr)
	run_b := platform.shape_text(0, 0, 'efgh', font, .ltr)
	mut builder := LineBuilder.new(mut state, container, values,
		AvailableSize.make_definite(CSSPixels.new(60)), .ltr, .horizontal_tb)
	builder.append_text_chunk(text_node, 0, 4, CSSPixels.new(0), CSSPixels.new(0),
		CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(40), CSSPixels.new(24), run_a)
	assert builder.break_if_needed(CSSPixels.new(40))
	builder.append_text_chunk(text_node, 4, 4, CSSPixels.new(0), CSSPixels.new(0),
		CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(40), CSSPixels.new(24), run_b)
	builder.update_last_line()
	assert values.line_boxes.len == 2
	assert values.line_boxes[0].fragments_[0].inline_offset().to_double() == 10
	assert values.line_boxes[1].fragments_[0].inline_offset().to_double() == 10
	fragment_metrics := layout_font_metrics_for_node(values.line_boxes[0].fragments_[0].layout_node_)
	assert values.line_boxes[0].fragments_[0].block_length() == normal_line_height_for_font_metrics(fragment_metrics)
	assert values.line_boxes[0].height().to_double() == 24
	assert values.line_boxes[1].bottom().to_double() == 48
}

fn test_line_builder_aligns_rtl_overflow_to_inline_start() {
	document := dom.Document.create(dom.url_about_blank())
	style := line_builder_test_style(document,
		'display:block; width:100px; direction:rtl; text-align:center; font-size:20px; line-height:24px')
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	dom_text := document.create_text_node('abcdefgh')
	text_node := TextNode.new(document, dom_text.as_node(), 'abcdefgh')
	container.append_child(unsafe { &Node(text_node) })
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	container_styled := unsafe { &Node(container) }.as_node_with_style() or { panic('style') }
	mut values := state.get_mutable(container_styled)
	values.set_content_width(CSSPixels.new(100))
	font := &platform.Font{
		family:     'Test'
		point_size: 20
	}
	run := platform.shape_text(0, 0, 'abcdefgh', font, .rtl)
	mut builder := LineBuilder.new(mut state, container, values,
		AvailableSize.make_definite(CSSPixels.new(100)), .rtl, .horizontal_tb)
	builder.append_text_chunk(text_node, 0, 8, CSSPixels.new(0), CSSPixels.new(0),
		CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(140), CSSPixels.new(24), run)
	builder.update_last_line()
	assert values.line_boxes.len == 1
	assert values.line_boxes[0].fragments_[0].inline_offset().to_double() == -40
}

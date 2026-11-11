module layout

import css
import dom

fn clearing_break_builder() (&LineBuilder, &UsedValues) {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	element.set_attribute_value('style', 'display:block;width:100px;line-height:20px')
	style := css.StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	mut container := BlockContainer.new(document, element.as_node(), style)
	container.set_children_are_inline(true)
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	mut values := state.get_mutable(unsafe { &NodeWithStyle(container) })
	values.set_content_width(CSSPixels.new(100))
	builder := LineBuilder.new(mut state, container, values,
		AvailableSize.make_definite(CSSPixels.new(100)), .ltr, .horizontal_tb)
	return builder, values
}

fn test_clearing_break_grows_last_nonempty_line_past_intervening_empty_lines() {
	mut builder, mut values := clearing_break_builder()
	values.line_boxes = [
		LineBox{has_break_: true, bottom_: CSSPixels.new(30), block_length_: CSSPixels.new(20),
			baseline_: CSSPixels.new(15), font_box_baseline_: CSSPixels.new(25)},
		LineBox{}, LineBox{},
	]
	builder.current_block_offset = CSSPixels.new(100)
	builder.did_introduce_clearance(CSSPixels.new(100))
	assert values.line_boxes[0].bottom_.to_double() == 100
	assert values.line_boxes[0].block_length_.to_double() == 90
	assert values.line_boxes[0].baseline_.to_double() == 15
	font_baseline := values.line_boxes[0].font_box_baseline_ or { panic('missing font baseline') }
	assert font_baseline.to_double() == 25
	assert values.line_boxes[1].block_length_.to_double() == 0
	assert builder.current_block_offset.to_double() == 100
}

fn test_clearing_break_keeps_existing_line_extent_and_later_offset() {
	mut builder, mut values := clearing_break_builder()
	values.line_boxes = [LineBox{has_break_: true, bottom_: CSSPixels.new(120),
		block_length_: CSSPixels.new(30)}, LineBox{}]
	builder.current_block_offset = CSSPixels.new(140)
	builder.did_introduce_clearance(CSSPixels.new(100))
	assert values.line_boxes[0].bottom_.to_double() == 120
	assert values.line_boxes[0].block_length_.to_double() == 30
	assert builder.current_block_offset.to_double() == 140
}

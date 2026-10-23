module html

import editing
import dom

fn mark_visible_position_inline(element &dom.Element) {
	mut mutable_element := unsafe { &dom.Element(element) }
	mutable_element.set_computed_properties(none, &dom.CSSComputedProperties_{
		display_: dom.CSSDisplay_{
			is_inline_outside_: true
			is_flow_inside_: true
		}
	})
}

fn attach_rendered_text_for_visible_position(text_node &dom.Node) {
	mut mutable_text_node := unsafe { &dom.Node(text_node) }
	mutable_text_node.set_layout_node(&dom.LayoutNode{
		is_text_node_: true
		visual_lines_data_: &dom.LayoutVisualLines{ values: [dom.VisualLine{
			start_offset: 0
			end_offset: text_node.length()
			end_offset_with_trailing_whitespace: text_node.length()
			has_fragments: true
			caret_stops: [dom.VisualCaretStop{ offset: 0, inline_coordinate: 0 }, dom.VisualCaretStop{
				offset: text_node.length()
				inline_coordinate: f64(text_node.length())
			}]
		}] }
	})
}

fn test_visible_position_keeps_dom_boundary_and_canonical_deep_equivalent() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><b>ab</b><i>cd</i></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	bold := host.as_node().first_child()?.as_element() or { panic('missing bold') }
	italic := host.as_node().last_child()?.as_element() or { panic('missing italic') }
	mark_visible_position_inline(bold)
	mark_visible_position_inline(italic)
	first_text := bold.as_node().first_child() or { panic('missing first text') }
	second_text := italic.as_node().first_child() or { panic('missing second text') }
	attach_rendered_text_for_visible_position(first_text)
	attach_rendered_text_for_visible_position(second_text)

	position := editing.VisiblePosition.create(document, dom.BoundaryPoint{
		node: host.as_node()
		offset: 0
	})
	boundary := position.boundary()
	assert voidptr(boundary.node) == voidptr(host.as_node())
	assert boundary.offset == 0
	deep := position.deep_equivalent()
	assert voidptr(deep.node) == voidptr(first_text)
	assert deep.offset == 0
	next := position.next() or { panic('missing next position') }
	next_deep := next.deep_equivalent()
	assert voidptr(next_deep.node) == voidptr(first_text)
	assert next_deep.offset == 1
	has_no_previous := position.previous() == none
	assert has_no_previous
}

fn test_visible_position_detects_paragraph_and_block_edges() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable>A<br>B</div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	first_text := host.as_node().first_child() or { panic('missing first text') }
	last_text := host.as_node().last_child() or { panic('missing last text') }
	attach_rendered_text_for_visible_position(first_text)
	attach_rendered_text_for_visible_position(last_text)

	first_start := editing.VisiblePosition.create(document, dom.BoundaryPoint{
		node: first_text
		offset: 0
	})
	first_end := editing.VisiblePosition.create(document, dom.BoundaryPoint{
		node: first_text
		offset: 1
	})
	last_start := editing.VisiblePosition.create(document, dom.BoundaryPoint{
		node: last_text
		offset: 0
	})
	last_end := editing.VisiblePosition.create(document, dom.BoundaryPoint{
		node: last_text
		offset: 1
	})

	assert first_start.is_start_of_paragraph()
	assert first_start.is_start_of_containing_block()
	assert first_end.is_end_of_paragraph()
	assert !first_end.is_end_of_containing_block()
	assert last_start.is_start_of_paragraph()
	assert !last_start.is_start_of_containing_block()
	assert last_end.is_end_of_paragraph()
	assert last_end.is_end_of_containing_block()
}

fn test_visible_position_treats_trailing_break_as_block_edge() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable>A<br></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	text := host.as_node().first_child() or { panic('missing text') }
	attach_rendered_text_for_visible_position(text)
	position := editing.VisiblePosition.create(document, dom.BoundaryPoint{
		node: host.as_node()
		offset: 1
	})

	assert position.is_end_of_paragraph()
	assert position.is_end_of_containing_block()
}

fn test_visible_position_retains_atomic_inline_block_owned_caret() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><img></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	image := host.as_node().first_child() or { panic('missing image') }
	mut mutable_image := unsafe { &dom.Node(image) }
	mutable_image.set_layout_node(&dom.LayoutNode{
		is_atomic_inline_: true
	})
	position := editing.VisiblePosition.create(document, dom.BoundaryPoint{
		node: host.as_node()
		offset: 0
	})

	deep := position.deep_equivalent()
	assert voidptr(deep.node) == voidptr(host.as_node())
	assert deep.offset == 0
	assert !position.is_before_or_after_containing_block()
}

module html

import editing
import dom

fn paragraph_operation_fixture() (&dom.Document, &dom.Element, &dom.Node) {
	document := parse_document('<!doctype html><body><div id="block" class="paragraph"><b id="bold">A<i id="italic">BC</i>D</b>E</div></body>')
	block := document.get_element_by_id('block') or { panic('missing block') }
	italic := document.get_element_by_id('italic') or { panic('missing italic') }
	text := italic.as_node().first_child() or { panic('missing text') }
	return document, block, text
}

fn test_split_inline_ancestors_clones_wrappers_around_text_boundary() {
	_, block, text := paragraph_operation_fixture()
	boundary := editing.split_inline_ancestors_at_boundary(dom.BoundaryPoint{
		node: text
		offset: 1
	}, block.as_node())

	assert boundary == dom.BoundaryPoint{ node: block.as_node(), offset: 1 }
	assert block.as_node().child_count() == 3
	left := block.as_node().child_at_index(0)?.as_element() or { panic('missing left wrapper') }
	right := block.as_node().child_at_index(1)?.as_element() or { panic('missing right wrapper') }
	assert left.outer_html()! == '<b id="bold">A<i id="italic">B</i></b>'
	assert right.outer_html()! == '<b id="bold"><i id="italic">C</i>D</b>'
}

fn test_split_inline_ancestors_hoists_edge_without_empty_clone() {
	_, block, text := paragraph_operation_fixture()
	boundary := editing.split_inline_ancestors_at_boundary(dom.BoundaryPoint{
		node: text
		offset: 0
	}, block.as_node())

	assert boundary == dom.BoundaryPoint{ node: block.as_node(), offset: 1 }
	left := block.as_node().child_at_index(0)?.as_element() or { panic('missing left wrapper') }
	right := block.as_node().child_at_index(1)?.as_element() or { panic('missing right wrapper') }
	assert left.outer_html()! == '<b id="bold">A</b>'
	assert right.outer_html()! == '<b id="bold"><i id="italic">BC</i>D</b>'
}

fn test_split_containing_block_moves_suffix_to_shallow_clone() {
	_, block, text := paragraph_operation_fixture()
	right_node := editing.split_containing_block_at_boundary(dom.BoundaryPoint{
		node: text
		offset: 1
	}, block.as_node())
	right := right_node.as_element() or { panic('right block is not an element') }

	assert right_node.parent()? == block.as_node().parent()?
	assert right_node.index() == block.as_node().index() + 1
	assert block.outer_html()! == '<div id="block" class="paragraph"><b id="bold">A<i id="italic">B</i></b></div>'
	assert right.outer_html()! == '<div id="block" class="paragraph"><b id="bold"><i id="italic">C</i>D</b>E</div>'
}

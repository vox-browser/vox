module editing

import dom

fn test_optional_editing_nodes_compare_identity() {
	mut document := dom.Document.create_for_fragment_parsing()
	defer { document.finalize() }
	first := document.create_text_node('same').as_node()
	// A shallow value copy has the same record contents and a distinct identity.
	copy := *first
	second := &dom.Node{ ...copy }
	assert optional_nodes_are_same(none, none)
	assert optional_nodes_are_same(first, first)
	assert !optional_nodes_are_same(first, second)
	assert !optional_nodes_are_same(first, none)
	assert !optional_nodes_are_same(none, first)
}

fn test_end_of_paragraph_requires_the_actual_ancestor() {
	mut document := dom.Document.create_for_fragment_parsing()
	defer { document.finalize() }
	first := document.create_text_node('same').as_node()
	copy := *first
	second := &dom.Node{ ...copy }
	boundary := dom.BoundaryPoint{ node: first, offset: first.length() }
	assert is_at_end_of(boundary, first)
	assert !is_at_end_of(boundary, second)
	assert !is_at_end_of(dom.BoundaryPoint{ node: first, offset: 0 }, first)
}

fn test_restoring_a_trailing_break_moves_only_the_requested_node() {
	mut document := dom.Document.create_for_fragment_parsing()
	defer { document.finalize() }
	block := document.create_element('p') or { panic(err) }
	source := document.create_element('p') or { panic(err) }
	first := document.create_element('br') or { panic(err) }
	second := document.create_element('br') or { panic(err) }
	mut block_node := block.as_node()
	mut source_node := source.as_node()
	block_node.append_child(first.as_node()) or { panic(err) }
	source_node.append_child(second.as_node()) or { panic(err) }
	restore_trailing_break(block.as_node(), first.as_node())
	assert block.as_node().child_count() == 1
	restore_trailing_break(block.as_node(), second.as_node())
	assert source.as_node().child_count() == 0
	assert block.as_node().child_count() == 2
	assert voidptr(block.as_node().first_child() or { panic('missing first break') }) == voidptr(first.as_node())
	assert voidptr(block.as_node().last_child() or { panic('missing restored break') }) == voidptr(second.as_node())
}

fn test_visible_sibling_scan_stops_at_the_actual_block() {
	mut document := dom.Document.create_for_fragment_parsing()
	defer { document.finalize() }
	block := document.create_element('p') or { panic(err) }
	first := document.create_text_node('first').as_node()
	last := document.create_text_node('last').as_node()
	mut block_node := block.as_node()
	block_node.append_child(first) or { panic(err) }
	block_node.append_child(last) or { panic(err) }
	copy := *first
	other := &dom.Node{ ...copy }
	assert !has_sibling_toward(first, first, .forward)
	assert has_sibling_toward(first, other, .forward)
	assert has_sibling_toward(first, block.as_node(), .forward)
	assert has_sibling_toward(last, block.as_node(), .backward)
	assert !has_sibling_toward(last, block.as_node(), .forward)
}

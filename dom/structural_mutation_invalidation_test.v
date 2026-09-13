module dom

fn structural_test_element(document &Document, name string) &Element {
	return document.create_element_ns('http://www.w3.org/1999/xhtml', name) or { panic(err) }
}

fn clear_structural_test_style_flags(elements ...&Element) {
	for element in elements {
		mut node := element.as_node()
		node.set_needs_style_update_internal(false)
		node.set_entire_subtree_needs_style_update(false)
	}
}

fn test_first_child_invalidation_targets_only_the_leading_element_transition() {
	document := Document.create(url_about_blank())
	mut parent := structural_test_element(document, 'main')
	inserted := structural_test_element(document, 'i')
	mut first := structural_test_element(document, 'a')
	mut second := structural_test_element(document, 'b')
	mut parent_node := parent.as_node()
	parent_node.append_child(inserted.as_node()) or { panic(err) }
	parent_node.append_child(document.create_text_node('separator').as_node()) or { panic(err) }
	parent_node.append_child(first.as_node()) or { panic(err) }
	parent_node.append_child(second.as_node()) or { panic(err) }
	first.set_affected_by_first_child_pseudo_class(true)
	second.set_affected_by_first_child_pseudo_class(true)
	clear_structural_test_style_flags(first, second)

	invalidate_structurally_affected_siblings(inserted.as_node(), .node_insert_before)
	assert first.needs_style_update()
	assert !second.needs_style_update()
}

fn test_last_child_invalidation_targets_only_the_trailing_element_transition() {
	document := Document.create(url_about_blank())
	mut parent := structural_test_element(document, 'main')
	mut first := structural_test_element(document, 'a')
	mut last := structural_test_element(document, 'b')
	inserted := structural_test_element(document, 'i')
	mut parent_node := parent.as_node()
	parent_node.append_child(first.as_node()) or { panic(err) }
	parent_node.append_child(last.as_node()) or { panic(err) }
	parent_node.append_child(document.create_text_node('separator').as_node()) or { panic(err) }
	parent_node.append_child(inserted.as_node()) or { panic(err) }
	first.set_affected_by_last_child_pseudo_class(true)
	last.set_affected_by_last_child_pseudo_class(true)
	clear_structural_test_style_flags(first, last)

	invalidate_structurally_affected_siblings(inserted.as_node(), .node_remove)
	assert !first.needs_style_update()
	assert last.needs_style_update()
}

fn test_positional_pseudos_still_invalidate_every_affected_sibling() {
	document := Document.create(url_about_blank())
	mut parent := structural_test_element(document, 'main')
	mut previous_first := structural_test_element(document, 'a')
	mut previous_second := structural_test_element(document, 'b')
	mutated := structural_test_element(document, 'i')
	mut next_first := structural_test_element(document, 'b')
	mut next_second := structural_test_element(document, 'a')
	mut parent_node := parent.as_node()
	for child in [previous_first, previous_second, mutated, next_first, next_second] {
		parent_node.append_child(child.as_node()) or { panic(err) }
	}
	previous_first.set_affected_by_backward_positional_pseudo_class(true)
	previous_second.set_affected_by_backward_positional_pseudo_class(true)
	next_first.set_affected_by_forward_positional_pseudo_class(true)
	next_second.set_affected_by_forward_positional_pseudo_class(true)
	clear_structural_test_style_flags(previous_first, previous_second, next_first, next_second)

	invalidate_structurally_affected_siblings(mutated.as_node(), .node_insert_before)
	assert previous_first.needs_style_update()
	assert previous_second.needs_style_update()
	assert next_first.needs_style_update()
	assert next_second.needs_style_update()
}

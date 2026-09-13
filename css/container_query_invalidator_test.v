module css

import dom

fn container_query_test_element(document &dom.Document, name string) &dom.Element {
	return document.create_element_ns('http://www.w3.org/1999/xhtml', name) or { panic('${err}') }
}

fn clear_container_query_test_style_flags(elements ...&dom.Element) {
	for element in elements {
		mut mutable_element := unsafe { &dom.Element(element) }
		mutable_element.set_needs_style_update(false)
		mut node := unsafe { &dom.Node(element.as_node()) }
		node.set_child_needs_style_update(false)
	}
}

fn test_size_container_invalidation_marks_only_dependent_dom_descendants() {
	document := dom.Document.create(dom.url_about_blank())
	mut container := container_query_test_element(document, 'div')
	mut dependent := container_query_test_element(document, 'span')
	unrelated := container_query_test_element(document, 'b')
	mut nested := container_query_test_element(document, 'i')
	mut container_node := container.as_node()
	mut dependent_node := dependent.as_node()
	container_node.append_child(dependent.as_node())!
	container_node.append_child(unrelated.as_node())!
	dependent_node.append_child(nested.as_node())!
	clear_container_query_test_style_flags(container, dependent, unrelated, nested)
	dependent.set_style_depends_on_size_container_query()
	nested.set_style_depends_on_size_container_query()

	// container-type alone is intentionally insufficient: the fast-path flag is
	// set only after something actually resolves against this container.
	invalidate_descendant_styles_depending_on_size_container_query(container)
	assert !dependent.needs_style_update()
	assert !nested.needs_style_update()
	assert document.style_invalidation_counters().size_query_container_scan_visits == 0

	container.set_is_size_query_container()
	invalidate_descendant_styles_depending_on_size_container_query(container)
	assert dependent.needs_style_update()
	assert nested.needs_style_update()
	assert !unrelated.needs_style_update()
	assert document.style_invalidation_counters().size_query_container_scan_visits == 3
}

fn test_size_container_invalidation_walks_shadow_and_assigned_flat_tree_children() {
	document := dom.Document.create(dom.url_about_blank())
	mut container := container_query_test_element(document, 'div')
	mut light_unassigned := container_query_test_element(document, 'p')
	mut light_assigned := container_query_test_element(document, 'span')
	mut container_node := container.as_node()
	container_node.append_child(light_unassigned.as_node())!
	container_node.append_child(light_assigned.as_node())!
	container.attach_a_shadow_root(.open, false, false, false, .named)!
	shadow_root := container.shadow_root() or { panic('missing shadow root') }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut shadow_dependent := container_query_test_element(document, 'b')
	mut slot_element := container_query_test_element(document, 'slot')
	shadow_node.append_child(shadow_dependent.as_node())!
	shadow_node.append_child(slot_element.as_node())!
	mut slot := unsafe { &dom.HTMLSlotElement(slot_element) }
	slot.set_assigned_nodes([light_assigned.as_node()])

	clear_container_query_test_style_flags(container, light_unassigned, light_assigned, shadow_dependent, slot_element)
	container.set_is_size_query_container()
	light_unassigned.set_style_depends_on_size_container_query()
	light_assigned.set_style_depends_on_size_container_query()
	shadow_dependent.set_style_depends_on_size_container_query()

	invalidate_descendant_styles_depending_on_size_container_query(container)
	assert shadow_dependent.needs_style_update()
	assert light_assigned.needs_style_update()
	assert !light_unassigned.needs_style_update()
	assert document.style_invalidation_counters().size_query_container_scan_visits == 3
}

fn test_style_container_invalidation_marks_only_dependent_shadow_including_descendants() {
	document := dom.Document.create(dom.url_about_blank())
	mut container := container_query_test_element(document, 'div')
	mut dependent := container_query_test_element(document, 'span')
	unrelated := container_query_test_element(document, 'b')
	mut light_child := container_query_test_element(document, 'i')
	mut container_node := container.as_node()
	container_node.append_child(dependent.as_node())!
	container_node.append_child(unrelated.as_node())!
	container_node.append_child(light_child.as_node())!
	container.attach_a_shadow_root(.open, false, false, false, .named)!
	shadow_root := container.shadow_root() or { panic('missing shadow root') }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut shadow_dependent := container_query_test_element(document, 'em')
	shadow_node.append_child(shadow_dependent.as_node())!

	clear_container_query_test_style_flags(container, dependent, unrelated, light_child,
		shadow_dependent)
	dependent.set_style_depends_on_style_container_query()
	light_child.set_style_depends_on_style_container_query()
	shadow_dependent.set_style_depends_on_style_container_query()
	container.invalidate_descendant_styles_depending_on_style_container_query()
	assert !dependent.needs_style_update()
	assert !light_child.needs_style_update()
	assert !shadow_dependent.needs_style_update()
	assert document.style_invalidation_counters().style_query_container_scans == 0

	container.set_is_style_query_container()
	container.invalidate_descendant_styles_depending_on_style_container_query()

	assert dependent.needs_style_update()
	assert light_child.needs_style_update()
	assert shadow_dependent.needs_style_update()
	assert !unrelated.needs_style_update()
	assert document.style_invalidation_counters().style_query_container_scans == 1
}

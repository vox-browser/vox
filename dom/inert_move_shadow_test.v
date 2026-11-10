module dom

fn inert_move_element(document &Document, name string) &Element {
	return document.create_element_ns('http://www.w3.org/1999/xhtml', name) or { panic(err) }
}

fn inert_append(parent &Node, child &Node) {
	mut mutable_parent := unsafe { &Node(parent) }
	mutable_parent.append_child(child) or { panic(err) }
}

fn inert_move(parent &Node, child &Node) {
	mut mutable_parent := unsafe { &Node(parent) }
	mut mutable_child := unsafe { &Node(child) }
	mutable_child.move_node(mut mutable_parent, none) or { panic(err) }
}

fn test_inertness_follows_state_preserving_moves_and_explicit_inert_subtrees() {
	mut document := Document.create(url_about_blank())
	root := inert_move_element(document, 'div')
	inert_append(document.as_node(), root.as_node())
	mut inert_parent := inert_move_element(document, 'div')
	inert_parent.set_attribute_value('inert', '')
	mut editor := inert_move_element(document, 'div')
	editor.set_attribute_value('contenteditable', 'true')
	inert_append(root.as_node(), inert_parent.as_node())
	inert_append(root.as_node(), editor.as_node())
	button := inert_move_element(document, 'button')
	inert_append(inert_parent.as_node(), button.as_node())
	assert button.as_node().is_inert()
	assert !button.matches_read_write_pseudo_class()
	inert_move(editor.as_node(), button.as_node())
	assert !button.as_node().is_inert()
	assert button.matches_read_write_pseudo_class()
	inert_move(inert_parent.as_node(), button.as_node())
	assert button.as_node().is_inert()
	inert_move(root.as_node(), button.as_node())
	assert !button.as_node().is_inert()
	assert !button.matches_read_write_pseudo_class()

	mut explicit := inert_move_element(document, 'div')
	explicit.set_attribute_value('inert', '')
	inner := inert_move_element(document, 'span')
	inert_append(explicit.as_node(), inner.as_node())
	inert_append(inert_parent.as_node(), explicit.as_node())
	mut explicit_node := explicit.as_node()
	explicit_node.remove(false)
	assert explicit.as_node().is_inert()
	assert inner.as_node().is_inert()
}

fn test_inertness_crosses_shadow_hosts_on_insertion_moves_and_attribute_changes() {
	mut document := Document.create(url_about_blank())
	root := inert_move_element(document, 'div')
	inert_append(document.as_node(), root.as_node())
	mut host := inert_move_element(document, 'div')
	inert_append(root.as_node(), host.as_node())
	shadow := host.attach_shadow(ShadowRootInit{mode: .open}) or { panic(err) }
	mut editor := inert_move_element(document, 'div')
	editor.set_attribute_value('contenteditable', 'true')
	inert_append(shadow.as_node(), editor.as_node())
	assert editor.matches_read_write_pseudo_class()
	mut editor_node := editor.as_node()
	// The DOM-only owner has no CSS invalidation planner. Clear construction
	// invalidations, then observe its whole-subtree fallback invalidation.
	document.set_needs_full_style_update(false)
	document.as_node().visit_shadow_including_inclusive_descendants(fn (node &Node) TraversalDecision {
		mut mutable_node := unsafe { &Node(node) }
		mutable_node.set_needs_style_update_internal(false)
		mutable_node.set_entire_subtree_needs_style_update(false)
		mutable_node.set_child_needs_style_update(false)
		return .@continue
	})
	host.set_attribute_value('inert', '')
	assert editor.as_node().is_inert()
	assert !editor.matches_read_write_pseudo_class()
	assert editor_node.needs_style_update() || editor_node.entire_subtree_needs_style_update()
	text := document.create_text_node('shadow text')
	inert_append(shadow.as_node(), text.as_node())
	assert text.as_node().is_inert()
	inserted := inert_move_element(document, 'button')
	inert_append(shadow.as_node(), inserted.as_node())
	assert inserted.as_node().is_inert()
	inert_move(root.as_node(), inserted.as_node())
	assert !inserted.as_node().is_inert()
	inert_move(shadow.as_node(), inserted.as_node())
	assert inserted.as_node().is_inert()
	host.remove_attribute('inert')
	assert !editor.as_node().is_inert()
	assert editor.matches_read_write_pseudo_class()
	assert !text.as_node().is_inert()
	assert !inserted.as_node().is_inert()
}

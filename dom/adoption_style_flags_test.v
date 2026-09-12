module dom

fn adoption_style_flags_test_element(document &Document, name string) &Element {
	return document.create_element_ns('http://www.w3.org/1999/xhtml', name) or {
		panic('${err}')
	}
}

fn clear_adoption_style_flags(mut node Node) {
	node.set_needs_style_update_internal(false)
	node.set_child_needs_style_update(false)
	node.set_entire_subtree_needs_style_update(false)
}

fn test_adoption_repropagates_entire_subtree_style_flag_through_shadow_host() {
	source := Document.create(url_about_blank())
	mut destination := Document.create(url_about_blank())
	mut host := adoption_style_flags_test_element(source, 'div')
	shadow_root := host.attach_shadow(ShadowRootInit{ mode: .open }) or { panic('${err}') }
	shadow_node := shadow_root_as_node(shadow_root)

	mut host_node := host.as_node()
	clear_adoption_style_flags(mut host_node)
	mut mutable_shadow_node := unsafe { &Node(shadow_node) }
	clear_adoption_style_flags(mut mutable_shadow_node)
	mutable_shadow_node.set_entire_subtree_needs_style_update(true)

	destination.adopt_node(host.as_node())

	assert shadow_node.document() == destination
	assert shadow_node.entire_subtree_needs_style_update()
	assert !shadow_node.needs_style_update()
	assert host.as_node().child_needs_style_update()
}

fn test_adoption_preserves_descendant_dirty_state_without_dirtying_root() {
	source := Document.create(url_about_blank())
	mut destination := Document.create(url_about_blank())
	parent := adoption_style_flags_test_element(source, 'div')
	child := adoption_style_flags_test_element(source, 'span')
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic('${err}') }
	clear_adoption_style_flags(mut parent_node)
	mut child_node := child.as_node()
	clear_adoption_style_flags(mut child_node)
	child_node.set_child_needs_style_update(true)

	destination.adopt_node(parent.as_node())

	assert child.as_node().child_needs_style_update()
	assert !child.as_node().needs_style_update()
	assert parent.as_node().child_needs_style_update()
}

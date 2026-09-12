module dom

fn test_style_invalidator_preserves_ancestor_chain_for_dirty_shadow_root() {
	mut document := Document.create(url_about_blank())
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	mut document_node := unsafe { &Node(document) }
	document_node.append_child(root.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(host.as_node()) or { panic('${err}') }
	shadow_root := host.attach_shadow(ShadowRootInit{ mode: .open }) or { panic('${err}') }
	mut shadow_node := unsafe { &Node(shadow_root) }

	document_node.set_child_needs_style_update(false)
	root_node.set_child_needs_style_update(false)
	mut host_node := host.as_node()
	host_node.set_child_needs_style_update(false)
	shadow_node.set_needs_style_update_internal(true)
	mut invalidator := StyleInvalidator{}
	invalidator.invalidate(mut document_node)

	assert host_node.child_needs_style_update()
	assert root_node.child_needs_style_update()
	assert document_node.child_needs_style_update()
}

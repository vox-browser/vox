module dom

fn test_attach_shadow_clears_a_matching_declarative_root_and_preserves_identity() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut host := document.create_element_ns(namespace_html_uri, 'div')!
	root := host.attach_shadow(ShadowRootInit{mode: .open, serializable: true})!
	unsafe { root.declarative = true }
	mut node := root.as_node()
	child := document.create_element_ns(namespace_html_uri, 'span')!
	node.append_child(child.as_node())!
	returned := host.attach_shadow(ShadowRootInit{mode: .open})!
	assert voidptr(returned) == voidptr(root)
	assert !root.declarative()
	assert root.serializable_
	assert node.children.len == 0
	assert child.as_node().parent() == none
}

fn test_attach_shadow_keeps_a_declarative_tree_when_the_requested_mode_differs() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut host := document.create_element_ns(namespace_html_uri, 'div')!
	root := host.attach_shadow(ShadowRootInit{mode: .closed})!
	unsafe { root.declarative = true }
	mut node := root.as_node()
	child := document.create_text_node('retained')
	node.append_child(child.as_node())!
	if _ := host.attach_shadow(ShadowRootInit{mode: .open}) {
		assert false, 'mode mismatch must fail'
	} else {
		assert err.msg().starts_with('NotSupportedError:')
	}
	assert root.declarative()
	assert node.children.len == 1
	assert voidptr(node.first_child()?) == voidptr(child.as_node())
}

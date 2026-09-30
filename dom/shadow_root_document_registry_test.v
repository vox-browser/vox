module dom

fn assert_document_shadow_roots(document &Document, roots []&ShadowRoot) {
	assert document.shadow_roots.len == roots.len
	for index, root in roots {
		assert voidptr(document.shadow_roots[index]) == voidptr(root)
	}
}

fn test_shadow_root_creation_registers_author_and_user_agent_roots() {
	mut document := Document.create(url_about_blank())
	mut host := document.create_element_ns(namespace_html_uri, 'div')!
	mut control := document.create_element_ns(namespace_html_uri, 'input')!
	mut document_node := document.as_node()
	document_node.append_child(host.as_node())!
	author_root := host.attach_shadow(ShadowRootInit{ mode: .open })!
	ua_root := control.attach_a_user_agent_shadow_root(.named)
	assert_document_shadow_roots(document, [author_root, ua_root])
	assert control.attach_a_user_agent_shadow_root(.named) == ua_root
	assert_document_shadow_roots(document, [author_root, ua_root])

	mut host_node := host.as_node()
	host_node.remove(false)
	assert_document_shadow_roots(document, [author_root, ua_root])
}

fn test_adoption_transfers_nested_shadow_roots_between_document_registries() {
	mut source := Document.create(url_about_blank())
	mut destination := Document.create(url_about_blank())
	mut host := source.create_element_ns(namespace_html_uri, 'div')!
	outer_root := host.attach_shadow(ShadowRootInit{ mode: .open })!
	mut nested_host := source.create_element_ns(namespace_html_uri, 'span')!
	mut outer_node := shadow_root_as_node(outer_root)
	outer_node.append_child(nested_host.as_node())!
	inner_root := nested_host.attach_shadow(ShadowRootInit{ mode: .closed })!
	mut unrelated_host := source.create_element_ns(namespace_html_uri, 'div')!
	unrelated_root := unrelated_host.attach_shadow(ShadowRootInit{ mode: .open })!

	destination.adopt_node(host.as_node())
	assert_document_shadow_roots(source, [unrelated_root])
	assert_document_shadow_roots(destination, [outer_root, inner_root])
	assert outer_node.document() == destination
	assert shadow_root_as_node(inner_root).document() == destination

	destination.adopt_node(host.as_node())
	assert_document_shadow_roots(destination, [outer_root, inner_root])
	source.adopt_node(host.as_node())
	assert_document_shadow_roots(source, [unrelated_root, outer_root, inner_root])
	assert destination.shadow_roots.len == 0
}

fn test_adopted_user_agent_shadow_root_finalizes_in_its_current_document() {
	mut source := Document.create(url_about_blank())
	mut destination := Document.create(url_about_blank())
	mut control := source.create_element_ns(namespace_html_uri, 'input')!
	mut root := control.attach_a_user_agent_shadow_root(.named)
	destination.adopt_node(control.as_node())
	assert source.shadow_roots.len == 0
	assert_document_shadow_roots(destination, [root])

	root.finalize()
	assert destination.shadow_roots.len == 0
}

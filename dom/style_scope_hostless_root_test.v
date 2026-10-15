module dom

fn test_retained_hostless_shadow_root_stops_without_an_implicit_document_scope() {
	mut document := Document.create(url_about_blank())
	mut host := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(host.as_node()) or { panic(err) }
	mut root := host.attach_shadow(ShadowRootInit{mode: .open}) or { panic(err) }
	mut root_node := shadow_root_as_node(root)
	child := document.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
	root_node.append_child(child.as_node()) or { panic(err) }
	retained := child.as_node().observing_style_scopes()
	assert voidptr(retained.first) == voidptr(root.style_scope())
	assert retained.additional.len == 1
	assert voidptr(retained.additional[0]) == voidptr(document.style_scope())

	// Native control rebuilding can detach a shadow root while another owner
	// still retains that root and its children. Its registry entry stays live.
	host.set_shadow_root(none)
	assert host.shadow_root() == none
	assert root.host() == none
	assert root_node.parent_or_shadow_host() == none
	assert document.shadow_roots.len == 1
	assert voidptr(child.as_node().root()) == voidptr(root_node)
	for _ in 0 .. 3 { gc_collect() }
	for node in [child.as_node(), root_node] {
		actual := node.observing_style_scopes()
		assert voidptr(actual.first) == voidptr(root.style_scope())
		assert actual.additional.len == 0
		assert actual.additional.cap == 0
	}
	// The earlier callback snapshot remains complete after host detachment.
	assert voidptr(retained.first) == voidptr(root.style_scope())
	assert retained.additional.len == 1
	assert voidptr(retained.additional[0]) == voidptr(document.style_scope())
	ordinary := host.as_node().observing_style_scopes()
	assert voidptr(ordinary.first) == voidptr(document.style_scope())
	assert ordinary.additional.len == 0

	root.set_uses_document_style_sheets(true)
	sheet_mode := child.as_node().observing_style_scopes()
	assert voidptr(sheet_mode.first) == voidptr(document.style_scope())
	assert sheet_mode.additional.len == 0
	root.set_uses_document_style_sheets(false)
	gc_collect()
	own_scope := child.as_node().observing_style_scopes()
	assert voidptr(own_scope.first) == voidptr(root.style_scope())
	assert own_scope.additional.len == 0
}

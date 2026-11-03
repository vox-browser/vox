module dom

fn navigable_registry_test_equal(document &Document) {
	actual := document.descendant_navigables()
	expected := document.collect_descendant_navigables()
	assert actual.len == expected.len
	for i in 0 .. actual.len { assert voidptr(actual[i]) == voidptr(expected[i]) }
}

fn test_descendant_registry_empty_and_other_document_containers_preserve_results() {
	mut document := Document.create(url_about_blank())
	mut other := Document.create(url_about_blank())
	defer { document.finalize(); other.finalize() }
	navigable_registry_test_equal(document)
	assert !document.may_have_registered_navigable_container()
	container := other.create_element_ns(namespace_html_uri, 'iframe')!
	mut child := &Navigable{container_: container.as_node(), active_document_: other}
	register_navigable(child)
	defer { child.remove_from_all_navigables() }
	assert !document.may_have_registered_navigable_container()
	navigable_registry_test_equal(document)
	// Detached same-document containers are deliberately not a negative proof.
	assert other.may_have_registered_navigable_container()
	navigable_registry_test_equal(other)
	assert other.descendant_navigables().len == 0
}

fn test_descendant_registry_registration_removal_and_container_changes_are_live() {
	mut document := Document.create(url_about_blank())
	mut child_document := Document.create(url_about_blank())
	defer { document.finalize(); child_document.finalize() }
	mut node := document.as_node()
	container := document.create_element_ns(namespace_html_uri, 'iframe')!
	node.append_child(container.as_node())!
	mut child := &Navigable{container_: container.as_node()}
	child_document.set_navigable(child)
	child.active_document_ = child_document
	defer { child.remove_from_all_navigables() }
	assert document.may_have_registered_navigable_container()
	navigable_registry_test_equal(document)
	assert document.descendant_navigables().len == 1
	child.container_ = none
	assert !document.may_have_registered_navigable_container()
	navigable_registry_test_equal(document)
	child.container_ = container.as_node()
	assert document.descendant_navigables().len == 1
	child.remove_from_all_navigables()
	assert !document.may_have_registered_navigable_container()
	navigable_registry_test_equal(document)
}

fn test_descendant_registry_keeps_tree_order_and_nested_document_results() {
	mut document := Document.create(url_about_blank())
	mut first_document := Document.create(url_about_blank())
	mut second_document := Document.create(url_about_blank())
	mut nested_document := Document.create(url_about_blank())
	defer { document.finalize(); first_document.finalize(); second_document.finalize(); nested_document.finalize() }
	mut root := document.create_element_ns(namespace_html_uri, 'main')!
	mut document_node := document.as_node()
	document_node.append_child(root.as_node())!
	first := document.create_element_ns(namespace_html_uri, 'iframe')!
	second := document.create_element_ns(namespace_html_uri, 'iframe')!
	mut root_node := root.as_node()
	root_node.append_child(first.as_node())!
	root_node.append_child(second.as_node())!
	nested := first_document.create_element_ns(namespace_html_uri, 'iframe')!
	mut first_node := first_document.as_node()
	first_node.append_child(nested.as_node())!
	mut a := &Navigable{container_: first.as_node(), active_document_: first_document}
	mut b := &Navigable{container_: second.as_node(), active_document_: second_document}
	mut c := &Navigable{container_: nested.as_node(), active_document_: nested_document}
	// Register in the opposite order: traversal order must remain DOM order.
	second_document.set_navigable(b)
	nested_document.set_navigable(c)
	first_document.set_navigable(a)
	defer { a.remove_from_all_navigables(); b.remove_from_all_navigables(); c.remove_from_all_navigables() }
	navigable_registry_test_equal(document)
	actual := document.descendant_navigables()
	assert actual.len == 3
	assert voidptr(actual[0]) == voidptr(a)
	assert voidptr(actual[1]) == voidptr(c)
	assert voidptr(actual[2]) == voidptr(b)
}

fn test_descendant_registry_follows_container_adoption_and_live_load_delay() {
	mut before := Document.create(url_about_blank())
	mut after := Document.create(url_about_blank())
	mut child_document := Document.create(url_about_blank())
	defer { before.finalize(); after.finalize(); child_document.finalize() }
	container := before.create_element_ns(namespace_html_uri, 'iframe')!
	mut child := &Navigable{container_: container.as_node(), active_document_: child_document}
	child_document.set_navigable(child)
	defer { child.remove_from_all_navigables() }
	assert before.may_have_registered_navigable_container()
	assert !after.may_have_registered_navigable_container()
	after.adopt_node(container.as_node())
	assert !before.may_have_registered_navigable_container()
	assert after.may_have_registered_navigable_container()
	mut after_node := after.as_node()
	after_node.append_child(container.as_node())!
	navigable_registry_test_equal(before)
	navigable_registry_test_equal(after)
	mut node := container.as_node()
	node.set_load_event_delay_hook(NodeLoadEventDelayHook{
		target: node
		callback: fn (target voidptr) bool { return unsafe { &Node(target) }.is_connected() }
	})
	assert after.anything_is_delaying_the_load_event()
	node.set_load_event_delay_hook(none)
	assert !after.anything_is_delaying_the_load_event()
}

fn test_descendant_registry_preserves_closed_shadow_container_discovery() {
	mut document := Document.create(url_about_blank())
	mut child_document := Document.create(url_about_blank())
	defer { document.finalize(); child_document.finalize() }
	mut host := document.create_element_ns(namespace_html_uri, 'div')!
	mut document_node := document.as_node()
	document_node.append_child(host.as_node())!
	shadow := host.attach_shadow(ShadowRootInit{mode: .closed})!
	container := document.create_element_ns(namespace_html_uri, 'iframe')!
	mut shadow_node := shadow_root_as_node(shadow)
	shadow_node.append_child(container.as_node())!
	mut child := &Navigable{container_: container.as_node(), active_document_: child_document}
	child_document.set_navigable(child)
	defer { child.remove_from_all_navigables() }
	assert document.may_have_registered_navigable_container()
	navigable_registry_test_equal(document)
	assert document.descendant_navigables().len == 1
	mut host_node := host.as_node()
	host_node.remove(false)
	// Removing the host leaves a conservative positive, then ordinary traversal
	// correctly excludes the detached shadow tree.
	assert document.may_have_registered_navigable_container()
	navigable_registry_test_equal(document)
	assert document.descendant_navigables().len == 0
}

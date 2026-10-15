module dom

fn test_stabilization_bound_tracks_connected_light_and_shadow_elements() {
	mut document := Document.create(url_about_blank())
	mut root := document.create_element_ns(namespace_html_uri, 'html')!
	mut document_node := unsafe { &Node(document) }
	document_node.append_child(root.as_node())!
	mut host := document.create_element_ns(namespace_html_uri, 'div')!
	mut root_node := root.as_node()
	root_node.append_child(host.as_node())!
	assert document.cached_layout_stabilization_element_count() == 2
	assert document.cached_layout_stabilization_element_count() == 2
	shadow := host.attach_shadow(ShadowRootInit{ mode: .open })!
	mut shadow_node := shadow_root_as_node(shadow)
	mut child := document.create_element_ns(namespace_html_uri, 'span')!
	shadow_node.append_child(child.as_node())!
	assert document.cached_layout_stabilization_element_count() == 3
	mut text := document.create_text_node('content')
	shadow_node.append_child(unsafe { &Node(text) })!
	assert document.cached_layout_stabilization_element_count() == 3
	// Attaching/detaching an already populated shadow root changes the count
	// even when the light-tree mutation version itself has not changed.
	host.set_shadow_root(none)
	assert document.cached_layout_stabilization_element_count() == 2
	host.set_shadow_root(shadow)
	assert document.cached_layout_stabilization_element_count() == 3
	mut child_node := child.as_node()
	child_node.remove(false)
	assert document.cached_layout_stabilization_element_count() == 2
	root_node.remove(false)
	assert document.cached_layout_stabilization_element_count() == 0
}

fn test_stabilization_bound_tracks_adopted_nested_shadow_trees() {
	mut source := Document.create(url_about_blank())
	mut destination := Document.create(URL{ value: 'https://other.test/' })
	mut source_root := source.create_element_ns(namespace_html_uri, 'html')!
	mut destination_root := destination.create_element_ns(namespace_html_uri, 'html')!
	mut source_node := unsafe { &Node(source) }
	mut destination_node := unsafe { &Node(destination) }
	source_node.append_child(source_root.as_node())!
	destination_node.append_child(destination_root.as_node())!
	mut host := source.create_element_ns(namespace_html_uri, 'div')!
	mut source_root_node := source_root.as_node()
	source_root_node.append_child(host.as_node())!
	shadow := host.attach_shadow(ShadowRootInit{ mode: .closed })!
	mut shadow_node := shadow_root_as_node(shadow)
	mut nested_host := source.create_element_ns(namespace_html_uri, 'span')!
	shadow_node.append_child(nested_host.as_node())!
	nested_shadow := nested_host.attach_shadow(ShadowRootInit{ mode: .open })!
	mut nested_shadow_node := shadow_root_as_node(nested_shadow)
	nested_shadow_node.append_child(source.create_element_ns(namespace_html_uri, 'b')!.as_node())!
	assert source.cached_layout_stabilization_element_count() == 4
	assert destination.cached_layout_stabilization_element_count() == 1
	destination.adopt_node(host.as_node())
	mut destination_root_node := destination_root.as_node()
	destination_root_node.append_child(host.as_node())!
	assert source.cached_layout_stabilization_element_count() == 1
	assert destination.cached_layout_stabilization_element_count() == 4
	nested_shadow_node.append_child(destination.create_element_ns(namespace_html_uri, 'i')!.as_node())!
	assert destination.cached_layout_stabilization_element_count() == 5
	assert source.cached_layout_stabilization_element_count() == 1
}

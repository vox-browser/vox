module dom

@[heap]
struct ShadowDetachObservation {
	node &Node
	root &Node
mut:
	calls int
}

fn shadow_detach_removed(target voidptr, subtree NodeIsSubtreeRoot, ancestor ?&Node, root &Node) {
	mut observation := unsafe { &ShadowDetachObservation(target) }
	assert subtree == .no && (ancestor or { panic('Missing old shadow ancestor') }) == observation.root
	assert root == observation.root && !root.is_connected() && !observation.node.is_connected()
	observation.calls++
}

fn shadow_detach_watch(node &Node, root &Node) &ShadowDetachObservation {
	observation := &ShadowDetachObservation{node: node, root: root}
	mut mutable_node := unsafe { &Node(node) }
	mutable_node.set_lifecycle_hook(NodeLifecycleHook{target: observation, removed_from: shadow_detach_removed})
	return observation
}

fn test_shadow_detachment_runs_removal_steps_for_nested_shadow_and_text_descendants() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut host := document.create_element_ns(namespace_html_uri, 'div')!
	mut document_node := document.as_node()
	document_node.append_child(host.as_node())!
	light_child := document.create_element_ns(namespace_html_uri, 'span')!
	mut host_node := host.as_node()
	host_node.append_child(light_child.as_node())!
	root := host.attach_shadow(ShadowRootInit{mode: .open})!
	mut root_node := shadow_root_as_node(root)
	mut child := document.create_element_ns(namespace_html_uri, 'section')!
	root_node.append_child(child.as_node())!
	text := document.create_text_node('retained')
	mut child_node := child.as_node()
	child_node.append_child(text.as_node())!
	inner := child.attach_a_user_agent_shadow_root(.named)
	mut inner_node := shadow_root_as_node(inner)
	svg := document.create_element_ns('http://www.w3.org/2000/svg', 'svg')!
	inner_node.append_child(svg.as_node())!
	path := document.create_element_ns('http://www.w3.org/2000/svg', 'path')!
	mut svg_node := svg.as_node()
	svg_node.append_child(path.as_node())!
	nodes := [child_node, text.as_node(), inner_node, svg_node, path.as_node()]
	mut observations := []&ShadowDetachObservation{}
	for node in nodes {
		assert node.is_connected()
		observations << shadow_detach_watch(node, root_node)
		mut mutable_node := unsafe { &Node(node) }
		mutable_node.set_layout_node(&LayoutNode{dom_node_: node})
	}
	host.set_shadow_root(none)
	assert host.shadow_root() == none && root.host() == none && !root_node.is_connected()
	for index, node in nodes {
		assert !node.is_connected() && node.unsafe_layout_node() == none
		assert observations[index].calls == 1
	}
	assert host.is_connected() && light_child.is_connected()
	assert root_node.children_as_vector() == [child_node]
	assert child_node.children_as_vector() == [text.as_node()]
	assert child.shadow_root()? == inner && inner.host()? == child
	host.set_shadow_root(none)
	for observation in observations { assert observation.calls == 1 }
}

fn test_shadow_replacement_disconnects_only_the_old_tree_and_same_root_is_a_noop() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut host := document.create_element_ns(namespace_html_uri, 'div')!
	mut document_node := document.as_node()
	document_node.append_child(host.as_node())!
	old := host.attach_a_user_agent_shadow_root(.named)
	mut old_node := shadow_root_as_node(old)
	child := document.create_element_ns(namespace_html_uri, 'span')!
	old_node.append_child(child.as_node())!
	observation := shadow_detach_watch(child.as_node(), old_node)
	host.set_shadow_root(old)
	assert child.is_connected() && observation.calls == 0
	mut donor := document.create_element_ns(namespace_html_uri, 'div')!
	next := donor.attach_a_user_agent_shadow_root(.named)
	donor.set_shadow_root(none)
	host.set_shadow_root(next)
	assert host.shadow_root()? == next && next.host()? == host
	assert shadow_root_as_node(next).is_connected() && !old_node.is_connected() && !child.is_connected()
	assert observation.calls == 1 && old_node.children_as_vector() == [child.as_node()]
}

fn test_disconnected_shadow_replacement_skips_already_disconnected_descendant_steps() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut host := document.create_element_ns(namespace_html_uri, 'div')!
	root := host.attach_a_user_agent_shadow_root(.named)
	mut root_node := shadow_root_as_node(root)
	child := document.create_element_ns(namespace_html_uri, 'span')!
	root_node.append_child(child.as_node())!
	observation := shadow_detach_watch(child.as_node(), root_node)
	assert !host.is_connected() && !root_node.is_connected() && !child.is_connected()
	host.set_shadow_root(none)
	assert root.host() == none && !child.is_connected() && observation.calls == 0
}

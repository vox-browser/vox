module dom

$if gcboehm ? { fn C.GC_get_total_bytes() usize }

fn root_walk_element(document &Document) &Element {
	return document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
}

fn test_root_walk_keeps_document_fragment_and_detached_roots() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut document_node := document.as_node()
	mut outer := root_walk_element(document).as_node()
	mut inner := root_walk_element(document).as_node()
	leaf := document.create_text_node('leaf').as_node()
	inner.append_child(leaf)!
	outer.append_child(inner)!
	assert voidptr(document_node.root()) == voidptr(document_node)
	assert voidptr(leaf.root()) == voidptr(outer)
	fragment := document.create_document_fragment()
	mut fragment_node := fragment.as_node()
	fragment_node.append_child(outer)!
	assert voidptr(leaf.root()) == voidptr(fragment_node)
	assert voidptr(fragment_node.root()) == voidptr(fragment_node)
	document_node.append_child(fragment_node)!
	assert voidptr(leaf.root()) == voidptr(document_node)
	assert voidptr(fragment_node.root()) == voidptr(fragment_node)
	outer.remove(false)
	assert voidptr(leaf.root()) == voidptr(outer)
}

fn test_root_walk_observes_moves_and_adoption_without_retaining_an_old_root() {
	mut source := Document.create(url_about_blank())
	mut destination := Document.create(url_about_blank())
	defer { source.finalize() }
	defer { destination.finalize() }
	mut source_node := source.as_node()
	mut destination_node := destination.as_node()
	mut first := root_walk_element(source).as_node()
	mut second := root_walk_element(source).as_node()
	mut branch := root_walk_element(source).as_node()
	leaf := source.create_text_node('moving').as_node()
	branch.append_child(leaf)!
	first.append_child(branch)!
	source_node.append_child(first)!
	assert voidptr(leaf.root()) == voidptr(source_node)
	second.append_child(branch)!
	assert voidptr(leaf.root()) == voidptr(second)
	assert voidptr(first.root()) == voidptr(source_node)
	destination.adopt_node(second)
	assert voidptr(leaf.root()) == voidptr(second)
	assert voidptr(leaf.document()) == voidptr(destination)
	destination_node.append_child(second)!
	assert voidptr(leaf.root()) == voidptr(destination_node)
	assert voidptr(first.root()) == voidptr(source_node)
}

fn test_root_walk_stops_at_shadow_roots_including_after_host_detachment() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut document_node := document.as_node()
	mut container := root_walk_element(document).as_node()
	document_node.append_child(container)!
	mut first_host := root_walk_element(document)
	mut second_host := root_walk_element(document)
	container.append_child(first_host.as_node())!
	container.append_child(second_host.as_node())!
	first := first_host.attach_shadow(ShadowRootInit{mode: .open})!
	second := second_host.attach_shadow(ShadowRootInit{mode: .closed})!
	mut first_node := first.as_node()
	mut second_node := second.as_node()
	mut branch := root_walk_element(document).as_node()
	leaf := document.create_text_node('shadow leaf').as_node()
	branch.append_child(leaf)!
	first_node.append_child(branch)!
	assert voidptr(leaf.root()) == voidptr(first_node)
	assert voidptr(leaf.shadow_including_root()) == voidptr(document_node)
	second_node.append_child(branch)!
	assert voidptr(leaf.root()) == voidptr(second_node)
	assert voidptr(first_node.root()) == voidptr(first_node)
	mut host_node := second_host.as_node()
	host_node.remove(false)
	assert voidptr(leaf.root()) == voidptr(second_node)
	assert voidptr(leaf.shadow_including_root()) == voidptr(host_node)
}

fn test_root_walk_handles_a_deep_parent_chain_without_allocating_on_reads() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	fragment := document.create_document_fragment()
	root := fragment.as_node()
	mut leaf := fragment.as_node()
	// Assemble consistent disconnected links directly so fixture setup does not
	// repeat the public insertion algorithm's ancestor validation at every depth.
	for _ in 0 .. 32768 {
		mut child := root_walk_element(document).as_node()
		child.parent_ = leaf
		child.index_in_parent_ = leaf.children.len
		leaf.children << child
		leaf = child
	}
	mut before := usize(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	mut matches := 0
	for _ in 0 .. 32 {
		if voidptr(leaf.root()) == voidptr(root) { matches++ }
	}
	mut allocated := usize(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert matches == 32
	assert allocated == 0
	assert voidptr(root.root()) == voidptr(root)
}

module layout

import dom

// The real Layout::Node base: tree structure (parent/children/siblings), DOM back-pointer, and flags.
fn test_layout_node_tree() {
	doc := dom.Document.create(dom.url_about_blank())
	mut el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }

	mut root := Node.new(doc, el.as_node())
	mut child1 := Node.new(doc, none) // anonymous box (no DOM node)
	child1.anonymous_ = true
	mut child2 := Node.new(doc, none)

	root.append_child(child1)
	root.append_child(child2)

	assert root.child_count() == 2
	assert root.has_children()
	assert !child1.has_children()

	// Parent links.
	c1_parent := child1.parent() or { panic('child1 has no parent') }
	assert layout_nodes_same(c1_parent, root)

	// First / last child.
	assert layout_nodes_same(root.first_child() or { panic('no first child') }, child1)
	assert layout_nodes_same(root.last_child() or { panic('no last child') }, child2)

	// Siblings.
	assert layout_nodes_same(child1.next_sibling() or { panic('child1 has no next sibling') }, child2)
	if _ := child2.next_sibling() {
		panic('child2 should have no next sibling')
	}
	assert layout_nodes_same(child2.previous_sibling() or { panic('child2 has no prev sibling') }, child1)
	if _ := child1.previous_sibling() {
		panic('child1 should have no previous sibling')
	}

	// DOM back-pointer: root has one (the div), the anonymous child does not.
	dn := root.dom_node() or { panic('root has no dom node') }
	if _ := dn.as_element() {
	} else {
		panic('root dom node is not an element')
	}
	if _ := child1.dom_node() {
		panic('anonymous child should have no dom node')
	}

	// Flags.
	assert child1.is_anonymous()
	assert !root.is_anonymous()
}

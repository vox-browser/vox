module layout

import dom
import css

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

	c1_parent := child1.parent() or { panic('child1 has no parent') }
	assert layout_nodes_same(c1_parent, root)

	assert layout_nodes_same(root.first_child() or { panic('no first child') }, child1)
	assert layout_nodes_same(root.last_child() or { panic('no last child') }, child2)

	assert layout_nodes_same(child1.next_sibling() or { panic('child1 has no next sibling') },
		child2)
	if _ := child2.next_sibling() {
		panic('child2 should have no next sibling')
	}
	assert layout_nodes_same(child2.previous_sibling() or { panic('child2 has no prev sibling') },
		child1)
	if _ := child1.previous_sibling() {
		panic('child1 should have no previous sibling')
	}

	dn := root.dom_node() or { panic('root has no dom node') }
	if _ := dn.as_element() {
	} else {
		panic('root dom node is not an element')
	}
	if _ := child1.dom_node() {
		panic('anonymous child should have no dom node')
	}

	assert child1.is_anonymous()
	assert !root.is_anonymous()
}

// NodeWithStyle embeds Node (so it participates in the tree) and holds the computed style; a &Node in the
// tree can be cast back to &NodeWithStyle to read it.
fn test_node_with_style() {
	doc := dom.Document.create(dom.url_about_blank())
	root_style := css.ComputedProperties.new()
	child_style := css.ComputedProperties.new()

	mut root := NodeWithStyle.new(doc, none, root_style)
	mut child := NodeWithStyle.new(doc, none, child_style)

	root_cv := root.computed_values()
	assert voidptr(root_cv) == voidptr(root_style)
	assert root.has_style()

	root.append_child(unsafe { &Node(child) })
	assert root.child_count() == 1
	first := root.first_child() or { panic('no first child') }
	first_styled := first.as_node_with_style() or { panic('child is not a NodeWithStyle') }
	first_cv := first_styled.computed_values()
	assert voidptr(first_cv) == voidptr(child_style)

	bare := Node.new(doc, none)
	if _ := bare.as_node_with_style() {
		panic('a styleless Node should not cast to NodeWithStyle')
	}
}

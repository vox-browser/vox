module dom

// Runtime smoke tests for the DOM module. The DOM was translated and type-checked but had
// never been executed; these exercise node identity, tree building, textContent aggregation
// and the tree-collection queries (getElementsByTagName / descendant collection), which
// depend on correct node identity and on closures being able to accumulate results.

fn new_element(doc &Document, tag string) &Element {
	return doc.create_element(tag) or { panic('create_element(${tag}): ${err}') }
}

fn test_node_identity() {
	doc := Document.create(url_about_blank())
	a := new_element(doc, 'div')
	b := new_element(doc, 'div')
	c := doc.create_comment('x')
	// A node is the same as itself and distinct from other freshly-created nodes, even when
	// their fields are structurally identical.
	assert a.as_node().is_same_node(a.as_node())
	assert !a.as_node().is_same_node(b.as_node())
	assert !a.as_node().is_same_node(c.as_node())
	assert !b.as_node().is_same_node(c.as_node())
}

fn test_tree_building() {
	doc := Document.create(url_about_blank())
	mut root := new_element(doc, 'div')
	child1 := new_element(doc, 'span')
	child2 := new_element(doc, 'p')
	mut root_node := root.as_node()
	root_node.append_child(child1.as_node()) or { panic('append1: ${err}') }
	root_node.append_child(child2.as_node()) or { panic('append2: ${err}') }

	assert root_node.child_count() == 2
	first := root_node.first_child() or { panic('no first child') }
	last := root_node.last_child() or { panic('no last child') }
	assert first.is_same_node(child1.as_node())
	assert last.is_same_node(child2.as_node())
	// A node cannot be appended below itself.
	if _ := root_node.append_child(root.as_node()) {
		assert false, 'appending a node to itself must fail'
	}
}

fn test_text_content() {
	doc := Document.create(url_about_blank())
	mut root := new_element(doc, 'div')
	mut span := new_element(doc, 'span')
	mut root_node := root.as_node()
	mut span_node := span.as_node()
	root_node.append_child(span_node) or { panic('${err}') }
	span_node.append_child(doc.create_text_node('hello').as_node()) or { panic('${err}') }
	root_node.append_child(doc.create_text_node(' world').as_node()) or { panic('${err}') }

	// textContent aggregates the data of all descendant text nodes in tree order.
	assert root_node.text_content() or { '' } == 'hello world'
	assert span_node.text_content() or { '' } == 'hello'
}

fn test_collection_queries() {
	doc := Document.create(url_about_blank())
	mut root := new_element(doc, 'div')
	mut root_node := root.as_node()
	root_node.append_child(new_element(doc, 'span').as_node()) or { panic('${err}') }
	nested := new_element(doc, 'p')
	root_node.append_child(nested.as_node()) or { panic('${err}') }
	mut nested_node := nested.as_node()
	nested_node.append_child(new_element(doc, 'span').as_node()) or { panic('${err}') }

	// getElementsByTagName walks the whole subtree.
	assert root.get_elements_by_tag_name('span').length() == 2
	assert root.get_elements_by_tag_name('p').length() == 1

	all := collect_elements_for_scope(root_node, .descendants, fn (e &Element) bool {
		return true
	})
	assert all.len == 3
}

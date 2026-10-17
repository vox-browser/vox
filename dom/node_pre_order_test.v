module dom

fn pre_order_test_element(document &Document, name string) &Element {
	return document.create_element_ns('http://www.w3.org/1999/xhtml', name) or { panic(err) }
}

// Traversal stops at its root by identity: the walk never leaves the root's
// subtree into the root's following siblings.
fn test_next_in_pre_order_stays_within_the_root_subtree() {
	mut document := Document.create(url_about_blank())
	mut document_node := unsafe { &Node(document) }
	mut html := pre_order_test_element(document, 'html')
	document_node.append_child(html.as_node()) or { panic(err) }
	mut root := pre_order_test_element(document, 'section')
	mut html_node := unsafe { &Node(html.as_node()) }
	html_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := unsafe { &Node(root.as_node()) }
	mut first := pre_order_test_element(document, 'p')
	root_node.append_child(first.as_node()) or { panic(err) }
	mut first_node := unsafe { &Node(first.as_node()) }
	first_node.append_child(pre_order_test_element(document, 'b').as_node()) or { panic(err) }
	root_node.append_child(pre_order_test_element(document, 'i').as_node()) or { panic(err) }
	html_node.append_child(pre_order_test_element(document, 'footer').as_node()) or { panic(err) }
	mut names := []string{}
	mut current := root.as_node().next_in_pre_order(root.as_node())
	for {
		node := current or { break }
		names << node.node_name()
		current = node.next_in_pre_order(root.as_node())
	}
	assert names == ['p', 'b', 'i']
	mut all := []string{}
	current = document.as_node().first_child()
	for {
		node := current or { break }
		all << node.node_name()
		current = node.next_in_pre_order(document.as_node())
	}
	assert all == ['html', 'section', 'p', 'b', 'i', 'footer']
}

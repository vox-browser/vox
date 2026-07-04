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

fn test_insert_remove_replace() {
	doc := Document.create(url_about_blank())
	mut root := new_element(doc, 'div')
	mut rn := root.as_node()
	a := new_element(doc, 'a')
	c := new_element(doc, 'i')
	rn.append_child(a.as_node()) or { panic('${err}') }
	rn.append_child(c.as_node()) or { panic('${err}') }
	b := new_element(doc, 'b')
	rn.insert_before(b.as_node(), c.as_node(), false)
	assert rn.child_count() == 3
	assert (a.as_node().next_sibling() or { panic('no sib') }).is_same_node(b.as_node())
	assert (c.as_node().previous_sibling() or { panic('no sib') }).is_same_node(b.as_node())

	rn.remove_child(b.as_node()) or { panic('${err}') }
	assert rn.child_count() == 2
	assert b.as_node().parent() == none
	assert rn.is_inclusive_ancestor_of(a.as_node())
	assert !rn.is_inclusive_ancestor_of(b.as_node())

	p := new_element(doc, 'p')
	rn.replace_child(p.as_node(), a.as_node()) or { panic('${err}') }
	assert (rn.first_child() or { panic('no child') }).is_same_node(p.as_node())
	// a precedes c in tree order.
	assert p.as_node().compare_document_position(c.as_node()) == 4
}

fn test_clone_and_attributes() {
	doc := Document.create(url_about_blank())
	mut root := new_element(doc, 'div')
	root.set_attribute_value('id', 'r')
	root.set_attribute_value('data-x', '1')
	mut rn := root.as_node()
	span := new_element(doc, 'span')
	mut sn := span.as_node()
	rn.append_child(sn) or { panic('${err}') }
	sn.append_child(doc.create_text_node('hi').as_node()) or { panic('${err}') }

	assert root.get_attribute_names().len == 2
	assert root.has_attribute('id')
	root.remove_attribute('data-x')
	assert !root.has_attribute('data-x')

	shallow := rn.clone_node(none, false) or { panic('${err}') }
	deep := rn.clone_node(none, true) or { panic('${err}') }
	assert shallow.child_count() == 0
	assert deep.child_count() == 1
	assert (deep.text_content() or { '' }) == 'hi'
	assert !rn.is_same_node(deep)
	assert (shallow.as_element() or { panic('') }).get_attribute('id') or { '' } == 'r'

	mut class_list := root.class_list()
	class_list.add(['foo', 'bar']) or { panic('${err}') }
	assert class_list.contains('foo')
	assert class_list.length() == 2
	assert (root.get_attribute('class') or { '' }) == 'foo bar'
}

fn test_character_data_and_fragment() {
	doc := Document.create(url_about_blank())
	mut text := doc.create_text_node('hello')
	assert text.length_in_utf16_code_units() == 5
	assert (text.substring_data(0, 5) or { '' }) == 'hello'
	text.insert_data(5, ' world') or { panic('${err}') }
	text.delete_data(0, 6) or { panic('${err}') }
	assert text.data() == 'world'

	frag := new_document_fragment(doc)
	mut frag_node := frag.as_node()
	frag_node.append_child(new_element(doc, 'a').as_node()) or { panic('${err}') }
	frag_node.append_child(new_element(doc, 'b').as_node()) or { panic('${err}') }
	mut host := new_element(doc, 'div')
	mut host_node := host.as_node()
	host_node.append_child(frag_node) or { panic('${err}') }
	// Inserting a fragment moves its children out; the fragment is emptied.
	assert host_node.child_count() == 2
	assert frag_node.child_count() == 0
}

fn test_get_element_by_id() {
	doc := Document.create(url_about_blank())
	mut doc_node := unsafe { &Node(doc) }
	mut root := new_element(doc, 'html')
	root.set_attribute_value('id', 'top')
	mut rn := root.as_node()
	doc_node.append_child(rn) or { panic('${err}') }
	mut target := new_element(doc, 'div')
	target.set_attribute_value('id', 'target')
	rn.append_child(target.as_node()) or { panic('${err}') }

	assert rn.is_connected()
	assert (doc.get_element_by_id('top') or { panic('no top') }).tag_name() == 'html'
	assert (doc.get_element_by_id('target') or { panic('no target') }).tag_name() == 'div'
	assert doc.get_element_by_id('missing') == none
}

fn test_text_split_and_whole() {
	doc := Document.create(url_about_blank())
	mut root := new_element(doc, 'div')
	mut rn := root.as_node()
	mut text := doc.create_text_node('hello world')
	rn.append_child(text.as_node()) or { panic('${err}') }
	// split_text creates a new sibling holding the tail.
	tail := text.split_text(5) or { panic('${err}') }
	assert text.data() == 'hello'
	assert tail.data() == ' world'
	assert rn.child_count() == 2
	// whole_text concatenates contiguous text siblings.
	assert text.whole_text() == 'hello world'
}

fn test_is_equal_node() {
	doc := Document.create(url_about_blank())
	a := new_element(doc, 'p')
	b := new_element(doc, 'p')
	mut c := new_element(doc, 'p')
	c.set_attribute_value('id', 'z')
	// isEqualNode is structural (distinct from isSameNode identity).
	assert a.as_node().is_equal_node(b.as_node())
	assert !a.as_node().is_equal_node(new_element(doc, 'div').as_node())
	assert !a.as_node().is_equal_node(c.as_node())
}

fn test_insert_adjacent_and_attr() {
	doc := Document.create(url_about_blank())
	mut root := new_element(doc, 'div')
	mut rn := root.as_node()
	b := new_element(doc, 'b')
	rn.append_child(b.as_node()) or { panic('${err}') }
	mut mb := b
	mb.insert_adjacent_element('beforebegin', new_element(doc, 'c')) or { panic('${err}') }
	mb.insert_adjacent_element('afterend', new_element(doc, 'd')) or { panic('${err}') }
	mut names := []string{}
	for child in rn.children {
		names << child.node_name()
	}
	assert names == ['c', 'b', 'd']

	mut e := new_element(doc, 'a')
	e.set_attribute_value('href', 'u')
	attr := e.get_attribute_node('href') or { panic('no attr') }
	assert attr.name() == 'href'
	assert attr.value() == 'u'
}

fn test_tree_walker_and_node_iterator() {
	doc := Document.create(url_about_blank())
	mut root := new_element(doc, 'div')
	mut rn := root.as_node()
	rn.append_child(doc.create_text_node('t').as_node()) or { panic('${err}') }
	a := new_element(doc, 'a')
	rn.append_child(a.as_node()) or { panic('${err}') }
	mut an := a.as_node()
	an.append_child(new_element(doc, 'b').as_node()) or { panic('${err}') }

	// SHOW_ELEMENT = 0x1. TreeWalker.nextNode starts below root; NodeIterator includes root.
	mut walker := doc.create_tree_walker(rn, u32(0x1), none)
	mut walked := []string{}
	for {
		node := walker.next_node() or { break }
		walked << node.node_name()
	}
	assert walked == ['a', 'b']

	mut iter := doc.create_node_iterator(rn, u32(0x1), none)
	mut iterated := []string{}
	for {
		node := iter.next_node() or { break }
		iterated << node.node_name()
	}
	assert iterated == ['div', 'a', 'b']
}

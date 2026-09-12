module dom

fn test_adopt_node_retains_the_destination_document_identity() {
	mut old_document := Document.create(URL{ value: 'https://old.example/' })
	mut new_document := Document.create(URL{ value: 'https://new.example/' })
	parent := old_document.create_element('div')!
	child := old_document.create_element('span')!
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node())!

	new_document.adopt_node(parent_node)
	assert voidptr(parent.as_node().document()) == voidptr(new_document)
	assert voidptr(parent.document()) == voidptr(new_document)
	assert voidptr(child.as_node().document()) == voidptr(new_document)
	assert voidptr(child.document()) == voidptr(new_document)
}

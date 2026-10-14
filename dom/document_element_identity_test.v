module dom

fn test_document_element_membership_tracks_identity_removal_and_adoption() {
	mut document := Document.create(url_about_blank())
	mut root := document.create_element('html') or { panic(err) }
	lookalike := document.create_element('html') or { panic(err) }
	mut document_node := unsafe { &Node(document) }
	document_node.append_child(root.as_node()) or { panic(err) }
	assert root.is_document_element()
	assert !lookalike.is_document_element()
	root.set_attribute_value('id', 'root')
	assert root.is_document_element()
	document_node.remove_child(root.as_node()) or { panic(err) }
	assert !root.is_document_element()
	document_node.append_child(lookalike.as_node()) or { panic(err) }
	assert lookalike.is_document_element()
	assert !root.is_document_element()
	other_document := Document.create(url_about_blank())
	mut other_node := unsafe { &Node(other_document) }
	other_node.append_child(lookalike.as_node()) or { panic(err) }
	assert lookalike.is_document_element()
	assert document.document_element() == none
	assert voidptr(lookalike.document()) == voidptr(other_document)
}

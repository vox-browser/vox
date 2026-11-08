module dom

fn range_mutation_fixture() (&Document, &Element, &Text, &Text) {
	document := Document.create(url_about_blank())
	mut root := document.create_element('div') or { panic(err) }
	mut root_node := root.as_node()
	start := document.create_text_node('start')
	middle := document.create_text_node('middle')
	end := document.create_text_node('end')
	root_node.append_child(start.as_node()) or { panic(err) }
	root_node.append_child(middle.as_node()) or { panic(err) }
	root_node.append_child(end.as_node()) or { panic(err) }
	return document, root, start, end
}

fn test_extract_contents_collapses_spanning_range_before_mutations() {
	document, root, start, end := range_mutation_fixture()
	mut range := document.create_range()
	range.set_start(start.as_node(), 2) or { panic(err) }
	range.set_end(end.as_node(), 2) or { panic(err) }

	fragment := range.extract_contents() or { panic(err) }

	assert fragment.as_node().text_content() or { '' } == 'artmiddleen'
	assert root.as_node().text_content() or { '' } == 'std'
	assert range.collapsed()
	assert range.start_container() == root.as_node()
	assert range.start_offset() == 1
}

fn test_extract_contents_climbs_nested_start_ancestors_before_collapsing() {
	document := Document.create(url_about_blank())
	root := document.create_element('div') or { panic(err) }
	start_branch := document.create_element('p') or { panic(err) }
	start_wrapper := document.create_element('span') or { panic(err) }
	end_branch := document.create_element('p') or { panic(err) }
	start := document.create_text_node('start')
	middle := document.create_text_node('middle')
	end := document.create_text_node('end')
	mut root_node := root.as_node()
	mut start_branch_node := start_branch.as_node()
	mut start_wrapper_node := start_wrapper.as_node()
	mut end_branch_node := end_branch.as_node()
	start_wrapper_node.append_child(start.as_node()) or { panic(err) }
	start_branch_node.append_child(start_wrapper_node) or { panic(err) }
	end_branch_node.append_child(end.as_node()) or { panic(err) }
	root_node.append_child(document.create_text_node('before').as_node()) or { panic(err) }
	root_node.append_child(start_branch_node) or { panic(err) }
	root_node.append_child(middle.as_node()) or { panic(err) }
	root_node.append_child(end_branch_node) or { panic(err) }
	root_node.append_child(document.create_text_node('after').as_node()) or { panic(err) }
	mut range := document.create_range()
	range.set_start(start.as_node(), 2) or { panic(err) }
	range.set_end(end.as_node(), 2) or { panic(err) }

	fragment := range.extract_contents() or { panic(err) }
	fragment_node := fragment.as_node()

	assert fragment_node.text_content() or { '' } == 'artmiddleen'
	assert root_node.text_content() or { '' } == 'beforestdafter'
	assert fragment_node.children.len == 3
	assert fragment_node.children[0].children[0].text_content() or { '' } == 'art'
	assert voidptr(fragment_node.children[1]) == voidptr(middle.as_node())
	assert start_branch_node.text_content() or { '' } == 'st'
	assert end_branch_node.text_content() or { '' } == 'd'
	assert root_node.children.len == 4
	assert voidptr(root_node.children[1]) == voidptr(start_branch_node)
	assert voidptr(root_node.children[2]) == voidptr(end_branch_node)
	assert range.collapsed()
	assert voidptr(range.start_container()) == voidptr(root_node)
	assert range.start_offset() == 2
}

fn test_delete_contents_collapses_spanning_range_before_mutations() {
	document, root, start, end := range_mutation_fixture()
	mut range := document.create_range()
	range.set_start(start.as_node(), 2) or { panic(err) }
	range.set_end(end.as_node(), 2) or { panic(err) }

	range.delete_contents() or { panic(err) }

	assert root.as_node().text_content() or { '' } == 'std'
	assert range.collapsed()
	assert range.start_container() == root.as_node()
	assert range.start_offset() == 1
}

fn test_insert_node_splits_a_cdata_section_start_node() {
	document := Document.create(url_about_blank())
	mut root := document.create_element('p') or { panic(err) }
	mut root_node := root.as_node()
	cdata := CDATASection.new(document, '1234')
	root_node.append_child(cdata.as_node()) or { panic(err) }
	inserted := document.create_element('b') or { panic(err) }
	mut range := document.create_range()
	range.set_start(cdata.as_node(), 2) or { panic(err) }
	range.set_end(cdata.as_node(), 2) or { panic(err) }

	range.insert_node(inserted.as_node()) or { panic(err) }

	children := root_node.children_as_vector()
	assert children.len == 3
	assert children[0] == cdata.as_node()
	assert children[0].text_content() or { '' } == '12'
	assert children[1] == inserted.as_node()
	assert children[2].text_content() or { '' } == '34'
}

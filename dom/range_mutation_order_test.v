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

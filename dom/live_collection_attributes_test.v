module dom

fn test_live_html_collection_rechecks_attribute_filters_without_tree_mutation() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element_ns(namespace_html_uri, 'div')!
	mut first := document.create_element_ns(namespace_html_uri, 'span')!
	mut second := document.create_element_ns(namespace_html_uri, 'span')!
	first.set_attribute_value('class', 'match')
	root.append_child(first)
	root.append_child(second)
	collection := root.get_elements_by_class_name('match')
	assert collection.length() == 1
	assert voidptr(collection.item(0)?) == voidptr(first)
	tree := document.dom_tree_version()
	second.set_attribute_value('class', 'match')
	assert document.dom_tree_version() == tree
	assert collection.length() == 2
	assert voidptr(collection.item(1)?) == voidptr(second)
	first.remove_attribute('class')
	assert collection.length() == 1
	assert voidptr(collection.item(0)?) == voidptr(second)
	assert collection.item(1) == none
	generation := collection.cache_generation_for_testing()
	assert collection.length() == 1
	assert collection.cache_generation_for_testing() == generation
}

fn test_tag_collection_reads_the_first_live_match_before_building_its_cache() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element('div')!
	mut nested := document.create_element('section')!.as_node()
	first := document.create_element('span')!
	mut second := document.create_element('span')!
	second.set_attribute_value('id', 'second')
	nested.append_child(first.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(document.create_text_node('text').as_node())!
	root_node.append_child(nested)!
	root_node.append_child(second.as_node())!

	wildcard := root.get_elements_by_tag_name('*')
	assert voidptr(wildcard.item(0)?.as_node()) == voidptr(nested)
	matches := root.get_elements_by_tag_name('span')
	assert matches.cache_generation_for_testing() == 0
	assert voidptr(matches.item(0)?) == voidptr(first)
	nested.remove_child(first.as_node())!
	assert voidptr(matches.item(0)?) == voidptr(second)
	assert matches.cache_generation_for_testing() == 0
	assert matches.length() == 1
	assert voidptr(matches.named_item('second')?) == voidptr(second)
	assert matches.item(1) == none
	root_node.remove_child(second.as_node())!
	assert matches.item(0) == none
}

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

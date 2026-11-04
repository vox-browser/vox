module dom

fn test_attribute_version_tracks_add_replace_remove_and_node_backed_edits() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element_ns(namespace_html_uri, 'link') or { panic(err) }
	mut node := document.as_node()
	node.append_child(element.as_node()) or { panic(err) }
	tree := document.dom_tree_version()
	mut previous := document.attribute_version()
	element.set_attribute_value('href', 'first.png')
	assert document.attribute_version() > previous
	previous = document.attribute_version()
	element.set_attribute_value('href', 'second.png')
	assert document.attribute_version() > previous
	previous = document.attribute_version()
	mut attrs := element.attributes()
	attrs.set_attribute(&Attr_{ name_: 'href', local_name_: 'href', value_: 'third.png' }) or { panic(err) }
	assert document.attribute_version() > previous
	previous = document.attribute_version()
	element.remove_attribute('href')
	assert document.attribute_version() > previous
	previous = document.attribute_version()
	element.remove_attribute('href')
	assert document.attribute_version() == previous
	element.set_attribute_value_ns('href', 'namespaced.png', 'x', 'urn:test')
	assert document.attribute_version() > previous
	assert document.dom_tree_version() == tree
}

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

fn test_light_dom_id_class_attribute_version_keeps_unrelated_attributes_separate() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element_ns(namespace_html_uri, 'div')!
	mut root := document.as_node()
	root.append_child(element.as_node())!
	initial := document.light_dom_id_class_attribute_version()
	element.set_attribute_value('aria-hidden', 'true')
	element.set_attribute_value('data-twiddle', '123')
	assert document.light_dom_id_class_attribute_version() == initial
	for name in ['id', 'class'] {
		before := document.light_dom_id_class_attribute_version()
		element.set_attribute_value(name, 'first')
		assert document.light_dom_id_class_attribute_version() > before
		changed := document.light_dom_id_class_attribute_version()
		element.remove_attribute(name)
		assert document.light_dom_id_class_attribute_version() > changed
	}
	before_namespace := document.light_dom_id_class_attribute_version()
	element.set_attribute_value_ns('class', 'namespaced', 'x', 'urn:test')
	assert document.light_dom_id_class_attribute_version() > before_namespace
}

fn test_light_dom_element_version_distinguishes_text_updates_and_element_replacement() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element_ns(namespace_html_uri, 'div')!
	mut root := document.as_node()
	root.append_child(element.as_node())!
	initial := document.light_dom_element_version()
	mut node := element.as_node()
	node.set_text_content('first')!
	node.set_text_content('second')!
	assert document.light_dom_element_version() == initial
	mut child := document.create_element_ns(namespace_html_uri, 'span')!
	node.append_child(child.as_node())!
	assert document.light_dom_element_version() > initial
	with_child := document.light_dom_element_version()
	node.set_text_content('replaced element')!
	assert document.light_dom_element_version() > with_child
}

fn test_light_dom_token_versions_ignore_detached_and_shadow_subtrees_until_inserted() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut host := document.create_element_ns(namespace_html_uri, 'div')!
	mut root := document.as_node()
	root.append_child(host.as_node())!
	structure := document.light_dom_element_version()
	attributes := document.light_dom_id_class_attribute_version()
	mut child := document.create_element_ns(namespace_html_uri, 'span')!
	child.set_attribute_value('id', 'detached')
	mut fragment := document.create_document_fragment()
	mut fragment_node := fragment.as_node()
	fragment_node.append_child(child.as_node())!
	assert document.light_dom_element_version() == structure
	assert document.light_dom_id_class_attribute_version() == attributes
	shadow := host.attach_shadow(ShadowRootInit{mode:.open})!
	mut shadow_node := shadow.as_node()
	shadow_node.append_child(fragment_node)!
	child.set_attribute_value('class', 'shadow')
	assert document.light_dom_element_version() == structure
	assert document.light_dom_id_class_attribute_version() == attributes
	mut host_node := host.as_node()
	host_node.append_child(child.as_node())!
	assert document.light_dom_element_version() > structure
	child.set_attribute_value('class', 'light')
	assert document.light_dom_id_class_attribute_version() > attributes
}

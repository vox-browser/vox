module dom

fn test_live_contenteditable_attributes_update_inherited_editability() {
	mut document := Document.create(url_about_blank())
	mut host := document.create_element_ns(namespace_html_uri, 'div')!
	mut child := document.create_element_ns(namespace_html_uri, 'span')!
	mut excluded := document.create_element_ns(namespace_html_uri, 'div')!
	mut nested := document.create_element_ns(namespace_html_uri, 'div')!
	excluded.set_attribute_value('contenteditable', 'false')
	nested.set_attribute_value('contenteditable', 'plaintext-only')
	mut host_node := host.as_node()
	host_node.append_child(child.as_node())!
	host_node.append_child(excluded.as_node())!
	mut excluded_node := excluded.as_node()
	excluded_node.append_child(nested.as_node())!
	text := document.create_text_node('text')
	mut child_node := child.as_node()
	child_node.append_child(text.as_node())!
	assert !child_node.is_editable()

	host.set_attribute_value('contenteditable', 'TrUe')
	assert host_node.is_editing_host()
	assert child_node.is_editable()
	assert text.as_node().is_editable()
	assert !excluded_node.is_editable_or_editing_host()
	assert nested.as_node().is_editing_host()
	host.remove_attribute('contenteditable')
	assert !host_node.is_editing_host()
	assert !child_node.is_editable()
	assert !text.as_node().is_editable()
	assert nested.as_node().is_editing_host()
}

fn test_design_mode_toggles_inherited_editability_and_preserves_explicit_boundaries() {
	mut document := Document.create(url_about_blank())
	mut root := document.create_element_ns(namespace_html_uri, 'html')!
	mut host := document.create_element_ns(namespace_html_uri, 'div')!
	mut excluded := document.create_element_ns(namespace_html_uri, 'div')!
	excluded.set_attribute_value('contenteditable', 'false')
	mut document_node := document.as_node()
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(host.as_node())!
	root_node.append_child(excluded.as_node())!
	assert document.design_mode() == 'off'
	document.set_design_mode('ON')!
	assert document.design_mode() == 'on'
	assert root_node.is_editing_host()
	assert host.as_node().is_editable()
	assert !excluded.as_node().is_editable_or_editing_host()
	document.set_design_mode('invalid')!
	assert document.design_mode() == 'on'
	document.set_design_mode('oFf')!
	assert document.design_mode() == 'off'
	assert !root_node.is_editing_host()
	assert !host.as_node().is_editable()
}

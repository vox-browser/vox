module dom

fn svg_use_test_element(mut document Document, name string) &Element {
	return document.create_element_ns(namespace_svg_uri, name) or { panic('${err}') }
}

fn test_svg_use_shadow_tree_tracks_referenced_element_changes_and_removal() {
	mut document := Document.create(URL{ value: 'https://example.test/image.svg' })
	document.completely_loaded_time = true
	mut svg_root := svg_use_test_element(mut document, 'svg')
	mut target := svg_use_test_element(mut document, 'g')
	target.set_attribute_value('id', 'shape')
	mut rect := svg_use_test_element(mut document, 'rect')
	mut target_node := target.as_node()
	target_node.append_child(rect.as_node())!
	mut use_element := svg_use_test_element(mut document, 'use')
	use_element.set_attribute_value('href', '#shape')

	mut document_node := unsafe { &Node(document) }
	document_node.append_child(svg_root.as_node())!
	mut svg_root_node := svg_root.as_node()
	svg_root_node.append_child(target.as_node())!
	svg_root_node.append_child(use_element.as_node())!
	use_element.svg_use_process_the_url()

	shadow_root := use_element.shadow_root() or { panic('use shadow root missing') }
	shadow_node := unsafe { &Node(shadow_root) }
	assert shadow_root.is_user_agent_internal()
	assert shadow_root.uses_document_style_sheets()
	assert shadow_node.children_as_vector().len == 1
	first_clone := shadow_node.first_child() or { panic('referenced clone missing') }
	first_clone_element := first_clone.as_element() or { panic('referenced clone is not an element') }
	assert first_clone_element.get_attribute_value('data-version') == ''

	target.set_attribute_value('data-version', 'two')
	assert shadow_node.children_as_vector().len == 1
	updated_clone := shadow_node.first_child() or { panic('updated clone missing') }
	updated_clone_element := updated_clone.as_element() or { panic('updated clone is not an element') }
	assert updated_clone_element.get_attribute_value('data-version') == 'two'
	assert updated_clone.children_as_vector().len == 1

	target_node.remove(false)
	assert shadow_node.children_as_vector().len == 0
}

fn test_svg_use_rejects_circular_reference_and_applies_dimensions_to_instance_root() {
	mut document := Document.create(URL{ value: 'https://example.test/image.svg' })
	mut svg_root := svg_use_test_element(mut document, 'svg')
	mut symbol := svg_use_test_element(mut document, 'symbol')
	symbol.set_attribute_value('id', 'symbol')
	mut use_element := svg_use_test_element(mut document, 'use')
	use_element.set_attribute_value('href', '#symbol')
	use_element.set_attribute_value('width', '40')
	use_element.set_attribute_value('height', '20')
	mut document_node := unsafe { &Node(document) }
	document_node.append_child(svg_root.as_node())!
	mut svg_root_node := svg_root.as_node()
	svg_root_node.append_child(symbol.as_node())!
	svg_root_node.append_child(use_element.as_node())!
	use_element.svg_use_process_the_url()

	shadow_root := use_element.shadow_root() or { panic('use shadow root missing') }
	clone := unsafe { &Node(shadow_root) }.first_child() or { panic('symbol clone missing') }
	clone_element := clone.as_element() or { panic('symbol clone is not an element') }
	assert clone_element.get_attribute_value('width') == '40'
	assert clone_element.get_attribute_value('height') == '20'
	assert clone_element.is_direct_child_of_svg_use_shadow_tree()

	mut nested_use := svg_use_test_element(mut document, 'use')
	nested_use.set_attribute_value('href', '#symbol')
	mut symbol_node := symbol.as_node()
	symbol_node.append_child(nested_use.as_node())!
	use_element.svg_use_process_the_url()
	assert unsafe { &Node(shadow_root) }.children_as_vector().len == 0
}

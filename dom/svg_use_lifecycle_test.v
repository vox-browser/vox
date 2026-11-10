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

fn test_svg_use_adoption_defers_the_new_documents_clone_until_reinsertion() {
	mut old_document := Document.create(URL{ value: 'https://old.example/image.svg' })
	mut new_document := Document.create(URL{ value: 'https://new.example/image.svg' })
	old_document.completely_loaded_time = true
	new_document.completely_loaded_time = true

	mut old_root := svg_use_test_element(mut old_document, 'svg')
	mut old_target := svg_use_test_element(mut old_document, 'g')
	old_target.set_attribute_value('id', 'shape')
	old_target.set_attribute_value('data-owner', 'old')
	mut use_element := svg_use_test_element(mut old_document, 'use')
	use_element.set_attribute_value('href', '#shape')
	mut old_document_node := unsafe { &Node(old_document) }
	old_document_node.append_child(old_root.as_node())!
	mut old_root_node := old_root.as_node()
	old_root_node.append_child(old_target.as_node())!
	old_root_node.append_child(use_element.as_node())!
	use_element.svg_use_process_the_url()

	mut new_root := svg_use_test_element(mut new_document, 'svg')
	mut new_target := svg_use_test_element(mut new_document, 'g')
	new_target.set_attribute_value('id', 'shape')
	new_target.set_attribute_value('data-owner', 'new')
	mut new_document_node := unsafe { &Node(new_document) }
	new_document_node.append_child(new_root.as_node())!
	mut new_root_node := new_root.as_node()
	new_root_node.append_child(new_target.as_node())!

	shadow_root := use_element.shadow_root() or { panic('use shadow root missing') }
	old_clone := unsafe { &Node(shadow_root) }.first_child() or { panic('old clone missing') }
	assert old_clone.as_element()?.get_attribute_value('data-owner') == 'old'

	new_document.adopt_node(use_element.as_node())
	assert voidptr(use_element.document()) == voidptr(new_document)
	assert !use_element.is_connected()
	assert !shadow_root.as_node().has_children()
	new_root_node.append_child(use_element.as_node())!
	new_clone := shadow_root.as_node().first_child() or { panic('new clone missing') }
	assert new_clone.as_element()?.get_attribute_value('data-owner') == 'new'
}

fn svg_use_test_instance(element &Element) ?&Element {
	return element.shadow_root()?.as_node().first_child()?.as_element()
}

fn svg_use_test_document_with_nested_symbol(address string) !&Document {
	mut document := Document.create(URL{ value: address })
	document.completely_loaded_time = true
	mut root := svg_use_test_element(mut document, 'svg')
	mut leaf := svg_use_test_element(mut document, 'rect')
	leaf.set_attribute_value('id', 'leaf')
	leaf.set_attribute_value('data-owner', address)
	mut symbol := svg_use_test_element(mut document, 'symbol')
	symbol.set_attribute_value('id', 'icon')
	mut nested := svg_use_test_element(mut document, 'use')
	nested.set_attribute_value('href', '#leaf')
	mut symbol_node := symbol.as_node()
	symbol_node.append_child(nested.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(leaf.as_node())!
	root_node.append_child(symbol_node)!
	mut document_node := document.as_node()
	document_node.append_child(root_node)!
	return document
}

fn test_svg_use_reconnection_refreshes_a_target_changed_while_detached() {
	for adopt_in_same_document in [false, true] {
		mut document := svg_use_test_document_with_nested_symbol('https://example.test/image.svg')!
		mut root_node := document.document_element()?.as_node()
		mut target := document.get_element_by_id('leaf')?
		mut use_element := svg_use_test_element(mut document, 'use')
		use_element.set_attribute_value('href', '#leaf')
		root_node.append_child(use_element.as_node())!
		assert svg_use_test_instance(use_element)?.get_attribute_value('data-owner') == document.url.serialize()

		if adopt_in_same_document {
			document.adopt_node(use_element.as_node())
		} else {
			mut use_node := use_element.as_node()
			use_node.remove(false)
		}
		assert !use_element.is_connected()
		assert voidptr(use_element.document()) == voidptr(document)
		target.set_attribute_value('data-owner', 'updated')
		// The connected-document observer cannot refresh this detached instance.
		assert svg_use_test_instance(use_element)?.get_attribute_value('data-owner') == document.url.serialize()
		root_node.append_child(use_element.as_node())!
		assert svg_use_test_instance(use_element)?.get_attribute_value('data-owner') == 'updated'
		document.finalize()
	}
}

fn test_svg_use_reconnection_clears_a_target_removed_while_detached() {
	mut document := svg_use_test_document_with_nested_symbol('https://example.test/image.svg')!
	defer { document.finalize() }
	mut root_node := document.document_element()?.as_node()
	mut use_element := svg_use_test_element(mut document, 'use')
	use_element.set_attribute_value('href', '#leaf')
	root_node.append_child(use_element.as_node())!
	assert svg_use_test_instance(use_element) != none

	mut use_node := use_element.as_node()
	use_node.remove(false)
	mut target_node := document.get_element_by_id('leaf')?.as_node()
	target_node.remove(false)
	assert svg_use_test_instance(use_element) != none
	root_node.append_child(use_node)!
	assert svg_use_test_instance(use_element) == none
}

fn test_svg_use_reconnection_resolves_a_target_replaced_while_detached() {
	mut document := svg_use_test_document_with_nested_symbol('https://example.test/image.svg')!
	defer { document.finalize() }
	mut root_node := document.document_element()?.as_node()
	mut use_element := svg_use_test_element(mut document, 'use')
	use_element.set_attribute_value('href', '#leaf')
	root_node.append_child(use_element.as_node())!
	assert svg_use_test_instance(use_element)?.local_name() == 'rect'

	mut use_node := use_element.as_node()
	use_node.remove(false)
	mut target_node := document.get_element_by_id('leaf')?.as_node()
	target_node.remove(false)
	mut replacement := svg_use_test_element(mut document, 'circle')
	replacement.set_attribute_value('id', 'leaf')
	replacement.set_attribute_value('data-owner', 'replacement')
	root_node.append_child(replacement.as_node())!
	assert svg_use_test_instance(use_element)?.local_name() == 'rect'
	root_node.append_child(use_node)!
	instance := svg_use_test_instance(use_element)?
	assert instance.local_name() == 'circle'
	assert instance.get_attribute_value('data-owner') == 'replacement'
}

fn test_svg_use_from_an_adopted_fragment_initializes_nested_instances_after_connection() {
	mut old_document := Document.create(URL{ value: 'https://old.example/template' })
	mut new_document := svg_use_test_document_with_nested_symbol('https://new.example/image.svg')!
	defer {
		old_document.finalize()
		new_document.finalize()
	}
	mut fragment := old_document.create_document_fragment().as_node()
	mut use_element := svg_use_test_element(mut old_document, 'use')
	use_element.set_attribute_value('href', '#icon')
	fragment.append_child(use_element.as_node())!
	new_document.adopt_node(fragment)
	assert svg_use_test_instance(use_element) == none
	mut root_node := new_document.document_element()?.as_node()
	root_node.append_child(fragment)!
	instance := svg_use_test_instance(use_element)?
	assert instance.local_name() == 'symbol'
	mut nested := instance.as_node().first_child()?.as_element()?
	nested_instance := svg_use_test_instance(nested)?
	assert nested_instance.get_attribute_value('data-owner') == 'https://new.example/image.svg'
	assert voidptr(nested.document()) == voidptr(new_document)
	// Replaying insertion for a UA clone must not rebuild its instance tree.
	nested.inserted()
	assert voidptr(svg_use_test_instance(nested)?) == voidptr(nested_instance)
}

fn test_svg_use_adoption_into_an_author_shadow_root_builds_the_missing_instance() {
	mut old_document := Document.create(URL{ value: 'https://old.example/image.svg' })
	mut new_document := svg_use_test_document_with_nested_symbol('https://new.example/image.svg')!
	defer {
		old_document.finalize()
		new_document.finalize()
	}
	mut host := new_document.create_element_ns(namespace_html_uri, 'div')!
	mut root_node := new_document.document_element()?.as_node()
	root_node.append_child(host.as_node())!
	shadow := host.attach_shadow(ShadowRootInit{ mode: .open })!
	mut use_element := svg_use_test_element(mut old_document, 'use')
	use_element.set_attribute_value('href', '#icon')
	new_document.adopt_node(use_element.as_node())
	assert svg_use_test_instance(use_element) == none
	mut shadow_node := shadow.as_node()
	shadow_node.append_child(use_element.as_node())!
	instance := svg_use_test_instance(use_element)?
	nested := instance.as_node().first_child()?.as_element()?
	assert svg_use_test_instance(nested)?.get_attribute_value('data-owner') == 'https://new.example/image.svg'
}

struct SVGUseAdoptionResources {
	documents map[string]&Document
}

fn svg_use_adoption_resource(target voidptr, address URL) ?&Document {
	resources := unsafe { &SVGUseAdoptionResources(target) }
	return resources.documents[address.serialize().all_before('#')] or { none }
}

fn test_svg_use_adoption_rebases_a_cached_external_reference_without_cloning_while_detached() {
	mut old_document := Document.create(URL{ value: 'https://example.test/a/page.svg' })
	mut new_document := Document.create(URL{ value: 'https://example.test/b/page.svg' })
	mut old_resource := svg_use_test_document_with_nested_symbol('https://example.test/a/icon.svg')!
	mut new_resource := svg_use_test_document_with_nested_symbol('https://example.test/b/icon.svg')!
	defer {
		old_document.finalize()
		new_document.finalize()
		old_resource.finalize()
		new_resource.finalize()
	}
	resources := &SVGUseAdoptionResources{
		documents: {
			old_resource.url.serialize(): old_resource
			new_resource.url.serialize(): new_resource
		}
	}
	hook := DocumentSVGUseResourceHook{ target: resources, resolve: svg_use_adoption_resource }
	old_document.set_svg_use_resource_hook(hook)
	new_document.set_svg_use_resource_hook(hook)
	mut new_root := svg_use_test_element(mut new_document, 'svg')
	mut new_document_node := new_document.as_node()
	new_document_node.append_child(new_root.as_node())!
	mut use_element := svg_use_test_element(mut old_document, 'use')
	use_element.set_attribute_value('href', 'icon.svg#icon')
	old_instance := svg_use_test_instance(use_element)?
	old_nested := old_instance.as_node().first_child()?.as_element()?
	assert svg_use_test_instance(old_nested)?.get_attribute_value('data-owner') == old_resource.url.serialize()
	new_document.adopt_node(use_element.as_node())
	assert svg_use_test_instance(use_element) == none
	assert !use_element.is_connected()
	mut new_root_node := new_root.as_node()
	new_root_node.append_child(use_element.as_node())!
	new_instance := svg_use_test_instance(use_element)?
	new_nested := new_instance.as_node().first_child()?.as_element()?
	assert svg_use_test_instance(new_nested)?.get_attribute_value('data-owner') == new_resource.url.serialize()
}

fn test_svg_use_direct_external_use_target_initializes_the_cloned_root() {
	mut document := Document.create(URL{ value: 'https://example.test/page.svg' })
	document.completely_loaded_time = true
	mut resource := svg_use_test_document_with_nested_symbol('https://example.test/sprite.svg')!
	defer {
		document.finalize()
		resource.finalize()
	}
	mut direct_target := svg_use_test_element(mut resource, 'use')
	direct_target.set_attribute_value('id', 'direct')
	direct_target.set_attribute_value('href', '#leaf')
	mut resource_root_node := resource.document_element()?.as_node()
	resource_root_node.append_child(direct_target.as_node())!
	resources := &SVGUseAdoptionResources{
		documents: {
			resource.url.serialize(): resource
		}
	}
	document.set_svg_use_resource_hook(DocumentSVGUseResourceHook{
		target:  resources
		resolve: svg_use_adoption_resource
	})
	mut root := svg_use_test_element(mut document, 'svg')
	mut document_node := document.as_node()
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	// The detached clone initially sees this page-local ID. Once attached to
	// the use shadow tree, the cloned root must resolve against the sprite URL.
	mut wrong_leaf := svg_use_test_element(mut document, 'rect')
	wrong_leaf.set_attribute_value('id', 'leaf')
	wrong_leaf.set_attribute_value('data-owner', 'page')
	root_node.append_child(wrong_leaf.as_node())!
	mut use_element := svg_use_test_element(mut document, 'use')
	use_element.set_attribute_value('href', 'sprite.svg#direct')
	root_node.append_child(use_element.as_node())!
	cloned_root := svg_use_test_instance(use_element)?
	assert cloned_root.local_name() == 'use'
	assert svg_use_test_instance(cloned_root)?.get_attribute_value('data-owner') == resource.url.serialize()
}

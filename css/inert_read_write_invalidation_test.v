module css

import dom

fn inert_selector_element(document &dom.Document, parent &dom.Node, tag string, id string) &dom.Element {
	mut element := document.create_element_ns(dom.namespace_html_uri, tag) or { panic(err) }
	if id != '' {
		element.set_attribute_value('id', id)
	}
	mut parent_node := unsafe { &dom.Node(parent) }
	parent_node.append_child(element.as_node()) or { panic(err) }
	return element
}

fn assert_inert_selector_styles_settled(document &dom.Document) {
	assert !document.needs_full_style_update()
	assert !document.needs_invalidation_of_elements_affected_by_has
	assert !document.as_node().needs_style_update()
	assert !document.as_node().child_needs_style_update()
}

fn inert_selector_fixture(source string, inherited_editability bool, inert_parent bool) (&dom.Document, &dom.Element, &dom.Element, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	document.set_browsing_context(&dom.BrowsingContext{})
	root := inert_selector_element(document, document.as_node(), 'html', '')
	body := inert_selector_element(document, root.as_node(), 'body', '')
	mut scope := inert_selector_element(document, body.as_node(), 'section', 'scope')
	if inherited_editability {
		scope.set_attribute_value('contenteditable', 'true')
	}
	mut editor := inert_selector_element(document, scope.as_node(), 'div', 'editor')
	if !inherited_editability {
		editor.set_attribute_value('contenteditable', 'true')
	}
	label := inert_selector_element(document, scope.as_node(), 'span', 'label')
	if inert_parent {
		scope.set_attribute_value('inert', '')
	}
	add_document_author_style_sheet(document, source)
	css_style_computer_for(document)
	assert document.style_computer().invalidation_plan_callback != unsafe { nil }
	document.update_style()
	assert_inert_selector_styles_settled(document)
	return document, scope, editor, label
}

fn inert_selector_retained_value(element &dom.Element, property PropertyID) string {
	style := computed_properties_for_element(element) or { panic('missing retained style') }
	value := style.property(property, .no) or { panic('missing retained property') }
	return value.css_text
}

fn test_inert_attribute_invalidates_read_write_and_read_only_sibling_styles() {
	for inherited_editability in [false, true] {
		mut document, _, mut editor, label := inert_selector_fixture('
			#editor:read-write + #label { color: red }
			#editor:read-only + #label { color: blue }', inherited_editability, false)
		defer { document.finalize() }
		assert editor.matches_read_write_pseudo_class()
		assert inert_selector_retained_value(label, .color) == 'rgb(255, 0, 0)'
		editor.set_attribute_value('inert', '')
		assert !editor.matches_read_write_pseudo_class()
		assert label.needs_style_update()
		assert !document.needs_full_style_update()
		document.update_style()
		assert inert_selector_retained_value(label, .color) == 'rgb(0, 0, 255)'
		assert_inert_selector_styles_settled(document)
		editor.remove_attribute('inert')
		assert editor.matches_read_write_pseudo_class()
		assert label.needs_style_update()
		document.update_style()
		assert inert_selector_retained_value(label, .color) == 'rgb(255, 0, 0)'
		assert_inert_selector_styles_settled(document)
	}
}

fn test_inert_attribute_invalidates_has_read_write_and_read_only_dependencies() {
	for pseudo_class in ['read-write', 'read-only'] {
		for inherited_editability in [false, true] {
			mut document, scope, mut editor, _ := inert_selector_fixture('
				#scope { background-color: blue }
				#scope:has(> #editor:${pseudo_class}) { background-color: red }',
				inherited_editability, false)
			defer { document.finalize() }
			before := if pseudo_class == 'read-write' { 'rgb(255, 0, 0)' } else { 'rgb(0, 0, 255)' }
			after := if pseudo_class == 'read-write' { 'rgb(0, 0, 255)' } else { 'rgb(255, 0, 0)' }
			assert inert_selector_retained_value(scope, .background_color) == before
			editor.set_attribute_value('inert', '')
			assert document.needs_invalidation_of_elements_affected_by_has
			assert !document.needs_full_style_update()
			document.update_style()
			assert inert_selector_retained_value(scope, .background_color) == after
			assert_inert_selector_styles_settled(document)
			editor.remove_attribute('inert')
			assert document.needs_invalidation_of_elements_affected_by_has
			document.update_style()
			assert inert_selector_retained_value(scope, .background_color) == before
			assert_inert_selector_styles_settled(document)
		}
	}
}

fn test_own_inert_attribute_keeps_read_write_dependencies_settled_under_inert_parent() {
	mut document, mut scope, mut editor, label := inert_selector_fixture('
		#label { color: blue }
		#editor:read-write + #label { color: red }
		#scope { background-color: blue }
		#scope:has(> #editor:read-write) { background-color: red }', false, true)
	defer { document.finalize() }
	for add_attribute in [true, false] {
		assert_inert_selector_styles_settled(document)
		if add_attribute {
			editor.set_attribute_value('inert', '')
		} else {
			editor.remove_attribute('inert')
		}
		assert !editor.matches_read_write_pseudo_class()
		assert !label.needs_style_update()
		assert !document.needs_invalidation_of_elements_affected_by_has
		document.update_style()
		assert inert_selector_retained_value(label, .color) == 'rgb(0, 0, 255)'
		assert inert_selector_retained_value(scope, .background_color) == 'rgb(0, 0, 255)'
	}
	scope.remove_attribute('inert')
	document.update_style()
	assert editor.matches_read_write_pseudo_class()
	assert inert_selector_retained_value(label, .color) == 'rgb(255, 0, 0)'
	assert inert_selector_retained_value(scope, .background_color) == 'rgb(255, 0, 0)'
	assert_inert_selector_styles_settled(document)
}

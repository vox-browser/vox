module css

import dom

fn custom_property_inheritance_test_element(document &dom.Document, name string) &dom.Element {
	return document.create_element_ns('http://www.w3.org/1999/xhtml', name) or {
		panic('${err}')
	}
}

fn test_registered_non_inheriting_custom_property_uses_initial_value_in_child() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := custom_property_inheritance_test_element(document, 'html')
	mut parent := custom_property_inheritance_test_element(document, 'div')
	parent.set_attribute_value('class', 'parent')
	mut child := custom_property_inheritance_test_element(document, 'span')
	child.set_attribute_value('class', 'child')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(parent.as_node()) or { panic('${err}') }
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic('${err}') }
	add_document_author_style_sheet(document, '@property --accent {
		syntax: "<color>";
		inherits: false;
		initial-value: green;
	}
	.parent { --accent: red; }
	.child { color: var(--accent); }')
	css_style_computer_for(document)
	document.needs_full_style_update = true
	document.update_style()

	assert computed_value_for(child, .color) or { '' } == 'rgb(0, 128, 0)'
}

fn test_inheritable_custom_property_cache_uses_document_identity_and_generation() {
	value := &dom.CSSStyleValue_{
		css_text: 'red'
	}
	data := dom.CSSCustomPropertyData_.create({
		'--accent': dom.CSSCustomProperty_{
			value: value
		}
	}, none)
	mut source_document := dom.Document.create(dom.url_about_blank())
	mut destination_document := dom.Document.create(dom.url_about_blank())
	register_property_for_document(mut source_document, PropertyDefinition{
		name: '--source-only'
		syntax: '*'
		inherits: true
	})!
	register_property_for_document(mut destination_document, PropertyDefinition{
		name: '--accent'
		syntax: '<color>'
		inherits: false
		initial_value: 'green'
	})!
	assert source_document.custom_property_registration_generation() == destination_document.custom_property_registration_generation()
	assert data.inheritable(source_document)? == data
	assert data.inheritable(destination_document) == none

	mut unregistered_document := dom.Document.create(dom.url_about_blank())
	assert data.inheritable(unregistered_document)? == data
	register_property_for_document(mut unregistered_document, PropertyDefinition{
		name: '--accent'
		syntax: '<color>'
		inherits: false
		initial_value: 'blue'
	})!
	assert data.inheritable(unregistered_document) == none
}

fn test_property_rule_cache_generation_changes_only_with_registrations() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut sheet := parse_css_stylesheet_with_parser('@property --accent {
		syntax: "<color>";
		inherits: false;
		initial-value: green;
	}', none)
	sheet.add_owning_document_or_shadow_root(unsafe { &dom.Node(document) })
	holder := css_author_style_sheets_for(document)
	unsafe {
		holder.sheets << sheet
	}
	mut scope := css_style_scope_for_document(document)
	scope.invalidate_rule_cache()
	css_style_computer_for(document)

	document.build_registered_properties_cache()
	first_generation := document.custom_property_registration_generation()
	assert first_generation == 1
	document.build_registered_properties_cache()
	assert document.custom_property_registration_generation() == first_generation

	sheet.set_disabled(true)
	document.build_registered_properties_cache()
	assert document.custom_property_registration_generation() == first_generation + 1
}

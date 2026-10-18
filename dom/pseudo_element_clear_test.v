module dom

fn test_clearing_missing_pseudo_layout_nodes_keeps_ordinary_elements_compact() {
	document := Document.create(url_about_blank())
	mut element := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	assert element.rare_data_ == unsafe { nil }
	for pseudo in [PseudoElement.before, .after, .first_letter, .marker] {
		element.set_pseudo_element_node(int(pseudo), none)
		assert element.get_pseudo_element(int(pseudo)) == none
	}
	assert element.pseudo_element_record_count() == 0
	assert element.rare_data_ == unsafe { nil }
}

fn test_clearing_pseudo_layout_preserves_existing_computed_style_and_record_identity() {
	document := Document.create(url_about_blank())
	mut element := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	pseudo_type := int(PseudoElement.before)
	properties := &CSSComputedProperties_{}
	element.set_computed_properties(pseudo_type, properties)
	record := element.get_pseudo_element(pseudo_type) or { panic('missing styled pseudo') }
	element.set_pseudo_element_node(pseudo_type, &LayoutNodeWithStyle_{})
	assert element.get_pseudo_element_node(pseudo_type) != none
	element.set_pseudo_element_node(pseudo_type, none)
	assert element.get_pseudo_element_node(pseudo_type) == none
	assert element.pseudo_element_record_count() == 1
	assert voidptr(element.get_pseudo_element(pseudo_type) or { panic('lost pseudo') }) == voidptr(record)
	assert voidptr(element.computed_properties_for_pseudo(pseudo_type) or { panic('lost computed style') }) == voidptr(properties)
}

fn test_clearing_missing_pseudo_keeps_other_pseudo_layout_owners_unchanged() {
	document := Document.create(url_about_blank())
	mut element := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	before := int(PseudoElement.before)
	node := &LayoutNodeWithStyle_{}
	element.set_pseudo_element_node(before, node)
	element.set_pseudo_element_node(int(PseudoElement.first_letter), none)
	assert element.pseudo_element_record_count() == 1
	assert voidptr(element.get_pseudo_element_node(before) or { panic('lost layout owner') }) == voidptr(node)
	element.set_pseudo_element_node(before, none)
	assert element.get_pseudo_element_node(before) == none
	element.set_pseudo_element_node(before, node)
	assert voidptr(element.get_pseudo_element_node(before) or { panic('lost replacement owner') }) == voidptr(node)
}

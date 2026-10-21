module css

import dom

fn literal_content_invalidation_properties(source string) &ComputedProperties {
	mut style := computed_properties_with_initial_values()
	value := parse_css_value_logic(.content, source) or { panic('expected content') }
	style.set_property(.content, dom_style_value_from_value_logic(value), .no, .no)
	return style
}

fn test_literal_content_invalidation_does_not_materialize_counter_styles() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or {
		panic(err)
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(element.as_node()) or { panic(err) }
	element.set_pseudo_element_node(int(dom.PseudoElement.before), &dom.LayoutNodeWithStyle_{})
	abstract_element := dom.AbstractElement.new(element, .before)
	mut old_style := literal_content_invalidation_properties('"label"')
	old_style.set_content(ContentData{ type_: .list, text: 'label' })
	new_style := literal_content_invalidation_properties('"label"')
	computer := StyleComputer.new(document)
	scope := css_style_scope_for(abstract_element)
	assert scope.needs_counter_style_cache_update
	unchanged := compute_required_invalidation(old_style, new_style, computer.font_computer(),
		abstract_element.unsafe_layout_node(), &abstract_element)
	assert !unchanged.needs_layout_tree_rebuild()
	assert scope.needs_counter_style_cache_update
	// Introducing a counter still rebuilds through ordinary content invalidation.
	changed_style := literal_content_invalidation_properties('counter(item, decimal)')
	changed := compute_required_invalidation(old_style, changed_style, computer.font_computer(),
		abstract_element.unsafe_layout_node(), &abstract_element)
	assert changed.needs_layout_tree_rebuild()
	assert scope.needs_counter_style_cache_update
}

fn test_counter_free_content_keeps_the_scope_registry_unmaterialized() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or { panic(err) }
	abstract_element := dom.AbstractElement.new(element, .before)
	scope := css_style_scope_for(abstract_element)
	for source in ['normal', 'none', '"counter(item)"', 'open-quote "label" close-quote',
		'url("icon.svg") / "image label"'] {
		style := literal_content_invalidation_properties(source)
		styles := registered_counter_styles_for_content(style, abstract_element)
		assert styles.len == 0
		_ = style.content(&abstract_element, 0, styles)
		assert scope.needs_counter_style_cache_update
	}
}

fn test_content_and_alternate_text_counters_still_resolve_author_definitions() {
	for source in ['counter(item, probe)', 'counters(item, ".", probe)',
		'"label" / counter(item, probe)'] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		add_document_author_style_sheet(document,
			'@counter-style probe { system: cyclic; symbols: "PASS"; suffix: ""; }')
		element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or { panic(err) }
		abstract_element := dom.AbstractElement.new(element, .before)
		style := literal_content_invalidation_properties(source)
		styles := registered_counter_styles_for_content(style, abstract_element)
		assert 'probe' in styles
		assert !css_style_scope_for(abstract_element).needs_counter_style_cache_update
		content := style.content(&abstract_element, 0, styles).content_data
		assert content.counter_style_dependencies.len == 1
		dependency := content.counter_style_dependencies[0] or { panic('lost counter dependency') }
		assert dependency.name() == 'probe'
	}
}

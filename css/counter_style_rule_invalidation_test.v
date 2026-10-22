module css

import dom

fn counter_style_invalidation_test_properties(property_id PropertyID, value_text string) &ComputedProperties {
	mut properties := computed_properties_with_initial_values()
	value := parse_css_value_logic(property_id, value_text) or {
		panic('could not parse ${property_id}: ${value_text}')
	}
	properties.set_property(property_id, dom_style_value_from_value_logic(value), .no, .no)
	return properties
}

fn attach_counter_style_invalidation_test_layout_node(mut element dom.Element) {
	mut node := element.as_node()
	node.set_layout_node(&dom.LayoutNode{
		dom_node_: node
	})
}

fn test_counter_style_equality_compares_every_effective_descriptor() {
	original := CounterStyle.decimal()
	same := CounterStyle.create(original.name(), original.algorithm(), original.negative_sign(), original.prefix(), original.suffix(), original.range(), original.fallback(), original.pad())
	assert original.equals(same)

	mut changed := same
	changed.suffix_ = 'changed'
	assert !original.equals(changed)
	changed = same
	changed.range_ = [CounterStyleRangeEntry{1, 2}]
	assert !original.equals(changed)
	changed = same
	changed.algorithm_ = CounterStyleAlgorithm(GenericCounterStyleAlgorithm{
		type_: .cyclic
		symbol_list: ['x']
	})
	assert !original.equals(changed)
}

fn test_predefined_square_counter_style_keeps_marker_suffix() {
	document := dom.Document.create(dom.url_about_blank())
	styles := registered_counter_styles_for_document(document)
	square := styles['square'] or { panic('missing predefined square counter style') }
	assert square.suffix() == ' '
}

fn test_counter_style_rule_mutation_invalidates_registered_style_cache() {
	mut document := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(document,
		'@counter-style marker { system: cyclic; symbols: "FAIL"; suffix: ""; }')
	styles_before := registered_counter_styles_for_document(document)
	assert generate_a_counter_representation(styles_before['marker'], styles_before, 1).contains('FAIL')

	holder := css_author_style_sheets_for(document)
	rule := holder.sheets[0].rules.rules[0]
	mut counter_style_rule := rule.counter_style_rule_value() or {
		panic('missing counter-style rule')
	}
	counter_style_rule.set_symbols('"PASS"')

	assert document.needs_full_style_update
	styles_after := registered_counter_styles_for_document(document)
	assert generate_a_counter_representation(styles_after['marker'], styles_after, 1).contains('PASS')
}

fn test_content_tracks_effective_counter_styles_and_invalidates_when_they_change() {
	mut document := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(document, '@counter-style marker { system: cyclic; symbols: "FAIL"; suffix: ""; }')
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or {
		panic(err)
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(element.as_node()) or { panic(err) }
	element.set_pseudo_element_node(int(dom.PseudoElement.before), &dom.LayoutNodeWithStyle_{})
	abstract_element := dom.AbstractElement.new(element, .before)
	old_style := counter_style_invalidation_test_properties(.content, 'counter(item, marker) / counter(item, marker)')
	new_style := counter_style_invalidation_test_properties(.content, 'counter(item, marker) / counter(item, marker)')
	old_content := old_style.content(&abstract_element, 0, registered_counter_styles_for_abstract_element(abstract_element)).content_data
	assert old_content.counter_style_dependencies.len == 2
	assert (old_content.counter_style_dependencies[0] or { panic('missing dependency') }).suffix() == ''
	mut old_values := unsafe { &MutableComputedValues(old_style) }
	old_values.set_content(old_content)
	computer := StyleComputer.new(document)
	assert !compute_required_invalidation(old_style, new_style, computer.font_computer(), abstract_element.unsafe_layout_node(), abstract_element).needs_layout_tree_rebuild()

	holder := css_author_style_sheets_for(document)
	mut sheet := holder.sheets[0]
	sheet.insert_rule('@counter-style marker { system: cyclic; symbols: "PASS"; suffix: ""; }', u32(sheet.rules.rules.len))!
	invalidation := compute_required_invalidation(old_style, new_style, computer.font_computer(), abstract_element.unsafe_layout_node(), abstract_element)
	assert invalidation.needs_layout_tree_rebuild()
	assert invalidation.needs_relayout()
	assert invalidation.needs_repaint()
}

fn test_list_style_type_invalidates_when_effective_counter_style_changes() {
	mut document := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(document, '@counter-style marker { system: cyclic; symbols: "FAIL"; suffix: ""; }')
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'li') or {
		panic(err)
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(element.as_node()) or { panic(err) }
	attach_counter_style_invalidation_test_layout_node(mut element)
	abstract_element := dom.AbstractElement.new(element, none)
	old_style := counter_style_invalidation_test_properties(.list_style_type, 'marker')
	new_style := counter_style_invalidation_test_properties(.list_style_type, 'marker')
	mut old_values := unsafe { &MutableComputedValues(old_style) }
	old_values.set_list_style_type(old_style.list_style_type_for_scope(css_style_scope_for(abstract_element)))
	computer := StyleComputer.new(document)
	assert !compute_required_invalidation(old_style, new_style, computer.font_computer(), abstract_element.unsafe_layout_node(), abstract_element).needs_layout_tree_rebuild()

	holder := css_author_style_sheets_for(document)
	mut sheet := holder.sheets[0]
	sheet.insert_rule('@counter-style marker { system: cyclic; symbols: "PASS"; suffix: ""; }', u32(sheet.rules.rules.len))!
	assert compute_required_invalidation(old_style, new_style, computer.font_computer(), abstract_element.unsafe_layout_node(), abstract_element).needs_layout_tree_rebuild()
}

fn test_invalid_counter_style_descriptor_does_not_invalidate() {
	mut document := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(document,
		'@counter-style marker { system: cyclic; symbols: "PASS"; }')
	_ = registered_counter_styles_for_document(document)
	document.needs_full_style_update = false

	holder := css_author_style_sheets_for(document)
	mut counter_style_rule := holder.sheets[0].rules.rules[0].counter_style_rule_value() or {
		panic('missing counter-style rule')
	}
	counter_style_rule.set_symbols('')
	assert !document.needs_full_style_update
}

fn test_insert_rule_rebuilds_registered_counter_styles_lazily() {
	mut document := dom.Document.create(dom.url_about_blank())
	document_node := unsafe { &dom.Node(document) }
	mut sheet := css_style_sheet_construct(none, document)!
	mut list := create_adopted_style_sheets_list(document_node)
	list.append(sheet)!

	styles_before := registered_counter_styles_for_document(document)
	assert 'dynamic-marker' !in styles_before
	sheet.insert_rule('@counter-style dynamic-marker { system: cyclic; symbols: "PASS"; suffix: ""; }', 0)!
	styles_after := registered_counter_styles_for_document(document)
	assert generate_a_counter_representation(styles_after['dynamic-marker'], styles_after, 1).contains('PASS')
}

fn test_replace_sync_rebuilds_registered_counter_styles_lazily() {
	mut document := dom.Document.create(dom.url_about_blank())
	document_node := unsafe { &dom.Node(document) }
	mut sheet := css_style_sheet_construct(none, document)!
	sheet.replace_sync('@counter-style dynamic-marker { system: cyclic; symbols: "FAIL"; suffix: ""; }')!
	mut list := create_adopted_style_sheets_list(document_node)
	list.append(sheet)!

	styles_before := registered_counter_styles_for_document(document)
	assert generate_a_counter_representation(styles_before['dynamic-marker'], styles_before, 1).contains('FAIL')
	sheet.replace_sync('@counter-style dynamic-marker { system: cyclic; symbols: "PASS"; suffix: ""; }')!
	styles_after := registered_counter_styles_for_document(document)
	assert generate_a_counter_representation(styles_after['dynamic-marker'], styles_after, 1).contains('PASS')
}

fn test_counter_styles_are_resolved_in_their_global_tree_scope() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(host.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	inside := document.create_element_ns('http://www.w3.org/1999/xhtml', 'ol') or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.append_child(inside.as_node()) or { panic(err) }
	mut nested_host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	shadow_node.append_child(nested_host.as_node()) or { panic(err) }
	nested_shadow_root := nested_host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or {
		panic(err)
	}
	nested_inside := document.create_element_ns('http://www.w3.org/1999/xhtml', 'ol') or {
		panic(err)
	}
	mut nested_shadow_node := unsafe { &dom.Node(nested_shadow_root) }
	nested_shadow_node.append_child(nested_inside.as_node()) or { panic(err) }

	add_document_author_style_sheet(document, '
		@counter-style outer { system: cyclic; symbols: "OUTER"; suffix: ""; }
		@counter-style shared { system: cyclic; symbols: "DOCUMENT"; suffix: ""; }
		@counter-style outer-extends-inner { system: extends inner; suffix: ""; }
	')
	add_shadow_root_author_style_sheet(shadow_root, '
		@counter-style inner { system: cyclic; symbols: "INNER"; suffix: ""; }
		@counter-style shared { system: cyclic; symbols: "SHADOW"; suffix: ""; }
		@counter-style inner-extends-outer { system: extends outer; suffix: ""; }
	')

	document_styles := registered_counter_styles_for_document(document)
	shadow_styles := registered_counter_styles_for_abstract_element(dom.AbstractElement.new(inside, none))
	nested_shadow_styles := registered_counter_styles_for_abstract_element(dom.AbstractElement.new(nested_inside, none))
	assert 'inner' !in document_styles
	assert generate_a_counter_representation(document_styles['shared'], document_styles, 1) == 'DOCUMENT'
	assert generate_a_counter_representation(document_styles['outer-extends-inner'], document_styles, 1) == '1'
	assert generate_a_counter_representation(shadow_styles['inner'], shadow_styles, 1) == 'INNER'
	assert generate_a_counter_representation(shadow_styles['shared'], shadow_styles, 1) == 'SHADOW'
	assert generate_a_counter_representation(shadow_styles['inner-extends-outer'], shadow_styles, 1) == 'OUTER'
	assert generate_a_counter_representation(nested_shadow_styles['shared'], nested_shadow_styles, 1) == 'SHADOW'
}

module css

import dom

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

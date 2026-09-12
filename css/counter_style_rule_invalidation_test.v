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

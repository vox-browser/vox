module css

import dom

fn shadow_counter_text(root &dom.ShadowRoot) string {
	styles := registered_counter_styles_for_scope(css_style_scope_for_shadow_root(root))
	return generate_a_counter_representation(styles['marker'], styles, 1)
}

fn test_document_counter_style_mutation_refreshes_detached_nested_shadow_roots() {
	document := dom.Document.create(dom.url_about_blank())
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	outer := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	mut nested_host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut outer_node := unsafe { &dom.Node(outer) }
	outer_node.append_child(nested_host.as_node())!
	inner := nested_host.attach_shadow(dom.ShadowRootInit{ mode: .closed })!
	add_document_author_style_sheet(document,
		'@counter-style marker { system: cyclic; symbols: "BEFORE"; suffix: ""; }')
	assert shadow_counter_text(outer) == 'BEFORE'
	assert shadow_counter_text(inner) == 'BEFORE'

	holder := css_author_style_sheets_for(document)
	mut rule := holder.sheets[0].rules.rules[0].counter_style_rule_value() or {
		panic('missing counter-style rule')
	}
	rule.set_symbols('"AFTER"')
	assert shadow_counter_text(outer) == 'AFTER'
	assert shadow_counter_text(inner) == 'AFTER'
}

fn test_adopted_shadow_counter_cache_receives_only_its_new_document_invalidations() {
	mut source := dom.Document.create(dom.url_about_blank())
	mut destination := dom.Document.create(dom.url_about_blank())
	mut host := source.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	root := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	add_document_author_style_sheet(source,
		'@counter-style marker { system: cyclic; symbols: "SOURCE"; suffix: ""; }')
	add_document_author_style_sheet(destination,
		'@counter-style marker { system: cyclic; symbols: "DESTINATION"; suffix: ""; }')
	assert shadow_counter_text(root) == 'SOURCE'
	destination.adopt_node(host.as_node())
	assert shadow_counter_text(root) == 'DESTINATION'

	source_holder := css_author_style_sheets_for(source)
	mut source_rule := source_holder.sheets[0].rules.rules[0].counter_style_rule_value() or {
		panic('missing source counter-style rule')
	}
	source_rule.set_symbols('"OLD"')
	scope := css_style_scope_for_shadow_root(root)
	assert !scope.needs_counter_style_cache_update
	assert shadow_counter_text(root) == 'DESTINATION'

	destination_holder := css_author_style_sheets_for(destination)
	mut destination_rule := destination_holder.sheets[0].rules.rules[0].counter_style_rule_value() or {
		panic('missing destination counter-style rule')
	}
	destination_rule.set_symbols('"UPDATED"')
	assert shadow_counter_text(root) == 'UPDATED'
}

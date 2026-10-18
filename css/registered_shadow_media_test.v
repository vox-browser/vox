module css

import dom

fn registered_media_document(width f64) &dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	document.set_viewport_rect(dom.Rect{0, 0, width, 600})
	_ = css_style_computer_for(document)
	return document
}

fn test_registered_shadow_media_visits_nested_connected_scopes() {
	mut document := registered_media_document(500)
	defer { document.finalize() }
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(host.as_node())!
	outer := host.attach_shadow(dom.ShadowRootInit{mode: .closed})!
	mut nested_host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut outer_node := unsafe { &dom.Node(outer) }
	outer_node.append_child(nested_host.as_node())!
	inner := nested_host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	for root in [outer, inner] {
		add_shadow_root_author_style_sheet(root, '@media (min-width:600px) { span { color:red } }')
	}
	document.evaluate_media_rules()
	for root in [outer, inner] {
		mut scope := css_style_scope_for_shadow_root(root)
		scope.build_rule_cache_if_needed()
		assert scope.has_valid_rule_cache()
	}
	assert document.registered_shadow_roots().len == 2
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	document.evaluate_media_rules()
	for root in [outer, inner] {
		assert !css_style_scope_for_shadow_root(root).has_valid_rule_cache()
	}
}

fn test_registered_shadow_media_keeps_disconnected_scopes_unevaluated_until_connection() {
	mut document := registered_media_document(500)
	defer { document.finalize() }
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	root := host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	add_shadow_root_author_style_sheet(root, '@media (min-width:600px) { span { color:red } }')
	mut scope := css_style_scope_for_shadow_root(root)
	mut sheet := scope.author_style_sheets[0]
	_ = sheet.evaluate_media_queries(document)
	scope.build_rule_cache_if_needed()
	assert !scope.author_style_sheets[0].rules.rules[0].condition_matches()
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	document.evaluate_media_rules()
	assert scope.has_valid_rule_cache()
	assert !scope.author_style_sheets[0].rules.rules[0].condition_matches()
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(host.as_node())!
	document.evaluate_media_rules()
	assert scope.author_style_sheets[0].rules.rules[0].condition_matches()
	scope.build_rule_cache_if_needed()
	document.set_viewport_rect(dom.Rect{0, 0, 500, 600})
	document.evaluate_media_rules()
	assert !scope.has_valid_rule_cache()
	assert !scope.author_style_sheets[0].rules.rules[0].condition_matches()
}

fn test_registered_shadow_media_moves_with_adopted_host() {
	mut source := registered_media_document(500)
	mut destination := registered_media_document(500)
	defer { source.finalize(); destination.finalize() }
	mut host := source.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	root := host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	add_shadow_root_author_style_sheet(root, '@media (min-width:600px) { span { color:red } }')
	destination.adopt_node(host.as_node())
	mut destination_node := unsafe { &dom.Node(destination) }
	destination_node.append_child(host.as_node())!
	assert source.registered_shadow_roots().len == 0
	assert destination.registered_shadow_roots().len == 1
	destination.evaluate_media_rules()
	mut scope := css_style_scope_for_shadow_root(root)
	scope.build_rule_cache_if_needed()
	source.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	source.evaluate_media_rules()
	assert scope.has_valid_rule_cache()
	destination.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	destination.evaluate_media_rules()
	assert !scope.has_valid_rule_cache()
}

module css

import dom

fn build_scope_invalidation_cache(source string) &StyleScope {
	mut document := dom.Document.create(dom.url_about_blank())
	mut sheet := parse_css_stylesheet_with_parser(source, none)
	sheet.add_owning_document_or_shadow_root(unsafe { &dom.Node(document) })
	holder := css_author_style_sheets_for(document)
	unsafe {
		holder.sheets << sheet
	}
	mut scope := css_style_scope_for_document(document)
	scope.invalidate_rule_cache()
	scope.build_rule_cache_if_needed()
	return scope
}

fn test_scope_boundary_mutations_invalidate_descendant_styles() {
	scope := build_scope_invalidation_cache('@scope (.root) to (.limit) { .target { color: red } }')
	data := scope.style_invalidation_data or { panic('missing invalidation data') }

	root_plan := data.plan_for_property(InvalidationProperty.class('root')) or {
		panic('missing scope root invalidation')
	}
	assert root_plan.invalidate_whole_subtree
	limit_plan := data.plan_for_property(InvalidationProperty.class('limit')) or {
		panic('missing scope limit invalidation')
	}
	assert limit_plan.invalidate_whole_subtree
}

fn test_scope_boundary_selectors_contribute_selector_insights() {
	scope := build_scope_invalidation_cache('@scope (.root:has(.flag)) { .target { color: red } }')
	insights := scope.selector_insights or { panic('missing selector insights') }
	assert insights.has_has_selectors
	data := scope.style_invalidation_data or { panic('missing invalidation data') }
	assert data.class_names_used_in_has_selectors['flag']
}

fn test_slotted_argument_contributes_selector_insights() {
	scope := build_scope_invalidation_cache('::slotted(.item:has(.flag)) { color: red }')
	insights := scope.selector_insights or { panic('missing selector insights') }
	assert insights.has_has_selectors
	data := scope.style_invalidation_data or { panic('missing invalidation data') }
	assert data.class_names_used_in_has_selectors['flag']
}

fn test_scope_root_class_change_invalidates_its_subtree() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut html := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic(err)
	}
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	root.set_attribute_value('class', 'root')
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html.as_node()) or { panic(err) }
	mut html_node := html.as_node()
	html_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(target.as_node()) or { panic(err) }

	mut sheet := parse_css_stylesheet_with_parser('@scope (.root) { .target { color: red } }',
		none)
	sheet.add_owning_document_or_shadow_root(unsafe { &dom.Node(document) })
	holder := css_author_style_sheets_for(document)
	unsafe {
		holder.sheets << sheet
	}
	mut scope := css_style_scope_for_document(document)
	scope.invalidate_rule_cache()
	scope.build_rule_cache_if_needed()

	document.set_needs_full_style_update(false)
	document_node.set_entire_subtree_needs_style_update(false)
	html_node.set_entire_subtree_needs_style_update(false)
	root_node.set_entire_subtree_needs_style_update(false)
	mut target_node := target.as_node()
	target_node.set_entire_subtree_needs_style_update(false)
	root.set_attribute_value('class', 'not-root')
	assert root_node.entire_subtree_needs_style_update()
}

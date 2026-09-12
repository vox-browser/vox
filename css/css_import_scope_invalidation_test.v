module css

import dom

fn test_import_broadness_comes_from_effective_imported_rules() {
	mut parent := parse_css_stylesheet_with_parser('@import url(imported.css) scope(.root);', none)
	mut import_rule := parent.rules.item(0) or { panic('missing import rule') }
	mut imported := parse_css_stylesheet_with_parser('@layer B, A;', none)
	import_rule.set_style_sheet(imported)

	assert !build_invalidation_set_for_stylesheet(parent).invalidation_set.needs_invalidate_whole_subtree()
	assert stylesheet_requires_broad_add_or_remove_invalidation(parent)

	plain := parse_css_stylesheet_with_parser('@import url(unloaded.css);', none)
	assert !stylesheet_requires_broad_add_or_remove_invalidation(plain)
}

fn test_import_scope_boundaries_seed_invalidation_and_selector_insights() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut parent_sheet := parse_css_stylesheet_with_parser('@import url(imported.css) scope(.root:has(.flag));', none)
	parent_sheet.add_owning_document_or_shadow_root(unsafe { &dom.Node(document) })
	mut import_rule := parent_sheet.rules.item(0) or { panic('missing import rule') }
	mut imported_sheet := parse_css_stylesheet_with_parser('.target { color: red }', none)
	import_rule.set_style_sheet(imported_sheet)
	holder := css_author_style_sheets_for(document)
	unsafe {
		holder.sheets << parent_sheet
	}
	mut scope := css_style_scope_for_document(document)
	scope.invalidate_rule_cache()
	scope.build_rule_cache_if_needed()

	data := scope.style_invalidation_data or { panic('missing invalidation data') }
	root_plan := data.plan_for_property(InvalidationProperty.class('root')) or {
		panic('missing imported scope root invalidation')
	}
	assert root_plan.invalidate_whole_subtree
	assert data.class_names_used_in_has_selectors['flag']
	insights := scope.selector_insights or { panic('missing selector insights') }
	assert insights.has_has_selectors
}

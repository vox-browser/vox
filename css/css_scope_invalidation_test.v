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

fn test_has_invalidation_tracks_featureless_and_sibling_sensitive_arguments() {
	filtered_scope := build_scope_invalidation_cache('section:has(.flag) { color: red }')
	filtered_data := filtered_scope.style_invalidation_data or { panic('missing invalidation data') }
	assert filtered_data.class_names_used_in_has_selectors['flag']
	assert !filtered_data.has_selectors_sensitive_to_featureless_subtree_changes

	universal_scope := build_scope_invalidation_cache('section:has(*) { color: red }')
	universal_data := universal_scope.style_invalidation_data or {
		panic('missing universal invalidation data')
	}
	assert universal_data.has_selectors_sensitive_to_featureless_subtree_changes

	state_scope := build_scope_invalidation_cache('section:has(:default) { color: red }')
	state_data := state_scope.style_invalidation_data or { panic('missing state invalidation data') }
	assert CSSPseudoClass.default_ !in state_data.pseudo_classes_used_in_has_selectors
	assert state_data.has_selectors_sensitive_to_featureless_subtree_changes

	sibling_scope := build_scope_invalidation_cache('.anchor:has(+ .peer) { color: red }')
	sibling_insights := sibling_scope.selector_insights or { panic('missing selector insights') }
	assert sibling_insights.has_has_selectors_with_relative_selector_that_has_sibling_combinator
}

fn test_pending_has_invalidations_deduplicate_by_node_without_changing_order() {
	document := dom.Document.create(dom.url_about_blank())
	mut first := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	mut second := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	mut scope := StyleScope.new(unsafe { &dom.Node(document) })
	scope.record_pending_has_invalidation_mutation_properties(first.as_node(), [
		InvalidationProperty.class('first'),
	])
	scope.record_pending_has_invalidation_mutation_properties(second.as_node(), [
		InvalidationProperty.id('second'),
	])
	scope.record_pending_has_invalidation_mutation_properties(first.as_node(), [
		InvalidationProperty.attribute('data-state'),
	])

	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 2
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has[0].unique_id() == first.as_node().unique_id()
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has[1].unique_id() == second.as_node().unique_id()
	first_features := scope.pending_has_invalidation_features[first.as_node().unique_id().value()] or {
		panic('missing first invalidation')
	}
	assert first_features.class_names['first']
	assert first_features.attribute_names['data-state']
	assert !first_features.is_conservative

	// A later conservative scheduler observes the existing entry without
	// replacing the precise mutation features.
	scope.schedule_ancestors_style_invalidation_due_to_presence_of_has(first.as_node())
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 2
	assert !first_features.is_conservative
	scope.schedule_ancestors_style_invalidation_due_to_presence_of_has(document.as_node())
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 3
	root_features := scope.pending_has_invalidation_features[document.as_node().unique_id().value()] or {
		panic('missing document invalidation')
	}
	assert root_features.is_conservative
}

fn test_pending_has_mutation_features_track_pseudo_classes_and_sibling_relationships() {
	document := dom.Document.create(dom.url_about_blank())
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	pseudo_class_features := collect_pending_has_invalidation_mutation_features_from_properties([
		InvalidationProperty.pseudo_class(.checked),
	])
	assert pseudo_class_features.pseudo_classes[.checked]
	assert selector_may_match_pending_has_mutation_features(selector_from_text(':checked'), pseudo_class_features)
	assert !selector_may_match_pending_has_mutation_features(selector_from_text(':empty'), pseudo_class_features)
	// Stateful pseudo-classes that cannot be represented as concrete mutation
	// features retain conservative invalidation.
	assert selector_may_match_pending_has_mutation_features(selector_from_text(':hover'), pseudo_class_features)

	mut class_features := collect_pending_has_invalidation_mutation_features_from_properties([
		InvalidationProperty.class('unrelated'),
	])
	sibling_selector := selector_from_text('.left + .right')
	assert !selector_may_match_pending_has_mutation_features(sibling_selector, class_features)
	class_features.may_affect_sibling_relationships = true
	assert selector_may_match_pending_has_mutation_features(sibling_selector, class_features)

	structural_features := collect_pending_has_invalidation_mutation_features(element.as_node(), true)
	assert structural_features.may_affect_sibling_relationships
	assert structural_features.may_affect_pseudo_classes
}

fn test_slotted_argument_builds_invalidation_sets() {
	scope := build_scope_invalidation_cache('::slotted(.item[data-state]) { color: red }')
	data := scope.style_invalidation_data or { panic('missing invalidation data') }
	assert data.plan_for_property(InvalidationProperty.class('item')) != none
	assert data.plan_for_property(InvalidationProperty.attribute('data-state')) != none
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

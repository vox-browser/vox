module css

// This view keeps the typed tree and deliberately has no metadata bits. That
// selects the uncached path without changing any invalidation input or result.
fn invalidation_projection_uncached_view(selector Selector) Selector {
	return Selector{data_: &SelectorData{compound_selectors: selector.compound_selectors()}}
}

fn invalidation_projection_signature(data &StyleInvalidationData) []string {
	return [data.invalidation_plans.str(), data.invalidation_plan_properties.str(),
		data.ids_used_in_has_selectors.str(), data.class_names_used_in_has_selectors.str(),
		data.attribute_names_used_in_has_selectors.str(), data.tag_names_used_in_has_selectors.str(),
		data.pseudo_classes_used_in_has_selectors.str(),
		data.has_selectors_sensitive_to_featureless_subtree_changes.str()]
}

fn test_invalidation_projection_matches_uncached_typed_tree_for_nested_features() {
	for text in ['.plain', '*', '.root:is(.a .b, .c:not(.off)) > .target',
		'.root:where(.a:is(.b, .c), .d) .target', '.owner:has(> .flag) .target',
		'.owner:has(:is(.a .b, .c))', '.owner:not(:is(.a:has(.flag) .tail))',
		'.root:nth-child(2n of :is(.a, .b)) .target',
		'.root:nth-last-child(odd of .a:not(.off)) .target',
		'slot::slotted(:is(.a, .b))', '[data-key]:is(#a, .b):hover',
		'.root:is(.a + .b, .c ~ .d) .target'] {
		selector := selector_from_text(text)
		mut actual := StyleInvalidationData.new()
		mut reference := StyleInvalidationData.new()
		actual.build_invalidation_sets_for_selector(selector)
		reference.build_invalidation_sets_for_selector(invalidation_projection_uncached_view(selector))
		assert invalidation_projection_signature(actual) == invalidation_projection_signature(reference)
		assert actual.invalidation_plans.keys() == reference.invalidation_plans.keys()
	}
}

fn test_invalidation_projection_observes_live_edits_between_public_builds() {
	selector := selector_from_text('.owner:is(.original .target)')
	mut actual := StyleInvalidationData.new()
	actual.build_invalidation_sets_for_selector(selector)
	assert actual.plan_for_property(InvalidationProperty.class('original')) != none
	mut data := selector.data_
	data.compound_selectors = selector_from_text('.owner:is(.replacement .target)').compound_selectors()
	gc_collect()
	actual.build_invalidation_sets_for_selector(selector)
	assert actual.plan_for_property(InvalidationProperty.class('replacement')) != none
	assert actual.plan_for_property(InvalidationProperty.class('original')) != none
	mut reference := StyleInvalidationData.new()
	reference.build_invalidation_sets_for_selector(invalidation_projection_uncached_view(selector))
	assert reference.plan_for_property(InvalidationProperty.class('replacement')) != none
	assert reference.plan_for_property(InvalidationProperty.class('original')) == none
}

fn test_invalidation_projection_keeps_scope_boundary_payload_separate() {
	selector := selector_from_text('.root:is(.ancestor .target)')
	mut actual := StyleInvalidationData.new()
	mut reference := StyleInvalidationData.new()
	actual.build_invalidation_sets_for_selector(selector)
	reference.build_invalidation_sets_for_selector(invalidation_projection_uncached_view(selector))
	actual.build_invalidation_sets_for_scope_boundary_selector(selector)
	reference.build_invalidation_sets_for_scope_boundary_selector(invalidation_projection_uncached_view(selector))
	assert invalidation_projection_signature(actual) == invalidation_projection_signature(reference)
	plan := actual.plan_for_property(InvalidationProperty.class('root')) or { panic('missing root plan') }
	assert plan.invalidate_whole_subtree
	gc_collect()
	assert (actual.plan_for_property(InvalidationProperty.class('root')) or { panic('lost root plan') }).invalidate_whole_subtree
}

fn test_invalidation_projection_result_survives_releasing_its_selector_graph() {
	text := ['.owner:is(', '.original .target, .fallback', ')'].join('')
	selector := selector_from_text(text)
	mut actual := StyleInvalidationData.new()
	actual.build_invalidation_sets_for_selector(selector)
	mut data := selector.data_
	data.text = ''
	data.compound_selectors = []CompoundSelector{}
	gc_collect()
	assert actual.plan_for_property(InvalidationProperty.class('original')) != none
	property := actual.invalidation_plan_properties[InvalidationProperty.class('original').key()] or { panic('lost original property') }
	assert property.value == 'original'
	assert actual.plan_for_property(InvalidationProperty.class('fallback')) != none
}

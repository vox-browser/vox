module css

import platform

fn assert_owned_invalidation_matches_reference(actual &StyleInvalidationData, expected &StyleInvalidationData) {
	assert actual.invalidation_plans.keys() == expected.invalidation_plans.keys()
	for key, plan in expected.invalidation_plans {
		assert invalidation_plans_equal(actual.invalidation_plans[key], plan), key
		assert actual.invalidation_plan_properties[key] == expected.invalidation_plan_properties[key]
	}
	assert actual.ids_used_in_has_selectors == expected.ids_used_in_has_selectors
	assert actual.class_names_used_in_has_selectors == expected.class_names_used_in_has_selectors
	assert actual.attribute_names_used_in_has_selectors == expected.attribute_names_used_in_has_selectors
	assert actual.tag_names_used_in_has_selectors == expected.tag_names_used_in_has_selectors
	assert actual.pseudo_classes_used_in_has_selectors == expected.pseudo_classes_used_in_has_selectors
	assert actual.has_selectors_sensitive_to_featureless_subtree_changes == expected.has_selectors_sensitive_to_featureless_subtree_changes
}

fn test_owned_selector_invalidation_preserves_plan_unions_and_nested_feature_dependencies() {
	mut actual := StyleInvalidationData{}
	mut reference := StyleInvalidationData{}
	for text in ['div', '.root .child', '.root > :is(.first, #second)[flag]', '.root + .next ~ .last',
		'.root:has(> #flag:checked)', '.root:has(+ .next .leaf)', '.root:is(.owner:has(.flag) .tail)',
		':nth-child(2n of .row, [visible]):not(.hidden)', ':host(.state) ::slotted(span.ready)',
		'.root:has(:not(:empty)) .tail', '.root:has(button:disabled)', '.root:has([flag]:focus)',
		'.root > .last'] {
		selector := selector_from_text(text)
		for boundary in [false, true] {
			build_owned_selector_invalidation(mut actual, selector, boundary)
			root := if boundary {
				make_invalidate_whole_subtree_invalidation()
			} else {
				make_invalidate_self_invalidation()
			}
			_ = build_invalidation_sets_for_selector_impl(mut reference, selector, .no, root)
			assert_owned_invalidation_matches_reference(actual, reference)
		}
	}
}

fn test_owned_selector_invalidation_plan_outlives_temporary_selector_storage() {
	mut storage := platform.new_arena('temporary selector input')
	entry := storage.enter()
	selector := selector_from_text('.owned-root:has(> #owned-child:checked) .owned-tail + [owned-flag]'.clone())
	storage.leave(entry)
	mut data := StyleInvalidationData{}
	build_owned_selector_invalidation(mut data, selector, false)
	storage.release()
	assert data.ids_used_in_has_selectors['owned-child']
	assert data.pseudo_classes_used_in_has_selectors[.checked]
	plan := data.plan_for_property(InvalidationProperty.class('owned-tail'))?
	assert plan.sibling_rules.len > 0
	assert plan.sibling_rules[0].match_set.to_string() == '[owned-flag]'
	assert plan.sibling_rules[0].payload.invalidate_self
	assert data.plan_for_property(InvalidationProperty.attribute('owned-flag'))?.invalidate_self
}

fn selector_invalidation_retained_bytes(selector Selector, workspace bool) u64 {
	mut storage := platform.new_arena('selector invalidation budget')
	entry := storage.enter()
	mut data := StyleInvalidationData{}
	if workspace {
		build_owned_selector_invalidation(mut data, selector, false)
	} else {
		_ = build_invalidation_sets_for_selector_impl(mut data, selector, .no, make_invalidate_self_invalidation())
	}
	storage.leave(entry)
	used := storage.usage().used
	storage.release()
	return used
}

fn test_selector_invalidation_workspace_retains_less_than_intermediate_plan_construction() {
	selector := selector_from_text('.owner:is(.one, .two, .three):has(> .child:checked) > .middle:not(.excluded) + [tail]')
	$if prealloc {
		reference := selector_invalidation_retained_bytes(selector, false)
		owned := selector_invalidation_retained_bytes(selector, true)
		assert owned < reference * 8 / 10, 'owned=${owned} reference=${reference}'
	}
}

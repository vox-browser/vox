module css

fn invalidation_registration_callback_oracle(mut data StyleInvalidationData, properties InvalidationSet, plan &InvalidationPlan) {
	properties.for_each_property(fn [mut data, plan] (property InvalidationProperty) bool {
		if !should_register_invalidation_property(property) { return true }
		key := property.key()
		if key !in data.invalidation_plans {
			data.invalidation_plans[key] = InvalidationPlan.create()
			data.invalidation_plan_properties[key] = property
		}
		mut stored := data.invalidation_plans[key] or { return true }
		stored.include_all_from(plan)
		return true
	})
}

fn assert_invalidation_registration_equal(actual &StyleInvalidationData, expected &StyleInvalidationData) {
	assert actual.invalidation_plans.keys() == expected.invalidation_plans.keys()
	assert actual.invalidation_plan_properties == expected.invalidation_plan_properties
	for key, plan in actual.invalidation_plans {
		other := expected.invalidation_plans[key] or { panic('missing property') }
		assert plan.str() == other.str()
	}
}

fn test_invalidation_registration_keeps_flags_keys_and_ordered_plan_merges() {
	mut properties := InvalidationSet{}
	properties.set_needs_invalidate_self()
	properties.set_needs_invalidate_whole_subtree()
	properties.set_needs_invalidate_class('')
	properties.set_needs_invalidate_class('café.#[]')
	properties.set_needs_invalidate_id('café.#[]')
	properties.set_needs_invalidate_attribute('café.#[]')
	properties.set_needs_invalidate_tag_name('café.#[]')
	properties.set_needs_invalidate_pseudo_class(.has)
	properties.set_needs_invalidate_pseudo_class(.hover)
	mut actual := StyleInvalidationData.new()
	mut expected := StyleInvalidationData.new()
	mut filter := InvalidationSet{}
	filter.set_needs_invalidate_class('descendant')
	plan := &InvalidationPlan{
		descendant_rules: [DescendantInvalidationRule{match_set: filter, payload: make_invalidate_self_invalidation()}]
		sibling_rules: [SiblingInvalidationRule{reach: .adjacent, match_any: true, payload: make_invalidate_self_invalidation()}]
	}
	for _ in 0 .. 2 {
		add_invalidation_plan_for_properties(mut actual, properties, plan)
		invalidation_registration_callback_oracle(mut expected, properties, plan)
		assert_invalidation_registration_equal(actual, expected)
	}
	assert actual.invalidation_plans.len == 7
	assert '$' !in actual.invalidation_plans && '*' !in actual.invalidation_plans
	// Identical registrations coalesce into one rule of each kind through the
	// existing append_or_merge helpers.
	for _, retained in actual.invalidation_plans {
		assert retained.descendant_rules.len == 1
		assert retained.sibling_rules.len == 1
		assert !retained.invalidate_whole_subtree
	}
	whole := make_invalidate_whole_subtree_invalidation()
	add_invalidation_plan_for_properties(mut actual, properties, whole)
	invalidation_registration_callback_oracle(mut expected, properties, whole)
	assert_invalidation_registration_equal(actual, expected)
	for _, retained in actual.invalidation_plans {
		assert retained.invalidate_whole_subtree
		assert retained.descendant_rules.len == 0 && retained.sibling_rules.len == 0
	}
	// Flags alone never install dependencies, even for a nonempty payload.
	mut flags := InvalidationSet{}
	flags.set_needs_invalidate_self()
	flags.set_needs_invalidate_whole_subtree()
	mut flags_data := StyleInvalidationData.new()
	add_invalidation_plan_for_properties(mut flags_data, flags, plan)
	assert flags_data.invalidation_plans.len == 0
	assert flags_data.invalidation_plan_properties.len == 0
	assert plan.descendant_rules.len == 1 && plan.sibling_rules.len == 1
}

fn test_invalidation_registration_retains_growing_and_overlapping_property_owners() {
	mut actual := StyleInvalidationData.new()
	mut expected := StyleInvalidationData.new()
	for batch in 0 .. 4 {
		mut properties := InvalidationSet{}
		for index in 0 .. 96 {
			properties.set_needs_invalidate_class('key-${index + batch * 48}-é')
			properties.set_needs_invalidate_id('key-${index + batch * 48}-é')
		}
		before := properties.to_string()
		plan := make_invalidate_self_invalidation()
		add_invalidation_plan_for_properties(mut actual, properties, plan)
		invalidation_registration_callback_oracle(mut expected, properties, plan)
		assert properties.to_string() == before
		assert_invalidation_registration_equal(actual, expected)
	}
	gc_collect()
	assert actual.invalidation_plans.len == 480
	assert actual.invalidation_plan_properties.len == 480
	assert_invalidation_registration_equal(actual, expected)
	for key, plan in actual.invalidation_plans {
		property := actual.invalidation_plan_properties[key] or { panic('missing owner') }
		assert property.key() == key
		assert plan.invalidate_self && !plan.invalidate_whole_subtree
	}
}

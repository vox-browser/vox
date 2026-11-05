module css

fn subset_union_match_set(names []string, payload CSSPseudoClass) InvalidationSet {
	mut set := InvalidationSet{}
	for name in names {
		set.add_property(InvalidationProperty{
			type_:        .class
			value:        name
			pseudo_class: payload
		})
	}
	return set
}

fn test_descendant_subset_union_retains_storage_order_and_first_payloads() {
	mut existing := subset_union_match_set(['inline', 'first', 'second', 'third'], .hover)
	existing.set_needs_invalidate_self()
	existing.set_needs_invalidate_whole_subtree()
	// The incoming inline key lives in the existing overflow map. Its second
	// key also arrives in a different order and with a different stored value.
	subset := subset_union_match_set(['third', 'first'], .checked)
	mut rules := [DescendantInvalidationRule{
		match_set: existing
		payload:   &InvalidationPlan{ invalidate_self: true }
	}]
	before_storage := rules.data
	before_properties := rules[0].match_set.properties()
	for _ in 0 .. 16 {
		append_or_merge_descendant_invalidation_rule(mut rules, DescendantInvalidationRule{
			match_set: subset
			payload:   &InvalidationPlan{ invalidate_self: true }
		})
		append_or_merge_descendant_invalidation_rule(mut rules, DescendantInvalidationRule{
			payload: &InvalidationPlan{ invalidate_self: true }
		})
	}
	assert rules.len == 1
	assert rules.data == before_storage
	assert rules[0].match_set.properties() == before_properties
	assert rules[0].match_set.needs_invalidate_self()
	assert rules[0].match_set.needs_invalidate_whole_subtree()
	assert rules[0].match_set.property_count() == 4
	assert rules[0].match_set.first_property_key_ == '.inline'
	assert rules[0].match_set.properties()[1].pseudo_class == .hover
	assert subset.properties()[0].pseudo_class == .checked
}

fn test_sibling_subset_union_retains_storage_with_an_existing_flag_superset() {
	mut existing := subset_union_match_set(['inline', 'first', 'second'], .hover)
	existing.set_needs_invalidate_self()
	existing.set_needs_invalidate_whole_subtree()
	mut subset := subset_union_match_set(['second', 'inline'], .checked)
	subset.set_needs_invalidate_self()
	mut rules := [SiblingInvalidationRule{
		reach:     .subsequent
		match_set: existing
		payload:   &InvalidationPlan{ invalidate_self: true }
	}]
	before_storage := rules.data
	before_properties := rules[0].match_set.properties()
	for _ in 0 .. 16 {
		append_or_merge_sibling_invalidation_rule(mut rules, SiblingInvalidationRule{
			reach:     .subsequent
			match_set: subset
			payload:   &InvalidationPlan{ invalidate_self: true }
		})
	}
	assert rules.len == 1
	assert rules.data == before_storage
	assert rules[0].match_set.properties() == before_properties
	assert rules[0].match_set.needs_invalidate_self()
	assert rules[0].match_set.needs_invalidate_whole_subtree()
	assert rules[0].match_set.property_count() == 3
	assert rules[0].match_set.first_property_.pseudo_class == .hover
	assert subset.first_property_.pseudo_class == .checked
}

fn test_subset_union_new_flags_require_merging_even_without_new_keys() {
	payload := &InvalidationPlan{ invalidate_self: true }
	existing := subset_union_match_set(['inline', 'first', 'second'], .hover)
	source := &InvalidationPlan{
		descendant_rules: [DescendantInvalidationRule{ match_set: existing, payload: payload }]
		sibling_rules:    [SiblingInvalidationRule{
			reach:     .adjacent
			match_set: existing
			payload:   payload
		}]
	}
	mut result := InvalidationPlan.create()
	result.include_all_from(source)
	snapshot := *result
	mut subset := subset_union_match_set(['second'], .checked)
	subset.set_needs_invalidate_self()
	result.include_all_from(&InvalidationPlan{
		descendant_rules: [DescendantInvalidationRule{ match_set: subset, payload: payload }]
		sibling_rules:    [SiblingInvalidationRule{
			reach:     .adjacent
			match_set: subset
			payload:   payload
		}]
	})
	assert result.descendant_rules[0].match_set.needs_invalidate_self()
	assert result.sibling_rules[0].match_set.needs_invalidate_self()
	assert !result.descendant_rules[0].match_set.needs_invalidate_whole_subtree()
	assert !result.sibling_rules[0].match_set.needs_invalidate_whole_subtree()
	subset.set_needs_invalidate_whole_subtree()
	result.include_all_from(&InvalidationPlan{
		descendant_rules: [DescendantInvalidationRule{ match_set: subset, payload: payload }]
		sibling_rules:    [SiblingInvalidationRule{
			reach:     .adjacent
			match_set: subset
			payload:   payload
		}]
	})
	assert result.descendant_rules[0].match_set.needs_invalidate_whole_subtree()
	assert result.sibling_rules[0].match_set.needs_invalidate_whole_subtree()
	assert result.descendant_rules[0].match_set.property_count() == 3
	assert result.sibling_rules[0].match_set.property_count() == 3
	assert !source.descendant_rules[0].match_set.needs_invalidate_self()
	assert !source.sibling_rules[0].match_set.needs_invalidate_whole_subtree()
	assert !snapshot.descendant_rules[0].match_set.needs_invalidate_whole_subtree()
	assert !snapshot.sibling_rules[0].match_set.needs_invalidate_self()
}

fn test_subset_union_keeps_payload_reach_any_and_later_growth_boundaries() {
	payload := &InvalidationPlan{ invalidate_self: true }
	existing := subset_union_match_set(['inline', 'first', 'second'], .hover)
	subset := subset_union_match_set(['second'], .checked)
	source := &InvalidationPlan{
		descendant_rules: [DescendantInvalidationRule{ match_set: existing, payload: payload }]
		sibling_rules:    [SiblingInvalidationRule{
			reach:     .adjacent
			match_set: existing
			payload:   payload
		}]
	}
	mut result := InvalidationPlan.create()
	result.include_all_from(source)
	result.include_all_from(&InvalidationPlan{
		descendant_rules: [DescendantInvalidationRule{ match_set: subset, payload: payload }]
		sibling_rules:    [SiblingInvalidationRule{
			reach:     .adjacent
			match_set: subset
			payload:   payload
		}]
	})
	snapshot := *result
	growing := subset_union_match_set(['second', 'new'], .checked)
	result.include_all_from(&InvalidationPlan{
		descendant_rules: [DescendantInvalidationRule{ match_set: growing, payload: payload }]
		sibling_rules:    [SiblingInvalidationRule{
			reach:     .adjacent
			match_set: growing
			payload:   payload
		}]
	})
	gc_collect()
	assert result.descendant_rules[0].match_set.property_count() == 4
	assert result.sibling_rules[0].match_set.property_count() == 4
	assert result.descendant_rules[0].match_set.properties()[2].pseudo_class == .hover
	assert result.sibling_rules[0].match_set.properties()[3].name() == 'new'
	assert source.descendant_rules[0].match_set.property_count() == 3
	assert source.sibling_rules[0].match_set.property_count() == 3
	assert snapshot.descendant_rules[0].match_set.property_count() == 3
	assert snapshot.sibling_rules[0].match_set.property_count() == 3
	assert !invalidation_set_has_stored_key(&source.descendant_rules[0].match_set, '.new')
	assert !invalidation_set_has_stored_key(&snapshot.sibling_rules[0].match_set, '.new')
	assert growing.property_count() == 2
	// A covered match set must not hide a distinct action or sibling reach.
	other_payload := &InvalidationPlan{ invalidate_whole_subtree: true }
	result.include_all_from(&InvalidationPlan{
		descendant_rules: [
			DescendantInvalidationRule{ match_set: subset, payload: other_payload },
			DescendantInvalidationRule{ match_set: subset, match_any: true, payload: payload },
		]
		sibling_rules:    [
			SiblingInvalidationRule{
				reach:     .subsequent
				match_set: subset
				payload:   payload
			},
			SiblingInvalidationRule{
				reach:     .adjacent
				match_set: subset
				payload:   other_payload
			},
			SiblingInvalidationRule{
				reach:     .adjacent
				match_set: subset
				match_any: true
				payload:   payload
			},
		]
	})
	assert result.descendant_rules.len == 3
	assert result.sibling_rules.len == 4
	assert result.descendant_rules[1].payload.invalidate_whole_subtree
	assert result.descendant_rules[2].match_any
	assert result.sibling_rules[1].reach == .subsequent
	assert result.sibling_rules[2].payload.invalidate_whole_subtree
	assert result.sibling_rules[3].match_any
}

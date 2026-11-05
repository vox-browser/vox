module css

// StyleInvalidationData.cpp: rule payloads compare structurally, with rule
// lists and match sets independent of insertion order.
fn invalidation_set_has_stored_key(set &InvalidationSet, key string) bool {
	if set.has_first_property_ && set.first_property_key_ == key { return true }
	if properties := set.additional_properties_ { return key in properties }
	return false
}

fn invalidation_match_sets_equal(a &InvalidationSet, b &InvalidationSet) bool {
	if a.needs_invalidate_self_ != b.needs_invalidate_self_
		|| a.needs_invalidate_whole_subtree_ != b.needs_invalidate_whole_subtree_
		|| a.property_count() != b.property_count() {
		return false
	}
	if a.has_first_property_ && !invalidation_set_has_stored_key(b, a.first_property_key_) {
		return false
	}
	if properties := a.additional_properties_ {
		for key, _ in properties {
			if !invalidation_set_has_stored_key(b, key) { return false }
		}
	}
	return true
}

fn descendant_invalidation_rules_equal(a &DescendantInvalidationRule, b &DescendantInvalidationRule) bool {
	return a.match_any == b.match_any && invalidation_match_sets_equal(&a.match_set, &b.match_set)
		&& invalidation_plans_equal(a.payload, b.payload)
}

fn sibling_invalidation_rules_equal(a &SiblingInvalidationRule, b &SiblingInvalidationRule) bool {
	return a.reach == b.reach && a.match_any == b.match_any
		&& invalidation_match_sets_equal(&a.match_set, &b.match_set)
		&& invalidation_plans_equal(a.payload, b.payload)
}

fn invalidation_plans_equal(a &InvalidationPlan, b &InvalidationPlan) bool {
	if voidptr(a) == voidptr(b) { return true }
	if a == unsafe { nil } || b == unsafe { nil } { return false }
	if a.invalidate_self != b.invalidate_self
		|| a.invalidate_whole_subtree != b.invalidate_whole_subtree
		|| a.descendant_rules.len != b.descendant_rules.len
		|| a.sibling_rules.len != b.sibling_rules.len {
		return false
	}
	mut descendants_ordered := true
	for index in 0 .. a.descendant_rules.len {
		if !descendant_invalidation_rules_equal(&a.descendant_rules[index],
			&b.descendant_rules[index]) {
			descendants_ordered = false
			break
		}
	}
	if !descendants_ordered {
		mut matched := []bool{len: b.descendant_rules.len}
		for rule in a.descendant_rules {
			mut found := false
			for index in 0 .. b.descendant_rules.len {
				if !matched[index]
					&& descendant_invalidation_rules_equal(&rule, &b.descendant_rules[index]) {
					matched[index] = true
					found = true
					break
				}
			}
			if !found { return false }
		}
	}
	mut siblings_ordered := true
	for index in 0 .. a.sibling_rules.len {
		if !sibling_invalidation_rules_equal(&a.sibling_rules[index], &b.sibling_rules[index]) {
			siblings_ordered = false
			break
		}
	}
	if !siblings_ordered {
		mut matched := []bool{len: b.sibling_rules.len}
		for rule in a.sibling_rules {
			mut found := false
			for index in 0 .. b.sibling_rules.len {
				if !matched[index]
					&& sibling_invalidation_rules_equal(&rule, &b.sibling_rules[index]) {
					matched[index] = true
					found = true
					break
				}
			}
			if !found { return false }
		}
	}
	return true
}

fn union_invalidation_match_sets(a InvalidationSet, b InvalidationSet) InvalidationSet {
	// Existing rules may share the stylesheet's map header. Give a merged set
	// its own storage so adding a property cannot mutate either input plan.
	// Clone the existing table once instead of rebuilding it property by
	// property on every merge of another rule into a growing match set.
	mut result := a
	if properties := a.additional_properties_ {
		result.additional_properties_ = properties.clone()
	}
	result.include_all_from(b)
	return result
}

fn append_or_merge_descendant_invalidation_rule(mut rules []DescendantInvalidationRule, rule DescendantInvalidationRule) {
	for index in 0 .. rules.len {
		if rules[index].match_any != rule.match_any || !invalidation_plans_equal(rules[index].payload, rule.payload) { continue
		 }
		if !rule.match_any {
			// A covered subset contributes no keys or flags, so neither the
			// rule vector nor the existing property map needs a new owner.
			if invalidation_match_set_covers(&rules[index].match_set, &rule.match_set) { return }
			// A value-copy of a V plan can share the old array header.
			// Replace the modified vector before changing an existing entry.
			rules = rules.clone()
			rules[index].match_set = union_invalidation_match_sets(rules[index].match_set,
				rule.match_set)
		}
		return
	}
	rules << rule
}

fn append_or_merge_sibling_invalidation_rule(mut rules []SiblingInvalidationRule, rule SiblingInvalidationRule) {
	for index in 0 .. rules.len {
		if rules[index].reach != rule.reach || rules[index].match_any != rule.match_any
			|| !invalidation_plans_equal(rules[index].payload, rule.payload) {
			continue
		}
		if !rule.match_any {
			if invalidation_match_set_covers(&rules[index].match_set, &rule.match_set) { return }
			rules = rules.clone()
			rules[index].match_set = union_invalidation_match_sets(rules[index].match_set,
				rule.match_set)
		}
		return
	}
	rules << rule
}

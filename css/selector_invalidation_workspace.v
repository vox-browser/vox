module css

import platform

// Selector projections, unions and partially built plans are parser-like
// work. Publish only the final dependency graph into the calling style owner.
fn build_owned_selector_invalidation(mut destination StyleInvalidationData, selector Selector,
	boundary bool) {
	mut scratch := platform.begin_thread_scratch('selector invalidation')
	mut temporary := StyleInvalidationData{}
	root := if boundary {
		make_invalidate_whole_subtree_invalidation()
	} else {
		make_invalidate_self_invalidation()
	}
	_ = build_invalidation_sets_for_selector_impl(mut temporary, selector, .no, root)
	scratch.leave()
	mut copy := InvalidationGraphCopy{}
	for key, plan in temporary.invalidation_plans {
		owned := copy.plan(plan)
		if mut existing := destination.invalidation_plans[key] {
			existing.include_all_from(owned)
		} else {
			owned_key := key.clone()
			destination.invalidation_plans[owned_key] = owned
			destination.invalidation_plan_properties[owned_key] = own_invalidation_property(temporary.invalidation_plan_properties[key])
		}
	}
	for key, value in temporary.ids_used_in_has_selectors {
		if key !in destination.ids_used_in_has_selectors {
			destination.ids_used_in_has_selectors[key.clone()] = value
		}
	}
	for key, value in temporary.class_names_used_in_has_selectors {
		if key !in destination.class_names_used_in_has_selectors {
			destination.class_names_used_in_has_selectors[key.clone()] = value
		}
	}
	for key, value in temporary.attribute_names_used_in_has_selectors {
		if key !in destination.attribute_names_used_in_has_selectors {
			destination.attribute_names_used_in_has_selectors[key.clone()] = value
		}
	}
	for key, value in temporary.tag_names_used_in_has_selectors {
		if key !in destination.tag_names_used_in_has_selectors {
			destination.tag_names_used_in_has_selectors[key.clone()] = value
		}
	}
	for key, value in temporary.pseudo_classes_used_in_has_selectors {
		destination.pseudo_classes_used_in_has_selectors[key] = value
	}
	destination.has_selectors_sensitive_to_featureless_subtree_changes = destination.has_selectors_sensitive_to_featureless_subtree_changes
		|| temporary.has_selectors_sensitive_to_featureless_subtree_changes
	scratch.finish()
}

struct InvalidationGraphCopy {
mut:
	plans map[voidptr]&InvalidationPlan
}

fn own_invalidation_property(property InvalidationProperty) InvalidationProperty {
	return InvalidationProperty{ ...property, value: property.value.clone() }
}

fn own_invalidation_match_set(source &InvalidationSet) InvalidationSet {
	mut result := InvalidationSet{
		needs_invalidate_self_:          source.needs_invalidate_self_
		needs_invalidate_whole_subtree_: source.needs_invalidate_whole_subtree_
	}
	if source.has_first_property_ {
		result.add_stored_property(source.first_property_key_.clone(), own_invalidation_property(source.first_property_))
	}
	if properties := source.additional_properties_ {
		for key, property in properties {
			result.add_stored_property(key.clone(), own_invalidation_property(property))
		}
	}
	return result
}

fn (mut copy InvalidationGraphCopy) plan(source &InvalidationPlan) &InvalidationPlan {
	if source == unsafe { nil } { return unsafe { nil } }
	if existing := copy.plans[voidptr(source)] { return existing }
	mut result := &InvalidationPlan{
		invalidate_self:          source.invalidate_self
		invalidate_whole_subtree: source.invalidate_whole_subtree
		descendant_rules:         []DescendantInvalidationRule{cap: source.descendant_rules.len}
		sibling_rules:            []SiblingInvalidationRule{cap: source.sibling_rules.len}
	}
	copy.plans[voidptr(source)] = result
	for rule in source.descendant_rules {
		result.descendant_rules << DescendantInvalidationRule{
			match_set: own_invalidation_match_set(&rule.match_set)
			match_any: rule.match_any
			payload:   copy.plan(rule.payload)
		}
	}
	for rule in source.sibling_rules {
		result.sibling_rules << SiblingInvalidationRule{
			reach:     rule.reach
			match_set: own_invalidation_match_set(&rule.match_set)
			match_any: rule.match_any
			payload:   copy.plan(rule.payload)
		}
	}
	return result
}

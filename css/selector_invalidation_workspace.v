module css

import platform

struct InvalidationPublication {
	key string
	plan &InvalidationPlan
}

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
	mut copy := InvalidationGraphCopy{}
	mut publications := []InvalidationPublication{}
	for key, plan in temporary.invalidation_plans {
		if existing := destination.invalidation_plans[key] {
			if invalidation_plan_covers(existing, plan) {
				continue
			}
			publications << InvalidationPublication{key, plan}
			// These unions only change flags and discard rules; they retain no
			// input payload. There is no graph to copy into the destination.
			if existing.invalidate_whole_subtree || plan.invalidate_whole_subtree { continue }
		} else {
			publications << InvalidationPublication{key, plan}
		}
		copy.prepare(plan)
	}
	// V clones string map keys during iteration. Enumerate while the
	// workspace is entered, including keys which need no publication.
	id_features := temporary.ids_used_in_has_selectors.keys()
	class_features := temporary.class_names_used_in_has_selectors.keys()
	attribute_features := temporary.attribute_names_used_in_has_selectors.keys()
	tag_features := temporary.tag_names_used_in_has_selectors.keys()
	scratch.leave()
	for publication in publications {
		key := publication.key
		plan := publication.plan
		if mut existing := destination.invalidation_plans[key] {
			if existing.invalidate_whole_subtree || plan.invalidate_whole_subtree {
				existing.include_all_from(plan)
			} else {
				existing.include_all_from(copy.plan(plan))
			}
		} else {
			owned_key := key.clone()
			destination.invalidation_plans[owned_key] = copy.plan(plan)
			destination.invalidation_plan_properties[owned_key] = own_invalidation_property(temporary.invalidation_plan_properties[key])
		}
	}
	for key in id_features {
		if key !in destination.ids_used_in_has_selectors {
			destination.ids_used_in_has_selectors[key.clone()] = temporary.ids_used_in_has_selectors[key]
		}
	}
	for key in class_features {
		if key !in destination.class_names_used_in_has_selectors {
			destination.class_names_used_in_has_selectors[key.clone()] = temporary.class_names_used_in_has_selectors[key]
		}
	}
	for key in attribute_features {
		if key !in destination.attribute_names_used_in_has_selectors {
			destination.attribute_names_used_in_has_selectors[key.clone()] = temporary.attribute_names_used_in_has_selectors[key]
		}
	}
	for key in tag_features {
		if key !in destination.tag_names_used_in_has_selectors {
			destination.tag_names_used_in_has_selectors[key.clone()] = temporary.tag_names_used_in_has_selectors[key]
		}
	}
	for key, value in temporary.pseudo_classes_used_in_has_selectors {
		if key !in destination.pseudo_classes_used_in_has_selectors {
			destination.pseudo_classes_used_in_has_selectors[key] = value
		}
	}
	destination.has_selectors_sensitive_to_featureless_subtree_changes = destination.has_selectors_sensitive_to_featureless_subtree_changes
		|| temporary.has_selectors_sensitive_to_featureless_subtree_changes
	scratch.finish()
}

// Check a union before allocating its owned graph. In particular, adding
// another selector often repeats an existing dependency or a subset of its
// match set. Equality alone misses those already-covered subsets.
fn invalidation_match_set_covers(destination &InvalidationSet, source &InvalidationSet) bool {
	if (source.needs_invalidate_self_ && !destination.needs_invalidate_self_)
		|| (source.needs_invalidate_whole_subtree_ && !destination.needs_invalidate_whole_subtree_) {
		return false
	}
	if source.has_first_property_ && !invalidation_set_has_stored_key(destination, source.first_property_key_) { return false }
	if properties := source.additional_properties_ {
		for key, _ in properties {
			if !invalidation_set_has_stored_key(destination, key) { return false }
		}
	}
	return true
}

fn invalidation_plan_covers(destination &InvalidationPlan, source &InvalidationPlan) bool {
	if source.invalidate_self && !destination.invalidate_self { return false }
	if destination.invalidate_whole_subtree { return true }
	if source.invalidate_whole_subtree { return false }
	for rule in source.descendant_rules {
		mut found := false
		for existing in destination.descendant_rules {
			if rule.match_any == existing.match_any
				&& invalidation_plans_equal(rule.payload, existing.payload)
				&& (rule.match_any || invalidation_match_set_covers(&existing.match_set, &rule.match_set)) {
				found = true
				break
			}
		}
		if !found { return false }
	}
	for rule in source.sibling_rules {
		mut found := false
		for existing in destination.sibling_rules {
			if rule.reach == existing.reach && rule.match_any == existing.match_any
				&& invalidation_plans_equal(rule.payload, existing.payload)
				&& (rule.match_any || invalidation_match_set_covers(&existing.match_set, &rule.match_set)) {
				found = true
				break
			}
		}
		if !found { return false }
	}
	return true
}

struct InvalidationGraphCopy {
mut:
	plans map[voidptr]&InvalidationCopyEntry
}

struct InvalidationCopyEntry {
mut:
	plan &InvalidationPlan = unsafe { nil }
}

// Reserve every memo entry while the construction workspace is entered.
// Copying below only replaces existing values, so no memo allocation can
// escape into the destination's longer lifetime. Register before descending
// to preserve both shared subgraphs and cycles.
fn (mut copy InvalidationGraphCopy) prepare(source &InvalidationPlan) {
	if source == unsafe { nil } || voidptr(source) in copy.plans { return }
	copy.plans[voidptr(source)] = &InvalidationCopyEntry{}
	for rule in source.descendant_rules { copy.prepare(rule.payload) }
	for rule in source.sibling_rules { copy.prepare(rule.payload) }
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
	mut entry := copy.plans[voidptr(source)] or { panic('unprepared invalidation graph') }
	if entry.plan != unsafe { nil } { return entry.plan }
	mut result := &InvalidationPlan{
		invalidate_self:          source.invalidate_self
		invalidate_whole_subtree: source.invalidate_whole_subtree
		descendant_rules:         []DescendantInvalidationRule{cap: source.descendant_rules.len}
		sibling_rules:            []SiblingInvalidationRule{cap: source.sibling_rules.len}
	}
	// Updating the entry itself cannot resize the memo's V map on a load-factor
	// boundary, unlike a map assignment even when its key already exists.
	entry.plan = result
	for index in 0 .. source.descendant_rules.len {
		rule := unsafe { &source.descendant_rules[index] }
		result.descendant_rules << DescendantInvalidationRule{
			match_set: own_invalidation_match_set(&rule.match_set)
			match_any: rule.match_any
			payload:   copy.plan(rule.payload)
		}
	}
	for index in 0 .. source.sibling_rules.len {
		rule := unsafe { &source.sibling_rules[index] }
		result.sibling_rules << SiblingInvalidationRule{
			reach:     rule.reach
			match_set: own_invalidation_match_set(&rule.match_set)
			match_any: rule.match_any
			payload:   copy.plan(rule.payload)
		}
	}
	return result
}

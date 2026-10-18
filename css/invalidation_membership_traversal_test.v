module css

// Preserve the former projection traversal as an oracle, including its local
// pseudo-class enum mapping and the slotted-only pseudo-element boundary.
fn invalidation_membership_projection_oracle(selector Selector, wanted CSSPseudoClass) bool {
	for group in selector_groups_for_invalidation(selector) {
		for simple in group.simple_selectors {
			if simple.type_ == .pseudo_class && simple.pseudo_class == wanted { return true }
			for nested in simple.nested_selectors {
				if invalidation_membership_projection_oracle(nested, wanted) { return true }
			}
		}
	}
	return false
}

fn invalidation_membership_selector(simple SimpleSelector) Selector {
	return Selector{data_: &SelectorData{compound_selectors: [CompoundSelector{simple_selectors: [simple]}]}}
}

fn test_invalidation_membership_preserves_every_local_enum_mapping() {
	parser_classes := [PseudoClass.invalid, .link, .any_link, .local_link, .visited, .active, .hover, .focus, .focus_visible, .focus_within, .fullscreen, .first_child, .last_child, .only_child, .empty, .root, .host, .scope, .first_of_type, .last_of_type, .only_of_type, .lang, .disabled, .enabled, .checked, .unchecked, .indeterminate, .high_value, .low_value, .optimal_value, .suboptimal_value, .even_less_good_value, .defined, .has, .is_, .where, .not_, .nth_child, .nth_last_child, .nth_of_type, .nth_last_of_type, .playing, .paused, .seeking, .muted, .volume_locked, .buffering, .stalled, .target, .dir, .read_only, .read_write, .placeholder_shown, .open, .closed, .modal, .popover_open, .valid, .invalid_state, .user_valid, .user_invalid, .required, .optional, .default_, .autofill, .state, .heading]
	wanted_classes := [CSSPseudoClass.enabled, .disabled, .defined, .placeholder_shown, .checked, .dir, .empty, .lang, .required, .optional, .read_only, .read_write, .link, .any_link, .local_link, .default_, .has, .not, .is_, .where, .nth_child, .nth_last_child, .nth_of_type, .nth_last_of_type, .hover, .focus, .focus_visible, .focus_within, .active, .target, .host, .root, .first_child, .last_child, .only_child, .paused, .playing, .muted, .seeking, .buffering, .stalled, .other]
	for parser_class in parser_classes {
		selector := invalidation_membership_selector(SimpleSelector.with_pseudo_class(.pseudo_class, PseudoClassSelector{type_: parser_class}))
		for wanted in wanted_classes {
			assert selector_contains_pseudo_class(selector, wanted) == invalidation_membership_projection_oracle(selector, wanted)
			assert selector_contains_pseudo_class(selector, wanted) == (css_pseudo_class_from_selector_pseudo_class(parser_class) == wanted)
		}
	}
	assert selector_contains_pseudo_class(selector_from_text(':not(.plain)'), .not)
	assert selector_contains_pseudo_class(selector_from_text(':first-of-type'), .other)
	assert !selector_contains_pseudo_class(selector_from_text('.not :hover'), .not)
}

fn test_invalidation_membership_reads_nested_lists_and_only_slotted_arguments() {
	leaf := selector_from_text('.flag:has(> .child):focus')
	nested := invalidation_membership_selector(SimpleSelector.with_pseudo_class(.pseudo_class, PseudoClassSelector{type_: .is_, argument_selector_list: SelectorList{selectors: [selector_from_text('.plain'), leaf]}}))
	slotted := invalidation_membership_selector(SimpleSelector.with_pseudo_element(.pseudo_element, PseudoElementSelector{type_: .slotted, compound_selector: nested}))
	ignored := invalidation_membership_selector(SimpleSelector.with_pseudo_element(.pseudo_element, PseudoElementSelector{type_: .before, compound_selector: nested}))
	for selector in [leaf, nested, slotted, ignored, Selector{}, Selector{data_: &SelectorData{compound_selectors: [CompoundSelector{}]}}] {
		for wanted in [CSSPseudoClass.has, .focus, .hover, .is_, .other] {
			assert selector_contains_pseudo_class(selector, wanted) == invalidation_membership_projection_oracle(selector, wanted)
		}
	}
	gc_collect()
	assert selector_contains_pseudo_class(slotted, .has)
	assert selector_contains_pseudo_class(slotted, .focus)
	assert !selector_contains_pseudo_class(ignored, .has)
	assert !selector_contains_pseudo_class(ignored, .focus)
}

fn test_invalidation_membership_observes_live_typed_edits_without_mutating_source() {
	selector := selector_from_text('.original:hover')
	assert selector.contains_pseudo_class(.hover)
	mut data := selector.data_
	data.compound_selectors = selector_from_text(':focus:has(.flag)').compound_selectors()
	// Selector metadata remains the original snapshot. This predicate must read
	// the same live typed data as the old projection path, without trusting it.
	assert selector.contains_pseudo_class(.hover)
	assert !selector_contains_pseudo_class(selector, .hover)
	assert selector_contains_pseudo_class(selector, .focus)
	assert selector_contains_pseudo_class(selector, .has)
	before := data.compound_selectors[0].simple_selectors.clone()
	gc_collect()
	for _ in 0 .. 8 { assert selector_contains_pseudo_class(selector, .has) }
	assert data.compound_selectors[0].simple_selectors == before
}

fn test_invalidation_membership_keeps_nested_has_scope_leakage_plan() {
	mut data := StyleInvalidationData.new()
	data.build_invalidation_sets_for_selector(selector_from_text('.root:is(.owner:has(.flag) .tail)'))
	plan := data.plan_for_property(InvalidationProperty.pseudo_class(.has)) or { panic('missing has plan') }
	assert plan.invalidate_whole_subtree
	assert data.class_names_used_in_has_selectors['flag']
	assert data.plan_for_property(InvalidationProperty.class('root')) != none
}

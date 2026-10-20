// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of CSS/StyleSheetInvalidation.{h,cpp}.
module css

import dom

struct StyleSheetPseudoElementInvalidationRule {
	anchor_set           InvalidationSet
	anchor_selector      ?Selector
	style_sheet_for_rule ?&CSSStyleSheet
}

struct StyleSheetTrailingUniversalInvalidationRule {
	anchor_set           InvalidationSet
	anchor_selector      ?Selector
	combinator           Combinator
	style_sheet_for_rule ?&CSSStyleSheet
}

struct StyleSheetInvalidationSet {
mut:
	invalidation_set                        InvalidationSet
	may_match_shadow_host                   bool
	may_match_light_dom_under_shadow_host   bool
	may_match_light_dom_outside_shadow_host bool
	pseudo_element_rules                    []StyleSheetPseudoElementInvalidationRule
	trailing_universal_rules                []StyleSheetTrailingUniversalInvalidationRule
}

struct StyleSheetAnchorInvalidationRule {
	anchor_set           InvalidationSet
	anchor_selector      ?Selector
	style_sheet_for_rule ?&CSSStyleSheet
}

struct ShadowRootStylesheetEffects {
mut:
	may_match_shadow_host                   bool
	may_match_light_dom_under_shadow_host   bool
	may_match_light_dom_outside_shadow_host bool
	may_affect_assigned_nodes_via_slots     bool
}

fn (effects ShadowRootStylesheetEffects) all_set() bool {
	return effects.may_match_shadow_host && effects.may_match_light_dom_under_shadow_host
		&& effects.may_match_light_dom_outside_shadow_host
		&& effects.may_affect_assigned_nodes_via_slots
}

fn selector_may_match_light_dom_under_shadow_host(selector Selector) bool {
	if selector.is_slotted() {
		return true
	}
	if !selector.contains_pseudo_class(.host) {
		return false
	}
	return selector.compound_selectors().len > 1
}

pub fn selector_text_may_match_light_dom_under_shadow_host(selector_text string) bool {
	selectors := parse_selector_with_parser(selector_text, map[string]bool{}) or { return false }
	if selectors.selectors.len != 1 {
		return false
	}
	return selector_may_match_light_dom_under_shadow_host(selectors.selectors[0])
}

fn pseudo_class_has_positive_selector_list_arguments(pseudo_class PseudoClass) bool {
	return pseudo_class in [.is_, .where]
}

fn simple_selector_may_match_shadow_host(simple_selector SimpleSelector) bool {
	if simple_selector.type_ != .pseudo_class {
		return false
	}
	pseudo_class := simple_selector.pseudo_class()
	if pseudo_class.type_ == .host {
		return true
	}
	if !pseudo_class_has_positive_selector_list_arguments(pseudo_class.type_) {
		return false
	}
	for selector in pseudo_class.argument_selector_list.selectors {
		if selector_may_match_shadow_host(selector) {
			return true
		}
	}
	return false
}

fn selector_may_match_shadow_host(selector Selector) bool {
	for compound_selector in selector.compound_selectors() {
		for simple_selector in compound_selector.simple_selectors {
			if simple_selector_may_match_shadow_host(simple_selector) {
				return true
			}
		}
	}
	return false
}

fn compound_selector_may_match_shadow_host(compound_selector CompoundSelector) bool {
	for simple_selector in compound_selector.simple_selectors {
		if simple_selector_may_match_shadow_host(simple_selector) {
			return true
		}
	}
	return false
}

fn simple_selector_may_match_light_dom_outside_shadow_host(simple_selector SimpleSelector) bool {
	if simple_selector.type_ != .pseudo_class {
		return false
	}
	pseudo_class := simple_selector.pseudo_class()
	if !pseudo_class_has_positive_selector_list_arguments(pseudo_class.type_) {
		return false
	}
	for selector in pseudo_class.argument_selector_list.selectors {
		if selector_may_match_light_dom_outside_shadow_host(selector) {
			return true
		}
	}
	return false
}

fn compound_selector_may_match_light_dom_outside_shadow_host(compound_selector CompoundSelector) bool {
	for simple_selector in compound_selector.simple_selectors {
		if simple_selector_may_match_light_dom_outside_shadow_host(simple_selector) {
			return true
		}
	}
	return false
}

fn selector_may_match_light_dom_outside_shadow_host(selector Selector) bool {
	compound_selectors := selector.compound_selectors()
	for i, compound_selector in compound_selectors {
		if compound_selector_may_match_light_dom_outside_shadow_host(compound_selector) {
			return true
		}
		if !compound_selector_may_match_shadow_host(compound_selector) {
			continue
		}
		for j := i + 1; j < compound_selectors.len; j++ {
			if compound_selectors[j].combinator in [.next_sibling, .subsequent_sibling] {
				return true
			}
		}
	}
	return false
}

pub fn selector_text_may_match_light_dom_outside_shadow_host(selector_text string) bool {
	selectors := parse_selector_with_parser(selector_text, map[string]bool{}) or { return false }
	if selectors.selectors.len != 1 {
		return false
	}
	return selector_may_match_light_dom_outside_shadow_host(selectors.selectors[0])
}

fn style_sheet_compound_is_universal_only(compound CompoundSelector) bool {
	if compound.simple_selectors.len == 0 {
		return false
	}
	return compound.simple_selectors.all(it.type_ == .universal)
}

fn style_sheet_compound_is_pseudo_element_only(compound CompoundSelector) bool {
	if compound.simple_selectors.len == 0 {
		return false
	}
	return compound.simple_selectors.all(it.type_ == .pseudo_element)
}

// :has() in the rightmost set filters by an element's previously recorded affected-by-:has() flags. Those flags
// are not set for a brand-new rule, so :has() alone cannot safely narrow stylesheet invalidation.
fn rightmost_set_has_targetable_features(rightmost_set InvalidationSet) bool {
	for property in rightmost_set.properties() {
		if property.type_ == .pseudo_class && property.pseudo_class == .has {
			continue
		}
		return true
	}
	return false
}

fn try_build_style_sheet_anchor_for_leading_compounds(compounds []CompoundSelector, mut throwaway_data StyleInvalidationData, style_sheet_for_rule ?&CSSStyleSheet) ?StyleSheetAnchorInvalidationRule {
	if compounds.len < 2 {
		return none
	}
	anchor_compounds := compounds[..compounds.len - 1].clone()
	rightmost_anchor := anchor_compounds[anchor_compounds.len - 1]
	mut anchor_set := InvalidationSet{}
	for simple_index in 0 .. rightmost_anchor.simple_selectors.len {
		simple := unsafe { &rightmost_anchor.simple_selectors[simple_index] }
		build_invalidation_sets_for_simple_selector(simple_selector_for_invalidation(simple), mut anchor_set, .no, mut throwaway_data, .no)
	}
	if !anchor_set.has_properties() {
		return none
	}
	anchor_selector := if anchor_compounds.len > 1 {
		?Selector(selector_from_compound_selectors(anchor_compounds))
	} else {
		?Selector(none)
	}
	return StyleSheetAnchorInvalidationRule{
		anchor_set: anchor_set
		anchor_selector: anchor_selector
		style_sheet_for_rule: style_sheet_for_rule
	}
}

fn extend_style_sheet_invalidation_set_with_style_rule(mut result StyleSheetInvalidationSet, style_rule &CSSRule) {
	mut mutable_rule := unsafe { &CSSRule(style_rule) }
	mut throwaway_data := StyleInvalidationData.new()
	for selector in mutable_rule.absolutized_selectors().selectors {
		result.may_match_light_dom_under_shadow_host = result.may_match_light_dom_under_shadow_host
			|| selector_may_match_light_dom_under_shadow_host(selector)
		result.may_match_light_dom_outside_shadow_host = result.may_match_light_dom_outside_shadow_host
			|| selector_may_match_light_dom_outside_shadow_host(selector)
		result.may_match_shadow_host = result.may_match_shadow_host
			|| selector.contains_pseudo_class(.host)
		compounds := selector.compound_selectors()
		if compounds.len == 0 {
			continue
		}
		rightmost := compounds[compounds.len - 1]
		mut rightmost_set := InvalidationSet{}
		for simple_index in 0 .. rightmost.simple_selectors.len {
			simple := unsafe { &rightmost.simple_selectors[simple_index] }
			build_invalidation_sets_for_simple_selector(simple_selector_for_invalidation(simple), mut rightmost_set, .no, mut throwaway_data, .no)
		}
		if rightmost_set_has_targetable_features(rightmost_set) {
			result.invalidation_set.include_all_from(rightmost_set)
			continue
		}
		// A bare structural-position pseudo can target boundary children. This runs only when the
		// rightmost set has no ordinary feature, so `.item:first-child` keeps targeting `.item` rather
		// than every first child in the tree.
		mut rightmost_has_structural_position_pseudo := false
		for simple in rightmost.simple_selectors {
			if simple.type_ == .pseudo_class
				&& simple.pseudo_class().type_ in [.first_child, .last_child, .only_child] {
				rightmost_has_structural_position_pseudo = true
				break
			}
		}
		if rightmost_has_structural_position_pseudo {
			for simple in rightmost.simple_selectors {
				if simple.type_ == .pseudo_class
					&& simple.pseudo_class().type_ in [.first_child, .last_child, .only_child] {
					result.invalidation_set.set_needs_invalidate_pseudo_class(css_pseudo_class_from_selector_pseudo_class(simple.pseudo_class().type_))
				}
			}
			continue
		}
		if style_sheet_compound_is_pseudo_element_only(rightmost) {
			if anchor := try_build_style_sheet_anchor_for_leading_compounds(compounds, mut throwaway_data, style_rule.parent_style_sheet) {
				result.pseudo_element_rules << StyleSheetPseudoElementInvalidationRule{
					anchor_set: anchor.anchor_set
					anchor_selector: anchor.anchor_selector
					style_sheet_for_rule: anchor.style_sheet_for_rule
				}
				continue
			}
		}
		if style_sheet_compound_is_universal_only(rightmost) {
			if anchor := try_build_style_sheet_anchor_for_leading_compounds(compounds, mut throwaway_data, style_rule.parent_style_sheet) {
				result.trailing_universal_rules << StyleSheetTrailingUniversalInvalidationRule{
					anchor_set: anchor.anchor_set
					anchor_selector: anchor.anchor_selector
					combinator: rightmost.combinator
					style_sheet_for_rule: anchor.style_sheet_for_rule
				}
				continue
			}
		}
		result.invalidation_set.set_needs_invalidate_whole_subtree()
		return
	}
}

fn mark_style_sheet_invalidation_element(element &dom.Element) {
	mut mutable_element := unsafe { &dom.Element(element) }
	mutable_element.set_needs_style_update(true)
}

fn style_sheet_element_matches_anchor_rule(element &dom.Element, anchor_set InvalidationSet, anchor_selector ?Selector, style_sheet_for_rule ?&CSSStyleSheet, shadow_host ?&dom.Element, rule_shadow_root ?&dom.ShadowRoot) bool {
	if !element.includes_properties_from_invalidation_set(invalidation_set_to_dom(anchor_set)) {
		return false
	}
	selector := anchor_selector or { return true }
	mut context := MatchContext{}
	if sheet := style_sheet_for_rule {
		context.style_sheet_for_rule = unsafe { &CSSStyleSheet(sheet) }
	}
	if root := rule_shadow_root {
		context.rule_shadow_root = unsafe { &dom.ShadowRoot(root) }
	}
	return matches(selector, element, shadow_host, mut context, none, none, .normal, none)
}

fn apply_style_sheet_trailing_universal_combinator(combinator Combinator, anchor &dom.Element, target_root &dom.Node) {
	match combinator {
		.immediate_child {
			for child in target_root.children_as_vector() {
				if element := child.as_element() {
					mark_style_sheet_invalidation_element(element)
				}
			}
		}
		.descendant {
			target_root.for_each_in_subtree(fn (node &dom.Node) dom.TraversalDecision {
				if element := node.as_element() {
					mark_style_sheet_invalidation_element(element)
				}
				return .@continue
			})
		}
		.next_sibling {
			if sibling := anchor.as_node().next_element_sibling() {
				mark_style_sheet_invalidation_element(sibling)
			}
		}
		.subsequent_sibling {
			mut sibling := anchor.as_node().next_element_sibling()
			for sibling != none {
				element := sibling or { break }
				mark_style_sheet_invalidation_element(element)
				sibling = element.as_node().next_element_sibling()
			}
		}
		.column {
			mut ancestor := ?&dom.Element(anchor)
			for ancestor != none {
				element := ancestor or { break }
				if element.is_html_element() && element.local_name() == 'table' {
					element.as_node().for_each_in_subtree(fn (node &dom.Node) dom.TraversalDecision {
						if cell := node.as_element() {
							if cell.is_html_element() && cell.local_name() in ['td', 'th'] {
								mark_style_sheet_invalidation_element(cell)
							}
						}
						return .@continue
					})
					break
				}
				ancestor = element.as_node().parent_element()
			}
		}
		.no_combinator {}
	}
}

fn invalidate_elements_matching_style_sheet_invalidation(root &dom.Node, result &StyleSheetInvalidationSet, shadow_host ?&dom.Element, rule_shadow_root ?&dom.ShadowRoot) {
	has_primary_set := result.invalidation_set.has_properties()
	has_anchor_rules := result.pseudo_element_rules.len > 0
		|| result.trailing_universal_rules.len > 0
	if !has_primary_set && !has_anchor_rules {
		return
	}
	primary_dom_set := invalidation_set_to_dom(result.invalidation_set)
	invalidate_matching_style_sheet_subtree(root, result, has_primary_set, primary_dom_set,
		shadow_host, rule_shadow_root)
}

fn invalidate_matching_style_sheet_subtree(node &dom.Node, result &StyleSheetInvalidationSet,
	has_primary_set bool, primary_dom_set dom.StyleInvalidationSet, shadow_host ?&dom.Element,
	rule_shadow_root ?&dom.ShadowRoot) {
	if element := node.as_element() {
		if has_primary_set && !element.needs_style_update()
			&& element.includes_properties_from_invalidation_set(primary_dom_set) {
			mark_style_sheet_invalidation_element(element)
		}
		if !element.needs_style_update() {
			for rule in result.pseudo_element_rules {
				if style_sheet_element_matches_anchor_rule(element, rule.anchor_set,
					rule.anchor_selector, rule.style_sheet_for_rule, shadow_host, rule_shadow_root)
				{
					mark_style_sheet_invalidation_element(element)
					break
				}
			}
		}
		for rule in result.trailing_universal_rules {
			if style_sheet_element_matches_anchor_rule(element, rule.anchor_set,
				rule.anchor_selector, rule.style_sheet_for_rule, shadow_host, rule_shadow_root)
			{
				apply_style_sheet_trailing_universal_combinator(rule.combinator, element,
					element.as_node())
			}
		}
	}
	for child in node.children {
		invalidate_matching_style_sheet_subtree(child, result, has_primary_set, primary_dom_set,
			shadow_host, rule_shadow_root)
	}
}

fn style_sheet_slot_or_ancestor_needs_style_update(slot &dom.HTMLSlotElement, shadow_root &dom.ShadowRoot) bool {
	shadow_node := unsafe { &dom.Node(shadow_root) }
	mut current := ?&dom.Node(slot.HTMLElement.Element.as_node())
	for current != none {
		node := current or { break }
		if node == shadow_node {
			break
		}
		if node.needs_style_update() {
			return true
		}
		current = node.parent_node()
	}
	return false
}

fn invalidate_assigned_elements_for_dirty_style_sheet_slots(shadow_root &dom.ShadowRoot) {
	shadow_node := unsafe { &dom.Node(shadow_root) }
	invalidate_dirty_style_sheet_slot_subtree(shadow_node, shadow_root)
}

fn invalidate_dirty_style_sheet_slot_subtree(node &dom.Node, shadow_root &dom.ShadowRoot) {
	if node.is_html_slot_element() {
		slot := unsafe { &dom.HTMLSlotElement(node) }
		if style_sheet_slot_or_ancestor_needs_style_update(slot, shadow_root) {
			options := dom.AssignedNodesOptions{
				flatten: true
			}
			for assigned in slot.assigned_elements(options) {
				mark_style_sheet_invalidation_element(assigned)
			}
		}
	}
	for child in node.children {
		invalidate_dirty_style_sheet_slot_subtree(child, shadow_root)
	}
}

fn invalidate_root_for_style_sheet_change(root &dom.Node, result &StyleSheetInvalidationSet, reason dom.StyleInvalidationReason, force_broad_invalidation bool) {
	if force_broad_invalidation || result.invalidation_set.needs_invalidate_whole_subtree() {
		mut mutable_root := unsafe { &dom.Node(root) }
		mutable_root.invalidate_style(reason)
		if shadow_root := root.as_shadow_root() {
			root_shadow_node := unsafe { &dom.Node(shadow_root) }
			root_shadow_node.for_each_in_inclusive_subtree(fn (node &dom.Node) dom.TraversalDecision {
				if node.is_html_slot_element() {
					mark_style_sheet_invalidation_element(unsafe { &dom.Element(node) })
				}
				return .@continue
			})
			invalidate_assigned_elements_for_dirty_style_sheet_slots(shadow_root)
			if host := shadow_root.host() {
				if result.may_match_light_dom_outside_shadow_host {
					mut host_root := unsafe { &dom.Node(host.as_node().root()) }
					host_root.invalidate_style(reason)
				} else if result.may_match_light_dom_under_shadow_host {
					mut host_node := host.as_node()
					host_node.invalidate_style(reason)
				} else if result.may_match_shadow_host {
					mut host_node := host.as_node()
					host_node.invalidate_style(reason)
					mut shadow_node := unsafe { &dom.Node(root) }
					shadow_node.set_needs_style_update(true)
				}
			}
		}
		return
	}

	shadow_root := root.as_shadow_root()
	mut shadow_host := ?&dom.Element(none)
	if value := shadow_root {
		shadow_host = value.host()
	}
	invalidate_elements_matching_style_sheet_invalidation(root, result, shadow_host, shadow_root)
	if value := shadow_root {
		invalidate_assigned_elements_for_dirty_style_sheet_slots(value)
		if host := value.host() {
			if result.may_match_light_dom_outside_shadow_host {
				invalidate_elements_matching_style_sheet_invalidation(host.as_node().root(), result, host, value)
			} else if result.may_match_light_dom_under_shadow_host {
				invalidate_elements_matching_style_sheet_invalidation(host.as_node(), result, host, value)
			} else if result.may_match_shadow_host {
				mut host_or_shadow_tree_needs_update := host.includes_properties_from_invalidation_set(invalidation_set_to_dom(result.invalidation_set))
				for rule in result.pseudo_element_rules {
					if style_sheet_element_matches_anchor_rule(host, rule.anchor_set, rule.anchor_selector, rule.style_sheet_for_rule, host, value) {
						host_or_shadow_tree_needs_update = true
						break
					}
				}
				if host_or_shadow_tree_needs_update {
					mark_style_sheet_invalidation_element(host)
					mut host_node := host.as_node()
					host_node.invalidate_style(reason)
					mut shadow_node := unsafe { &dom.Node(root) }
					shadow_node.set_needs_style_update(true)
				}
				for rule in result.trailing_universal_rules {
					if style_sheet_element_matches_anchor_rule(host, rule.anchor_set, rule.anchor_selector, rule.style_sheet_for_rule, host, value) {
						apply_style_sheet_trailing_universal_combinator(rule.combinator, host, host.as_node())
					}
				}
			}
		}
	}
}

fn invalidate_owners_for_inserted_style_rule(mut style_sheet CSSStyleSheet, style_rule &CSSRule, reason dom.StyleInvalidationReason) {
	style_sheet.did_match = none
	mut invalidation := &StyleSheetInvalidationSet{}
	extend_style_sheet_invalidation_set_with_style_rule(mut invalidation, style_rule)
	for owner in style_sheet.owning_documents_or_shadow_roots {
		mut scope := css_style_scope_for_node(owner)
		scope.invalidate_rule_cache()
		invalidate_root_for_style_sheet_change(owner, invalidation, reason, false)
	}
}

fn invalidate_trees_affected_by_keyframes(root &dom.Node, include_host bool,
	include_light_dom_under_shadow_host bool, animation_name string) {
	invalidate_elements_affected_by_inserted_keyframes_rule(root, animation_name)
	if shadow_root := root.as_shadow_root() {
		host := shadow_root.host() or { return }
		if include_host && include_light_dom_under_shadow_host {
			invalidate_elements_affected_by_inserted_keyframes_rule(host.as_node().root(),
				animation_name)
		} else if include_host || include_light_dom_under_shadow_host {
			invalidate_elements_affected_by_inserted_keyframes_rule(host.as_node(), animation_name)
		}
	}
}

fn style_value_references_animation_name(value StyleValue, animation_name string) bool {
	if value is CustomIdentStyleValue {
		return value.custom_ident() == animation_name
	}
	if value is StringStyleValue {
		return value.string_value() == animation_name
	}
	if value !is StyleValueList {
		return false
	}
	list := value as StyleValueList
	for item in list.values() {
		if item is CustomIdentStyleValue && item.custom_ident() == animation_name {
			return true
		}
		if item is StringStyleValue && item.string_value() == animation_name {
			return true
		}
	}
	return false
}

fn computed_properties_reference_animation_name(computed &ComputedProperties, animation_name string) bool {
	value := computed.property(.animation_name, .no) or { return false }
	typed := style_value_logic_from_dom(.animation_name, value) or { return false }
	return style_value_references_animation_name(typed, animation_name)
}

fn element_or_pseudo_references_animation_name(element &dom.Element, animation_name string) bool {
	if placeholder := element.computed_properties_for_pseudo(none) {
		if computed := computed_properties_from_dom(placeholder) {
			if computed_properties_reference_animation_name(computed, animation_name) {
				return true
			}
		}
	}
	// Computed pseudo styles need not have layout nodes. The record map is
	// empty for most elements, so avoid probing every known pseudo on a miss.
	if element.pseudo_element_record_count() == 0 {
		return false
	}
	for pseudo := 0; pseudo < int(dom.PseudoElement.known_pseudo_element_count); pseudo++ {
		if placeholder := element.computed_properties_for_pseudo(pseudo) {
			if computed := computed_properties_from_dom(placeholder) {
				if computed_properties_reference_animation_name(computed, animation_name) {
					return true
				}
			}
		}
	}
	return false
}

fn invalidate_elements_affected_by_inserted_keyframes_rule(root &dom.Node, animation_name string) {
	invalidate_animation_name_subtree(root, animation_name, root.is_document())
}

fn invalidate_animation_name_subtree(node &dom.Node, animation_name string, include_shadow bool) {
	if element := node.as_element() {
		if element_or_pseudo_references_animation_name(element, animation_name) {
			mark_style_sheet_invalidation_element(element)
		}
		if include_shadow {
			if shadow_root := element.shadow_root() {
				invalidate_animation_name_subtree(unsafe { &dom.Node(shadow_root) },
					animation_name, true)
			}
		}
	}
	for child in node.children {
		invalidate_animation_name_subtree(child, animation_name, include_shadow)
	}
}

struct StyleSheetKeyframesInvalidationContext {
	root                                &dom.Node
	include_host                        bool
	include_light_dom_under_shadow_host bool
}

fn invalidate_style_sheet_keyframes_rule(context voidptr, rule &CSSRule) {
	if rule.type_ != .keyframes { return }
	state := unsafe { &StyleSheetKeyframesInvalidationContext(context) }
	invalidate_trees_affected_by_keyframes(state.root, state.include_host,
		state.include_light_dom_under_shadow_host, rule.keyframes_name())
}

fn invalidate_root_for_keyframes_rules_in_sheet(root &dom.Node, sheet &CSSStyleSheet) {
	// Shadow-scoped keyframes can affect the host or its light DOM when another active rule in the
	// same scope assigns animation-name through :host or ::slotted(...). Mirror the per-rule fan-out.
	mut include_host := false
	mut include_light_dom_under_shadow_host := false
	if shadow_root := root.as_shadow_root() {
		effects := determine_shadow_root_style_sheet_effects(shadow_root)
		include_host = effects.may_match_shadow_host
		include_light_dom_under_shadow_host = effects.may_match_light_dom_under_shadow_host
	}
	state := StyleSheetKeyframesInvalidationContext{
		root:                                root
		include_host:                        include_host
		include_light_dom_under_shadow_host: include_light_dom_under_shadow_host
	}
	sheet.for_each_effective_rule_with_context(.preorder, voidptr(&state),
		invalidate_style_sheet_keyframes_rule)
}

fn style_sheet_selector_may_affect_assigned_nodes_via_slot_inheritance(selector Selector, slots []&dom.Element, style_sheet &CSSStyleSheet, shadow_root &dom.ShadowRoot) bool {
	shadow_node := unsafe { &dom.Node(shadow_root) }
	for slot in slots {
		mut current := ?&dom.Node(slot.as_node())
		for current != none {
			node := current or { break }
			if node == shadow_node {
				break
			}
			if element := node.as_element() {
				mut context := MatchContext{}
				context.style_sheet_for_rule = unsafe { &CSSStyleSheet(style_sheet) }
				context.subject = unsafe { &dom.Element(element) }
				context.rule_shadow_root = unsafe { &dom.ShadowRoot(shadow_root) }
				if matches(selector, element, shadow_root.host(), mut context, none, none, .normal, none) {
					return true
				}
			}
			current = node.parent_node()
		}
	}
	return false
}

fn collect_style_sheet_slots(node &dom.Node, mut slots []&dom.Element) {
	if node.is_html_slot_element() {
		if element := node.as_element() { slots << element }
	}
	for child in node.children {
		collect_style_sheet_slots(child, mut slots)
	}
}

struct ShadowSheetEffectsContext {
	style_sheet &CSSStyleSheet
	shadow_root &dom.ShadowRoot
	slots       []&dom.Element
mut:
	effects ShadowRootStylesheetEffects
}

fn collect_shadow_sheet_rule_effects(context voidptr, rule &CSSRule) {
	mut state := unsafe { &ShadowSheetEffectsContext(context) }
	if state.effects.all_set() || rule.type_ != .style { return }
	mut mutable_rule := unsafe { &CSSRule(rule) }
	for selector in mutable_rule.absolutized_selectors().selectors {
		state.effects.may_match_shadow_host = state.effects.may_match_shadow_host
			|| selector.contains_pseudo_class(.host)
		state.effects.may_match_light_dom_under_shadow_host =
			state.effects.may_match_light_dom_under_shadow_host
			|| selector_may_match_light_dom_under_shadow_host(selector)
		state.effects.may_match_light_dom_outside_shadow_host =
			state.effects.may_match_light_dom_outside_shadow_host
			|| selector_may_match_light_dom_outside_shadow_host(selector)
		if !state.effects.may_affect_assigned_nodes_via_slots && state.slots.len > 0 {
			state.effects.may_affect_assigned_nodes_via_slots = style_sheet_selector_may_affect_assigned_nodes_via_slot_inheritance(selector,
				state.slots, state.style_sheet, state.shadow_root)
		}
		if state.effects.all_set() { break
		 }
	}
}

fn determine_shadow_root_style_sheet_effects_for_sheet(style_sheet &CSSStyleSheet, shadow_root &dom.ShadowRoot) ShadowRootStylesheetEffects {
	mut slots := []&dom.Element{}
	collect_style_sheet_slots(unsafe { &dom.Node(shadow_root) }, mut slots)
	state := ShadowSheetEffectsContext{
		style_sheet: style_sheet
		shadow_root: shadow_root
		slots:       slots
	}
	style_sheet.for_each_effective_rule_with_context(.preorder, voidptr(&state),
		collect_shadow_sheet_rule_effects)
	return state.effects
}

struct ShadowScopeEffectsContext {
	shadow_root &dom.ShadowRoot
mut:
	effects ShadowRootStylesheetEffects
}

fn collect_shadow_scope_sheet_effects(context voidptr, style_sheet &CSSStyleSheet) {
	mut state := unsafe { &ShadowScopeEffectsContext(context) }
	sheet_effects := determine_shadow_root_style_sheet_effects_for_sheet(style_sheet,
		state.shadow_root)
	state.effects.may_match_shadow_host = state.effects.may_match_shadow_host
		|| sheet_effects.may_match_shadow_host
	state.effects.may_match_light_dom_under_shadow_host =
		state.effects.may_match_light_dom_under_shadow_host
		|| sheet_effects.may_match_light_dom_under_shadow_host
	state.effects.may_match_light_dom_outside_shadow_host =
		state.effects.may_match_light_dom_outside_shadow_host
		|| sheet_effects.may_match_light_dom_outside_shadow_host
	state.effects.may_affect_assigned_nodes_via_slots =
		state.effects.may_affect_assigned_nodes_via_slots
		|| sheet_effects.may_affect_assigned_nodes_via_slots
}

fn determine_shadow_root_style_sheet_effects(shadow_root &dom.ShadowRoot) ShadowRootStylesheetEffects {
	state := ShadowScopeEffectsContext{
		shadow_root: shadow_root
	}
	scope := css_style_scope_for_shadow_root(shadow_root)
	style_scope_for_each_active_css_style_sheet_boundary_with_context(scope, voidptr(&state),
		collect_shadow_scope_sheet_effects)
	return state.effects
}

fn style_computer_shadow_root_may_match_host_callback(_ voidptr, shadow_root &dom.ShadowRoot) bool {
	return determine_shadow_root_style_sheet_effects(shadow_root).may_match_shadow_host
}

fn determine_shadow_root_style_sheet_effects_for_style_sheet(style_sheet &CSSStyleSheet) ShadowRootStylesheetEffects {
	mut effects := ShadowRootStylesheetEffects{}
	for owner in style_sheet.owning_documents_or_shadow_roots {
		shadow_root := owner.as_shadow_root() or { continue }
		sheet_effects := determine_shadow_root_style_sheet_effects_for_sheet(style_sheet, shadow_root)
		effects.may_match_shadow_host = effects.may_match_shadow_host
			|| sheet_effects.may_match_shadow_host
		effects.may_match_light_dom_under_shadow_host = effects.may_match_light_dom_under_shadow_host
			|| sheet_effects.may_match_light_dom_under_shadow_host
		effects.may_match_light_dom_outside_shadow_host = effects.may_match_light_dom_outside_shadow_host
			|| sheet_effects.may_match_light_dom_outside_shadow_host
		effects.may_affect_assigned_nodes_via_slots = effects.may_affect_assigned_nodes_via_slots
			|| sheet_effects.may_affect_assigned_nodes_via_slots
		if effects.all_set() {
			break
		}
	}
	return effects
}

fn invalidate_owners_for_inserted_keyframes_rule(mut style_sheet CSSStyleSheet, keyframes_rule &CSSRule) {
	style_sheet.did_match = none
	for owner in style_sheet.owning_documents_or_shadow_roots {
		mut scope := css_style_scope_for_node(owner)
		scope.invalidate_rule_cache()
		if owner.as_shadow_root() == none && owner.entire_subtree_needs_style_update() {
			continue
		}
		mut include_host := false
		mut include_light_dom_under_shadow_host := false
		if shadow_root := owner.as_shadow_root() {
			effects := determine_shadow_root_style_sheet_effects(shadow_root)
			include_host = effects.may_match_shadow_host
			include_light_dom_under_shadow_host = effects.may_match_light_dom_under_shadow_host
		}
		animation_name := keyframes_rule.keyframes_name()
		invalidate_trees_affected_by_keyframes(owner, include_host,
			include_light_dom_under_shadow_host, animation_name)
	}
}

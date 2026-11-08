module css

import dom
import os

const disable_disjunctive_subject_masks = os.getenv('VOX_DISABLE_DISJUNCTIVE_SUBJECT_MASKS') != ''
const disjunctive_subject_mask_diagnostics = os.getenv('VOX_DISJUNCTIVE_SUBJECT_MASK_DIAGNOSTICS') != ''
__global disjunctive_subject_masks_reported bool

struct MaskedSubjectRule {
	rule &MatchingRule
	mask u64
}

@[heap]
struct DisjunctiveSubjectMasks {
mut:
	rules []MaskedSubjectRule
	classes map[string]u64
	ids map[string]u64
	tags map[string]u64
	bits uint
}

fn disjunctive_subject_names(selector Selector) []SimplifiedSelectorForBucketing {
	compounds := selector.compound_selectors()
	if compounds.len == 0 { return []SimplifiedSelectorForBucketing{} }
	for simple in compounds.last().simple_selectors {
		if simple.type_ != .pseudo_class { continue }
		pseudo := simple.pseudo_class()
		if pseudo.type_ !in [.is_, .where] || pseudo.argument_selector_list.selectors.len < 2 { continue }
		mut names := []SimplifiedSelectorForBucketing{}
		for branch in pseudo.argument_selector_list.selectors {
			parts := branch.compound_selectors()
			if parts.len == 0 { names.clear(); break }
			mut found := false
			for index := parts.last().simple_selectors.len - 1; index >= 0; index-- {
				if name := subject_bucket_name(parts.last().simple_selectors[index]) {
					if name !in names { names << name }
					found = true
					break
				}
			}
			if !found { names.clear(); break }
		}
		if names.len > 0 { return names }
	}
	return []SimplifiedSelectorForBucketing{}
}

fn (mut cache RuleCache) append_other_subject_rule(rule &MatchingRule) {
	cache.other_rules << rule
	if disable_disjunctive_subject_masks { return }
	if cache.disjunctive_subject_masks_ == unsafe { nil } {
		cache.disjunctive_subject_masks_ = &DisjunctiveSubjectMasks{}
	}
	mut index := cache.disjunctive_subject_masks_
	names := if index.bits < 64 { disjunctive_subject_names(rule.selector) }
		else { []SimplifiedSelectorForBucketing{} }
	mask := if names.len > 0 { u64(1) << index.bits } else { u64(0) }
	if mask != 0 {
		index.bits++
		for name in names {
			match name.type_ {
				.class { index.classes[cache.selector_name_bucket_key(name.name)] |= mask }
				.id { index.ids[cache.selector_name_bucket_key(name.name)] |= mask }
				.tag_name { index.tags[name.name] |= mask }
				else {}
			}
		}
	}
	index.rules << MaskedSubjectRule{rule, mask}
}

// The union of positive subject buckets supplies one bit per original rule.
// Iterate that original vector once, so overlapping alternatives cannot emit
// duplicates or change candidate order. Public bucket APIs remain live views.
fn style_scope_add_masked_other_rules(computer &StyleComputer, subject dom.AbstractElement,
	cache &RuleCache, rule_root ?&dom.ShadowRoot, shadow_root ?&dom.ShadowRoot,
	element_shadow_root ?&dom.ShadowRoot, mut rules []ScopedMatchingRule) {
	index := cache.disjunctive_subject_masks_
	if disable_disjunctive_subject_masks || !cache.disjunctive_subject_masks_trusted_
		|| index == unsafe { nil } || index.bits == 0
		|| index.rules.len != cache.other_rules.len {
		style_scope_add_rules_to_run(computer, subject, cache.other_rules, rule_root, shadow_root, element_shadow_root, mut rules)
		return
	}
	element := subject.element()
	mut possible := u64(0)
	if index.classes.len > 0 {
		for name in element.classes { possible |= index.classes[cache.selector_name_bucket_key(name)] }
	}
	if index.ids.len > 0 {
		if name := element.id() { possible |= index.ids[cache.selector_name_bucket_key(name)] }
	}
	if index.tags.len > 0 { possible |= index.tags[element.lowercased_local_name()] }
	if disjunctive_subject_mask_diagnostics && !disjunctive_subject_masks_reported {
		disjunctive_subject_masks_reported = true
		eprintln('Vox selector disjunction: collected positive subject masks without duplicate rules')
	}
	namespace_uri := element.namespace_uri()
	pseudo := style_scope_pseudo_element_from_abstract_element(subject)
	for offset, rule in cache.other_rules {
		entry := unsafe { &index.rules[offset] }
		if voidptr(entry.rule) == voidptr(rule) && entry.mask != 0 && entry.mask & possible == 0 { continue }
		if target := pseudo {
			if !style_scope_selector_targets_pseudo_element(rule.selector, target) { continue }
		} else if !rule.slotted && !rule.contains_part_pseudo_element && rule.contains_pseudo_element { continue }
		if !style_scope_filter_namespace_rule(namespace_uri, rule) { continue }
		style_scope_add_rule_to_run(computer, subject, rule, rule_root, shadow_root, element_shadow_root, mut rules)
	}
}

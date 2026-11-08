module css

import dom
import os

const disable_pseudo_subject_rule_index = os.getenv('VOX_DISABLE_PSEUDO_SUBJECT_RULE_INDEX') != ''

// Scope-built caches keep the same bucket order and MatchingRule identities,
// with an additional view for each terminal pseudo-element. A ::before query
// then looks up only buckets containing ::before selectors. Slot and part
// collection keep their separate scope-crossing paths.
fn (mut cache RuleCache) index_pseudo_subject_rule(rule &MatchingRule,
	pseudo_element ?PseudoElement, contains_root bool) {
	if disable_pseudo_subject_rule_index { return }
	cache.pseudo_subject_index_ready_ = true
	if rule.slotted || rule.contains_part_pseudo_element { return }
	// Matching uses the selector's terminal target; the coarse existence query
	// uses MatchingRule's recorded target. Keep both views for chained pseudos.
	mut terminal := ?PseudoElement(none)
	if rule.selector.data_ != unsafe { nil } {
		if target := rule.selector.data_.pseudo_element { terminal = target.type_ }
	}
	if target := terminal {
		cache.index_pseudo_subject_target(rule, pseudo_element, contains_root, target)
	}
	if recorded := rule.pseudo_element {
		if previous := terminal {
			if previous == recorded { return }
		}
		cache.index_pseudo_subject_target(rule, pseudo_element, contains_root, recorded)
	}
}

fn (mut cache RuleCache) index_pseudo_subject_target(rule &MatchingRule,
	pseudo_element ?PseudoElement, contains_root bool, target PseudoElement) {
	mut index := cache.pseudo_subject_rules_[target] or {
		created := RuleCache.new()
		cache.pseudo_subject_rules_[target] = created
		created
	}
	index.fold_id_and_class_name_case = cache.fold_id_and_class_name_case
	index.add_rule(rule, pseudo_element, contains_root)
}

fn pseudo_subject_rule_cache_for_type(cache &RuleCache, pseudo PseudoElement) ?&RuleCache {
	if disable_pseudo_subject_rule_index || !cache.pseudo_subject_index_ready_ { return cache }
	return cache.pseudo_subject_rules_[pseudo] or { return none }
}

fn pseudo_subject_rule_cache(cache &RuleCache, element dom.AbstractElement) ?&RuleCache {
	pseudo := style_scope_pseudo_element_from_abstract_element(element) or { return cache }
	return pseudo_subject_rule_cache_for_type(cache, pseudo)
}

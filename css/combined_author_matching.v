module css

import dom
import os
import platform

// Author rules are cached per cascade layer, and matching used to collect each
// layer separately: GitHub declares about ten layers, so every element (and
// every pseudo-element attempt) looked up its id, class, tag and attribute
// buckets once per layer. Each RuleCaches also indexes all of its rules in
// one cache, in the same insertion order. One collection over that index
// finds the same rules; splitting them by the layer cache that holds them,
// in layer order and then the unlayered rules, and sorting each part gives
// the per-layer lists exactly: a layer's rules keep their relative order.
const disable_combined_author_matching = os.getenv('VOX_DISABLE_COMBINED_AUTHOR_MATCHING') != ''

// The reserved layer name that selects RuleCaches.all. A qualified layer
// name never starts with NUL.
const all_layers_rule_cache_name = '\x00all-layers'

$if test {
	__global combined_author_matching_disabled_for_test bool
}

fn use_combined_author_matching() bool {
	$if test {
		if combined_author_matching_disabled_for_test { return false }
	}
	return !disable_combined_author_matching
}

fn collect_author_rules_by_layer(style_computer &StyleComputer, abstract_element dom.AbstractElement,
	mut matching_rule_set MatchingRuleSet, mut attempted_pseudo_class_matches PseudoClassBitmap,
	scope &StyleScope, storage &platform.Arena) {
	all := collect_matching_rules_with_storage(style_computer, abstract_element, .author,
		mut attempted_pseudo_class_matches, all_layers_rule_cache_name, scope, storage)
	for layer_name in scope.qualified_layer_names_in_order {
		mut layer_rules := []ScopedMatchingRule{}
		for rule in all {
			if rule.rule.in_layer_cache && rule.rule.cache_layer_name == layer_name {
				append_scoped_matching_rule(mut layer_rules, rule, storage)
			}
		}
		sort_matching_rules(mut layer_rules)
		append_matching_layer(mut matching_rule_set.author_rules, LayerMatchingRules{
			qualified_layer_name: layer_name
			rules: layer_rules
		}, storage)
	}
	mut unlayered := []ScopedMatchingRule{}
	for rule in all {
		if !rule.rule.in_layer_cache {
			append_scoped_matching_rule(mut unlayered, rule, storage)
		}
	}
	sort_matching_rules(mut unlayered)
	append_matching_layer(mut matching_rule_set.author_rules, LayerMatchingRules{
		qualified_layer_name: ''
		rules: unlayered
	}, storage)
}

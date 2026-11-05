module css

import dom
import os

const retain_attribute_bucket_candidates = os.getenv('VOX_RETAIN_ATTRIBUTE_BUCKET_CANDIDATES') != ''
const attribute_bucket_pair_diagnostics = os.getenv('VOX_ATTRIBUTE_BUCKET_PAIR_DIAGNOSTICS') != ''

__global attribute_bucket_pair_reported bool

struct AttributeBucketBytePairs {
mut:
	bits [16]u64
	ready bool
}

@[inline]
fn attribute_bucket_pair_hash(first u8, second u8) u32 {
	return (u32(selector_substring_fold_byte(first)) * 257
		+ u32(selector_substring_fold_byte(second)) * 17) & 1023
}

// Every matching nonempty attribute value pattern must contain these pairs.
// ASCII folding and hash collisions only admit extra candidates. The ordinary
// matcher still decides operators, case, namespaces and the whole selector.
fn attribute_bucket_pattern_might_match(value string, pattern string, mut pairs AttributeBucketBytePairs) bool {
	if pattern.len < 2 { return true }
	if pattern.len > value.len { return false }
	if !pairs.ready {
		for i in 1 .. value.len {
			h := attribute_bucket_pair_hash(value[i - 1], value[i])
			pairs.bits[h >> 6] |= u64(1) << (h & 63)
		}
		pairs.ready = true
	}
	first := attribute_bucket_pair_hash(pattern[0], pattern[1])
	last := attribute_bucket_pair_hash(pattern[pattern.len - 2], pattern[pattern.len - 1])
	return pairs.bits[first >> 6] & (u64(1) << (first & 63)) != 0
		&& pairs.bits[last >> 6] & (u64(1) << (last & 63)) != 0
}

fn attribute_bucket_rule_is_impossible(rule &MatchingRule, name string, value string, mut pairs AttributeBucketBytePairs) bool {
	// Skipping dynamic/relational selectors could discard attempted-pseudo or
	// selector-involvement metadata. Scoped rules can also evaluate pseudos in
	// their scope roots/limits before matching the subject. Keep those paths.
	if rule.scope_rule != none || rule.container_rule != none || rule.slotted
		|| rule.contains_part_pseudo_element || rule.contains_pseudo_element {
		return false
	}
	compounds := rule.selector.compound_selectors()
	if compounds.len != 1 || compounds[0].combinator != .no_combinator { return false }
	mut pattern := ''
	for index in 0 .. compounds[0].simple_selectors.len {
		simple := &compounds[0].simple_selectors[index]
		if simple.type_ !in [.tag_name, .universal, .id, .class, .attribute] { return false }
		if simple.type_ != .attribute { continue }
		attribute := simple.attribute()
		if attribute.match_type != .has_attribute && attribute.value.len >= 2
			&& attribute.qualified_name.namespace_type in [.default_, .none]
			&& attribute.qualified_name.name.name == name {
			pattern = attribute.value
		}
	}
	// Read current selector payloads on every visit: public rules and selectors
	// are mutable. Nothing here retains element, selector or value storage.
	return pattern.len >= 2 && !attribute_bucket_pattern_might_match(value, pattern, mut pairs)
}

fn style_scope_add_attribute_bucket_rules_to_run(style_computer &StyleComputer, abstract_element dom.AbstractElement, name string, rules []&MatchingRule, rule_root ?&dom.ShadowRoot, shadow_root ?&dom.ShadowRoot, element_shadow_root ?&dom.ShadowRoot, mut rules_to_run []ScopedMatchingRule) {
	if retain_attribute_bucket_candidates || rules.len < 8
		|| style_scope_pseudo_element_from_abstract_element(abstract_element) != none {
		style_scope_add_rules_to_run(style_computer, abstract_element, rules, rule_root, shadow_root, element_shadow_root, mut rules_to_run)
		return
	}
	element := abstract_element.element()
	// Use the same qualified-name lookup as matches_attribute_in_namespace,
	// including duplicate namespace/name behavior. A bucket's triggering Attr
	// is not necessarily the one the ordinary matcher would read.
	attribute := element.get_attribute_node(name) or {
		style_scope_add_rules_to_run(style_computer, abstract_element, rules, rule_root, shadow_root, element_shadow_root, mut rules_to_run)
		return
	}
	value := attribute.value()
	if value.len > 512 {
		style_scope_add_rules_to_run(style_computer, abstract_element, rules, rule_root, shadow_root, element_shadow_root, mut rules_to_run)
		return
	}
	mut pairs := AttributeBucketBytePairs{}
	element_namespace_uri := element.namespace_uri()
	for rule in rules {
		if attribute_bucket_rule_is_impossible(rule, name, value, mut pairs) {
			if attribute_bucket_pair_diagnostics && !attribute_bucket_pair_reported {
				attribute_bucket_pair_reported = true
				eprintln('Vox attribute candidates: rejected an absent required byte pair')
			}
			continue
		}
		// The same ordinary-element eligibility and scope checks as the shared
		// collector, without allocating a one-rule array for each survivor.
		if (rule.slotted || rule.contains_part_pseudo_element || !rule.contains_pseudo_element)
			&& style_scope_filter_namespace_rule(element_namespace_uri, rule) {
			style_scope_add_rule_to_run(style_computer, abstract_element, rule, rule_root, shadow_root, element_shadow_root, mut rules_to_run)
		}
	}
}

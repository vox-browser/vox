module css

import dom
import os

const disable_exact_attribute_buckets = os.getenv('VOX_DISABLE_EXACT_ATTRIBUTE_BUCKETS') != ''
const exact_attribute_bucket_diagnostics = os.getenv('VOX_EXACT_ATTRIBUTE_BUCKET_DIAGNOSTICS') != ''

__global exact_attribute_bucket_reported bool

@[heap]
struct ExactAttributeRuleBuckets {
mut:
	values map[string][]&MatchingRule
}

// Bucket only a required attribute of the subject compound. Keep class/ID
// preference, namespace-dependent names and all case-folded values on their
// ordinary paths. Full matching still checks every remaining selector part.
fn exact_attribute_rule_bucket(compound CompoundSelector) ?(string, string) {
	if disable_exact_attribute_buckets { return none }
	mut selected := ?SelectorAttribute(none)
	for index := compound.simple_selectors.len - 1; index >= 0; index-- {
		component := &compound.simple_selectors[index]
		if component.type_ in [.class, .id] { return none }
		if simplified := style_scope_is_roundabout_selector_bucketable_as_something_simpler(*component) {
			if simplified.type_ in [.class, .id] { return none }
		}
		if component.type_ != .attribute || selected != none { continue }
		attribute := component.attribute()
		name := attribute.qualified_name.name.lowercase_name
		if attribute.match_type != .exact_value_match
			|| attribute.qualified_name.namespace_type !in [.default_, .none]
			|| name.len == 0 || name.contains(':')
			|| attribute.case_type == .case_insensitive_match
			|| (attribute.case_type == .default_match
				&& selector_html_attribute_is_case_insensitive(name)) { continue }
		selected = attribute
	}
	attribute := selected or { return none }
	return attribute.qualified_name.name.lowercase_name, attribute.value
}

fn (mut cache RuleCache) add_exact_attribute_rule(name string, value string, rule &MatchingRule) {
	if name !in cache.rules_by_exact_attribute {
		cache.rules_by_exact_attribute[name] = &ExactAttributeRuleBuckets{}
	}
	mut buckets := unsafe { cache.rules_by_exact_attribute[name] }
	style_scope_push_rule(mut buckets.values, value, rule)
}

fn (cache &RuleCache) exact_attribute_rules(attribute &dom.Attr_) ?[]&MatchingRule {
	if cache.rules_by_exact_attribute.len == 0 { return none }
	name := rule_cache_attribute_bucket_name(attribute.name())
	buckets := cache.rules_by_exact_attribute[name] or { return none }
	// Read the current value on every traversal: replacement, namespace edits
	// and Attr.value mutations need no independent invalidation cache here.
	if exact_attribute_bucket_diagnostics && !exact_attribute_bucket_reported {
		exact_attribute_bucket_reported = true
		eprintln('Vox exact attribute buckets: selected rules by live value')
	}
	if attribute.value() in buckets.values { return unsafe { buckets.values[attribute.value()] } }
	return none
}

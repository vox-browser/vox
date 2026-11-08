module css

import os
import platform

const disable_generated_pseudo_content_preflight = os.getenv('VOX_DISABLE_GENERATED_PSEUDO_CONTENT_PREFLIGHT') != ''

fn rules_may_set_generated_content(rules []ScopedMatchingRule) bool {
	for scoped in rules {
		rule := scoped.rule.rule or { continue }
		declaration := rule.style() or { continue }
		_ = declaration_style_properties(declaration)
		if declaration.typed_may_set_content_ { return true }
	}
	return false
}

// Only content itself and all can supply a content longhand. Without either,
// ::before/::after creation would reach the existing absent/normal-content
// return after installing custom properties and performing two cascades.
// Ordinary computed-style queries still use the complete computation path.
fn generated_pseudo_has_no_content_declaration(rules MatchingRuleSet) bool {
	if disable_generated_pseudo_content_preflight { return false }
	// Deferred declarations and their typed metadata outlive this query.
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	if rules_may_set_generated_content(rules.user_agent_rules)
		|| rules_may_set_generated_content(rules.user_rules) {
		return false
	}
	for layer in rules.author_rules {
		if rules_may_set_generated_content(layer.rules) { return false }
	}
	return true
}

module css

import os

const retain_broad_conditional_rule_deletion = os.getenv('VOX_RETAIN_BROAD_CONDITIONAL_RULE_DELETION') != ''
const deleted_conditional_rule_diagnostics = os.getenv('VOX_DELETED_CONDITIONAL_RULE_DIAGNOSTICS') != ''

__global deleted_conditional_rule_reported bool

fn deleted_conditional_tree_has_only_leaf_styles(rule &CSSRule) bool {
	if rule.type_ !in [.style, .media, .supports] { return false }
	if children := rule.css_rules() {
		if rule.type_ == .style && children.rules.len > 0 { return false }
		for child in children.rules {
			if !deleted_conditional_tree_has_only_leaf_styles(child) { return false }
		}
	}
	return true
}

fn can_target_deleted_conditional_style_rule(rule &CSSRule) bool {
	return !retain_broad_conditional_rule_deletion && rule.type_ in [.media, .supports]
		&& deleted_conditional_tree_has_only_leaf_styles(rule)
}

// Project every branch before removal releases its stylesheet/namespace context.
// A condition can be stale while a viewport update is pending, so include its
// former subjects even when the current condition would not match. Independent
// changes in remaining media rules still select the existing broad fallback.
fn extend_deleted_conditional_style_invalidation(mut result StyleSheetInvalidationSet,
	rule &CSSRule) {
	if rule.type_ == .style {
		extend_style_sheet_invalidation_set_with_style_rule(mut result, rule)
	}
	if children := rule.css_rules() {
		for child in children.rules {
			extend_deleted_conditional_style_invalidation(mut result, child)
		}
	}
}

fn report_deleted_conditional_style_rule(sheet &CSSStyleSheet) {
	if !deleted_conditional_rule_diagnostics || deleted_conditional_rule_reported { return }
	if document := sheet.owning_document() {
		deleted_conditional_rule_reported = true
		eprintln('Vox deleted conditional rule: selected style-only invalidation; document=${document.url.serialize()}')
	}
}

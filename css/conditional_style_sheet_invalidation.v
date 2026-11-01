module css

import dom
import os

const disable_conditional_sheet_invalidation = os.getenv('VOX_DISABLE_CONDITIONAL_SHEET_INVALIDATION') != ''
const conditional_sheet_invalidation_diagnostics = os.getenv('VOX_CONDITIONAL_SHEET_INVALIDATION_DIAGNOSTICS') != ''

__global conditional_sheet_invalidation_reported bool

// Conditional groups containing only style rules change the same subjects as
// those selectors. Rules that register fonts, layers, properties or other
// global state retain the stylesheet-wide invalidation path.
fn conditional_style_rule_tree_has_only_selectors(rule &CSSRule) bool {
	if rule.type_ !in [.style, .media, .supports] { return false }
	if rules := rule.css_rules() {
		for child in rules.rules {
			if !conditional_style_rule_tree_has_only_selectors(child) { return false }
		}
	}
	return true
}

fn can_target_inserted_conditional_style_rule(rule &CSSRule) bool {
	return !disable_conditional_sheet_invalidation && rule.type_ in [.media, .supports]
		&& conditional_style_rule_tree_has_only_selectors(rule)
}

fn extend_conditional_style_rule_invalidation(mut result StyleSheetInvalidationSet, rule &CSSRule) {
	if rule.type_ == .style {
		extend_style_sheet_invalidation_set_with_style_rule(mut result, rule)
	}
	if rules := rule.css_rules() {
		for child in rules.rules {
			extend_conditional_style_rule_invalidation(mut result, child)
		}
	}
}

fn invalidate_owners_for_inserted_conditional_style_rule(mut sheet CSSStyleSheet, rule &CSSRule) {
	sheet.did_match = none
	sheet.invalidate_shared_style_cache()
	if document := sheet.owning_document() {
		// First evaluation of the inserted group is new state. A change in an
		// older rule can affect subjects outside this group's selector set.
		if sheet.evaluate_media_queries(document) {
			sheet.invalidate_owners(.style_sheet_insert_rule)
			return
		}
	}
	mut invalidation := &StyleSheetInvalidationSet{}
	extend_conditional_style_rule_invalidation(mut invalidation, rule)
	for owner in sheet.owning_documents_or_shadow_roots {
		mut scope := css_style_scope_for_node(owner)
		scope.invalidate_rule_cache()
		invalidate_root_for_style_sheet_change(owner, invalidation, .style_sheet_insert_rule, false)
	}
	if conditional_sheet_invalidation_diagnostics && !conditional_sheet_invalidation_reported {
		conditional_sheet_invalidation_reported = true
		eprintln('Vox conditional stylesheet: selected style-only group invalidation')
	}
}

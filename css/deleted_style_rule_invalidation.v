module css

import os

const disable_deleted_style_rule_invalidation = os.getenv('VOX_DISABLE_DELETED_STYLE_RULE_INVALIDATION') != ''
const deleted_style_rule_invalidation_diagnostics = os.getenv('VOX_DELETED_STYLE_RULE_INVALIDATION_DIAGNOSTICS') != ''

// Ordinary leaves and selector-only conditional groups affect their former
// selector subjects. Preserve the broad path for nested style/global effects,
// constructed sheets, and owners outside inline style elements.
fn invalidation_for_deleted_style_rule(sheet &CSSStyleSheet, index u32) ?&StyleSheetInvalidationSet {
	if disable_deleted_style_rule_invalidation || sheet.constructed
		|| int(index) >= sheet.rules.rules.len {
		return none
	}
	owner := sheet.base.owner_node or { return none }
	if !owner.as_node().is_html_style_element() { return none }
	rule := sheet.rules.rules[index]
	if can_target_deleted_conditional_style_rule(rule) {
		mut invalidation := &StyleSheetInvalidationSet{}
		extend_deleted_conditional_style_invalidation(mut invalidation, rule)
		return invalidation
	}
	if rule.type_ != .style { return none }
	if children := rule.css_rules() {
		if children.rules.len > 0 { return none }
	}
	mut invalidation := &StyleSheetInvalidationSet{}
	extend_style_sheet_invalidation_set_with_style_rule(mut invalidation, rule)
	if deleted_style_rule_invalidation_diagnostics {
		eprintln('Vox deleted style rule: ${rule.selector_text()}')
	}
	return invalidation
}

fn invalidate_owners_for_deleted_style_rule(mut sheet CSSStyleSheet, invalidation &StyleSheetInvalidationSet, previous_sheet_effects ?ShadowRootStylesheetEffects) bool {
	sheet.did_match = none
	sheet.invalidate_shared_style_cache()
	if document := sheet.owning_document() {
		// An independently changed media condition can affect other rules too.
		if sheet.evaluate_media_queries(document) {
			sheet.invalidate_owners_with_previous_effects(.style_sheet_delete_rule, previous_sheet_effects)
			return false
		}
	}
	for owner in sheet.owning_documents_or_shadow_roots {
		mut scope := css_style_scope_for_node(owner)
		scope.invalidate_rule_cache()
		invalidate_root_for_style_sheet_change(owner, invalidation, .style_sheet_delete_rule, false)
	}
	return !invalidation.invalidation_set.needs_invalidate_whole_subtree()
}

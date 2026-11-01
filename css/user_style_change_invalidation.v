module css

import dom
import os

const disable_targeted_user_style_changes = os.getenv('VOX_DISABLE_TARGETED_USER_STYLE_CHANGES') != ''
const targeted_user_style_change_diagnostics = os.getenv('VOX_TARGETED_USER_STYLE_CHANGE_DIAGNOSTICS') != ''

struct TargetedUserStyleChange {
	sheet        &CSSStyleSheet
	invalidation &StyleSheetInvalidationSet
	subject_filter ?&StaticUserStyleFilter
}

// Replacing plain user rules can change subjects from either sheet, including
// subjects that no longer match any replacement rule. Global registrations,
// nested rules and unbounded selector plans retain the document-wide path.
fn prepare_targeted_user_style_change(document &dom.Document, mut scope StyleScope, source string) ?TargetedUserStyleChange {
	if disable_targeted_user_style_changes || document.needs_full_style_update() { return none }
	scope.build_user_style_sheet_if_needed()
	mut sheets := []&CSSStyleSheet{}
	if previous := scope.user_style_sheet { sheets << previous }
	replacement := parse_css_stylesheet_with_parser(source, none)
	sheets << replacement
	mut invalidation := &StyleSheetInvalidationSet{}
	for sheet in sheets {
		for rule in sheet.rules.rules {
			if rule.type_ != .style { return none }
			if children := rule.css_rules() {
				if children.rules.len > 0 { return none }
			}
			extend_style_sheet_invalidation_set_with_style_rule(mut invalidation, rule)
			if invalidation.invalidation_set.needs_invalidate_whole_subtree() { return none }
		}
	}
	if targeted_user_style_change_diagnostics {
		eprintln('Vox user style change: selected old/new selector invalidation')
	}
	return TargetedUserStyleChange{sheet: replacement, invalidation: invalidation,
		subject_filter: build_static_user_style_filter(document, sheets)}
}

fn invalidate_user_style_change_tree(root &dom.Node, invalidation &StyleSheetInvalidationSet, subject_filter ?&StaticUserStyleFilter) {
	if filter := subject_filter {
		invalidate_static_user_style_subjects(root, filter)
	} else {
		invalidate_root_for_style_sheet_change(root, invalidation, .style_sheet_replace, false)
	}
	invalidate_user_style_change_shadow_roots(root, invalidation)
}

fn invalidate_user_style_change_shadow_roots(node &dom.Node, invalidation &StyleSheetInvalidationSet) {
	if element := node.as_element() {
		if shadow := element.shadow_root() {
			// Shadow inheritance is maintained at a separate style boundary.
			// Preserve the old full pass there even when its host is the only
			// light-DOM subject. This also refreshes assigned-node inheritance.
			shadow_node := unsafe { &dom.Node(shadow) }
			invalidate_root_for_style_sheet_change(shadow_node, invalidation, .style_sheet_replace, true)
			invalidate_user_style_change_shadow_roots(shadow_node, invalidation)
		}
	}
	for child in node.children {
		invalidate_user_style_change_shadow_roots(child, invalidation)
	}
}

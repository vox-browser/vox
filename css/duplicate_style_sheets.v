module css

import dom
import os

// Pages can link the same style sheet several times: github.com repeats its
// 300 KB primer-react-css <link> in each server-rendered React partial. Every
// copy still gets its own CSSStyleSheet and CSSOM rules, but indexing each
// copy's rules multiplied the candidates every element tests and the
// invalidation sets every DOM change consults.
//
// Within one cascade origin and scope, a declaration of an earlier copy loses
// to the identical declaration of the latest copy, which has the same
// specificity, layer and importance and comes later; dropping the earlier
// copy changes no winner. So the rule caches index one copy, at the sheet
// index of the latest copy. Copies qualify only when they were converted from
// the same cached source bytes at the same location and media, CSSOM has not
// changed them, and their meaning cannot depend on the copy: no @import (each
// copy loads its own), no @scope (an implicit root is the owner's parent) and
// no anonymous @layer (each copy is its own layer, and important
// declarations prefer earlier layers). Keyframes are still registered from
// every copy in order.

// Same-binary control: index every copy of identical author style sheets.
const index_duplicate_style_sheets = os.getenv('VOX_INDEX_DUPLICATE_STYLE_SHEETS') != ''
const duplicate_style_sheet_diagnostics = os.getenv('VOX_DUPLICATE_STYLE_SHEET_DIAGNOSTICS') != ''

// The indexed rules shared by identical copies, and their current sheet index.
@[heap]
struct DuplicateSheetGroup {
mut:
	rules []&MatchingRule
	index uint
}

fn duplicate_rules_are_copy_independent(rules &CSSRuleList) bool {
	for rule in rules.rules {
		if rule.type_ in [.import_rule, .scope] { return false }
		if rule.type_ == .layer_block && rule.layer_block_name() == '' { return false }
		if children := rule.css_rules() {
			if !duplicate_rules_are_copy_independent(children) { return false }
		}
	}
	return true
}

// The key shared by identical, interchangeable copies, or none.
fn (sheet &CSSStyleSheet) duplicate_identity() ?string {
	if index_duplicate_style_sheets || sheet.source_syntax_id_ == 0 || sheet.content_mutated_
		|| sheet.constructed || sheet.owner_rule != none || sheet.rules == unsafe { nil }
		|| sheet.base.media == unsafe { nil } {
		return none
	}
	if sheet.duplicate_contents_ == 0 {
		mut mutable_sheet := unsafe { &CSSStyleSheet(sheet) }
		mutable_sheet.duplicate_contents_ = if duplicate_rules_are_copy_independent(sheet.rules) { 1 } else { 2 }
	}
	if sheet.duplicate_contents_ != 1 { return none }
	return '${sheet.source_syntax_id_}\x00${sheet.base.location or { '' }}\x00${sheet.base.media.media_text()}'
}

// Identities of `sheets` (empty when a sheet does not qualify) and, for each
// identity, the position of its last copy among them.
fn duplicate_sheet_identities(cascade_origin CascadeOrigin, sheets []&CSSStyleSheet) ([]string, map[string]int) {
	mut identities := []string{len: sheets.len}
	mut last := map[string]int{}
	if cascade_origin != .author || index_duplicate_style_sheets { return identities, last }
	for position, sheet in sheets {
		identity := sheet.duplicate_identity() or { continue }
		identities[position] = identity
		last[identity] = position
	}
	return identities, last
}

fn report_duplicate_style_sheet(sheet &CSSStyleSheet, action string, index uint) {
	if duplicate_style_sheet_diagnostics {
		eprintln('VOX_DUPLICATE_STYLE_SHEET ${action} location=${sheet.base.location or { '-' }} rules=${sheet.rules.length()} index=${index}')
	}
}

// CSSOM changed the sheet's rules or declarations, so it no longer equals the
// source its syntax id names. Its disabled state and media list are not
// contents: the identity compares the media text itself.
fn note_style_sheet_content_mutation(sheet &CSSStyleSheet, reason dom.StyleInvalidationReason) {
	if reason in [.style_sheet_disabled_state_change, .media_list_set_media_text,
		.media_list_append_medium, .media_list_delete_medium] {
		return
	}
	mut mutable_sheet := unsafe { &CSSStyleSheet(sheet) }
	mutable_sheet.content_mutated_ = true
}

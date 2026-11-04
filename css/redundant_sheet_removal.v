module css

import dom
import os

const retain_redundant_sheet_removal = os.getenv('VOX_RETAIN_REDUNDANT_SHEET_REMOVAL') != ''
const redundant_sheet_removal_diagnostics = os.getenv('VOX_REDUNDANT_SHEET_REMOVAL_DIAGNOSTICS') != ''

// Only leaf rules with a positive, never-seen tag can be ignored. A removed
// element leaves its tag in the document history, so false positives merely
// retain invalidation. Nested rules and non-selector effects stay significant.
fn redundant_sheet_rule_cannot_match(rule &CSSRule, document &dom.Document) bool {
	if rule.type_ != .style || rule.selectors.is_empty() { return false }
	if children := rule.rules {
		if children.rules.len != 0 { return false }
	}
	for selector in rule.selectors.selectors {
		compounds := selector.compound_selectors()
		if compounds.len == 0 { return false }
		mut absent := false
		for simple in compounds[compounds.len - 1].simple_selectors {
			if simple.type_ == .tag_name
				&& !document.has_seen_element_local_name(simple.qualified_name().name.lowercase_name) {
				absent = true
				break
			}
		}
		if !absent { return false }
	}
	return true
}

fn redundant_sheet_declarations_equal(left &CSSRule, right &CSSRule) bool {
	a := left.declaration or { return right.declaration == none }
	b := right.declaration or { return false }
	// Materialize deferred declarations in their normal document allocation scope.
	if a.length() != b.length() || a.properties.len != b.properties.len
		|| a.custom_properties.len != b.custom_properties.len { return false }
	for i, property in a.properties {
		// CSSOM can serialize independent longhands as a shorthand whose
		// expansion order differs, e.g. column-gap/row-gap becomes gap.
		// Match unique longhands by name, retaining the relative order of
		// logical/physical aliases that can compete for the same used edge.
		for previous in a.properties[..i] {
			if previous.name == property.name { return false }
		}
		id := property_id_from_string(property.name) or { return false }
		if property_is_shorthand(id) { return false }
		mut index := -1
		for j, candidate in b.properties {
			if candidate.name == property.name {
				if index != -1 { return false }
				index = j
			}
		}
		if index == -1 { return false }
		other := b.properties[index]
		if property.value != other.value
			|| property.important != other.important
			|| style_value_option_changed(property.style_value, other.style_value) { return false }
		if group := logical_property_group_for_property(id) {
			for previous in a.properties[..i] {
				previous_id := property_id_from_string(previous.name) or { return false }
				previous_group := logical_property_group_for_property(previous_id) or { continue }
				if previous_group != group
					|| (!property_is_logical_alias(id) && !property_is_logical_alias(previous_id)) {
					continue
				}
				for j, candidate in b.properties {
					if candidate.name == previous.name && j >= index { return false }
				}
			}
		}
	}
	for name, property in a.custom_properties {
		other := b.custom_properties[name] or { return false }
		if property.important != other.important
			|| style_value_option_changed(property.value, other.value) { return false }
	}
	return true
}

fn redundant_sheet_rules_equal(left []&CSSRule, right []&CSSRule, document &dom.Document) bool {
	mut changed := []&CSSRule{}
	return redundant_sheet_rule_sequences_match(left, right, document, mut changed) && changed.len == 0
}

fn redundant_sheet_rule_sequences_match(left []&CSSRule, right []&CSSRule, document &dom.Document, mut changed []&CSSRule) bool {
	return redundant_sheet_rule_sequences_match_with_media(left, right, document, mut changed, false)
}

fn redundant_sheet_rule_sequences_match_with_media(left []&CSSRule, right []&CSSRule, document &dom.Document, mut changed []&CSSRule, fresh_media bool) bool {
	mut i := 0
	mut j := 0
	for {
		for i < left.len && redundant_sheet_rule_cannot_match(left[i], document) { i++ }
		for j < right.len && redundant_sheet_rule_cannot_match(right[j], document) { j++ }
		if i == left.len || j == right.len { return i == left.len && j == right.len }
		a := left[i]
		b := right[j]
		if a.type_ != b.type_ || a.type_ !in [.style, .media, .supports] { return false }
		if a.type_ == .style {
			if serialize_a_group_of_selectors(a.selectors) != serialize_a_group_of_selectors(b.selectors) { return false }
			if !redundant_sheet_declarations_equal(a, b) { changed << a }
		} else {
			if a.type_ == .media {
				media := a.media or { return false }
				other := b.media or { return false }
				if fresh_media {
					if b.did_evaluate || !following_media_query_texts_equal(media, other)
						|| a.condition_matches() != following_media_snapshot_matches(other, document) {
						return false
					}
				} else if media.media != other.media || a.condition_matches() != b.condition_matches() {
					return false
				}
			} else {
				if a.condition_matches() != b.condition_matches() { return false }
				supports := a.supports or { return false }
				other := b.supports or { return false }
				// Supports is evaluated once at parse time. Its cached parser
				// graph need not have identical storage; its condition text and
				// static result must agree. CSSOM changes still invalidate owners.
				if supports.to_string() != other.to_string() { return false }
			}
		}
		if children := a.rules {
			other := b.rules or { return false }
			if !redundant_sheet_rule_sequences_match_with_media(children.rules, other.rules, document, mut changed, fresh_media) { return false }
		} else if children := b.rules {
			if children.rules.len != 0 { return false }
		}
		i++
		j++
	}
	return false
}

fn (list &StyleSheetList) removal_has_equivalent_following_sheet(sheet &CSSStyleSheet) bool {
	changed := list.removal_following_sheet_changes(sheet) or { return false }
	return changed.len == 0
}

fn (list &StyleSheetList) removal_following_sheet_changes(sheet &CSSStyleSheet) ?[]&CSSRule {
	if retain_redundant_sheet_removal || !list.document_or_shadow_root.is_document()
		|| sheet.constructed || sheet.base.disabled || sheet.rules.rules.len == 0
		|| sheet.owning_documents_or_shadow_roots.len != 1 { return none }
	owner := sheet.base.owner_node or { return none }
	if !owner.as_node().is_html_style_element() { return none }
	mut index := -1
	for i, candidate in list.sheets {
		if voidptr(candidate) == voidptr(sheet) { index = i; break }
	}
	if index < 0 || index + 1 >= list.sheets.len { return none }
	following := list.sheets[index + 1]
	following_owner := following.base.owner_node or { return none }
	if following.constructed || following.base.disabled
		|| !following_owner.as_node().is_html_style_element()
		|| sheet.base.location != following.base.location || sheet.base_url != following.base_url { return none }
	fresh_media := !retain_unevaluated_following_sheet && sheet.did_match != none
		&& following.did_match == none
	if fresh_media {
		previous := sheet.did_match or { return none }
		if sheet.base.title != following.base.title || sheet.base.alternate != following.base.alternate
			|| !following_media_query_texts_equal(sheet.base.media, following.base.media)
			|| sheet.base.media.matches() != previous
			|| following_media_snapshot_matches(following.base.media, list.document()) != previous { return none }
	} else if sheet.base.media.media != following.base.media.media
		|| sheet.did_match != following.did_match { return none }
	mut changed := []&CSSRule{}
	if !redundant_sheet_rule_sequences_match_with_media(sheet.rules.rules, following.rules.rules, list.document(), mut changed, fresh_media) {
		return none
	}
	if fresh_media { report_fresh_following_sheet_media(list.document()) }
	return changed
}

fn (list &StyleSheetList) removal_invalidation_from_following_sheet(sheet &CSSStyleSheet) ?StyleSheetInvalidationSet {
	changed := list.removal_following_sheet_changes(sheet) or { return none }
	mut result := StyleSheetInvalidationSet{}
	for rule in changed { extend_style_sheet_invalidation_set_with_style_rule(mut result, rule) }
	if redundant_sheet_removal_diagnostics {
		eprintln('Vox stylesheet removal: adjacent following sheet, ${changed.len} changed declaration rules')
	}
	return result
}

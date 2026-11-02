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
		other := b.properties[i]
		if property.name != other.name || property.value != other.value
			|| property.important != other.important
			|| style_value_option_changed(property.style_value, other.style_value) { return false }
	}
	for name, property in a.custom_properties {
		other := b.custom_properties[name] or { return false }
		if property.important != other.important
			|| style_value_option_changed(property.value, other.value) { return false }
	}
	return true
}

fn redundant_sheet_rules_equal(left []&CSSRule, right []&CSSRule, document &dom.Document) bool {
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
			if serialize_a_group_of_selectors(a.selectors) != serialize_a_group_of_selectors(b.selectors)
				|| !redundant_sheet_declarations_equal(a, b) { return false }
		} else {
			if a.condition_matches() != b.condition_matches() { return false }
			if a.type_ == .media {
				media := a.media or { return false }
				other := b.media or { return false }
				if media.media != other.media { return false }
			} else {
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
			if !redundant_sheet_rules_equal(children.rules, other.rules, document) { return false }
		} else if children := b.rules {
			if children.rules.len != 0 { return false }
		}
		i++
		j++
	}
	return false
}

fn (list &StyleSheetList) removal_has_equivalent_following_sheet(sheet &CSSStyleSheet) bool {
	if retain_redundant_sheet_removal || !list.document_or_shadow_root.is_document()
		|| sheet.constructed || sheet.base.disabled || sheet.rules.rules.len == 0
		|| sheet.owning_documents_or_shadow_roots.len != 1 { return false }
	owner := sheet.base.owner_node or { return false }
	if !owner.as_node().is_html_style_element() { return false }
	mut index := -1
	for i, candidate in list.sheets {
		if voidptr(candidate) == voidptr(sheet) { index = i; break }
	}
	if index < 0 || index + 1 >= list.sheets.len { return false }
	following := list.sheets[index + 1]
	following_owner := following.base.owner_node or { return false }
	if following.constructed || following.base.disabled
		|| !following_owner.as_node().is_html_style_element()
		|| sheet.base.location != following.base.location || sheet.base_url != following.base_url
		|| sheet.base.media.media != following.base.media.media
		|| sheet.did_match != following.did_match { return false }
	if !redundant_sheet_rules_equal(sheet.rules.rules, following.rules.rules, list.document()) {
		return false
	}
	if redundant_sheet_removal_diagnostics {
		eprintln('Vox stylesheet removal: retained styles covered by the adjacent following sheet')
	}
	return true
}

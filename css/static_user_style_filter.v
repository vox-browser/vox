module css

import dom
import os

const disable_static_user_style_filter = os.getenv('VOX_DISABLE_STATIC_USER_STYLE_FILTER') != ''
const static_user_style_filter_diagnostics = os.getenv('VOX_STATIC_USER_STYLE_FILTER_DIAGNOSTICS') != ''

struct StaticUserStyleFilter {
	cache    &RuleCache
	fallback &StyleSheetInvalidationSet
}

// Static predicates in the rightmost compound are necessary conditions even
// when the rest of the selector contains dynamic pseudos or combinators. Keep
// every predicate together: the coarse invalidation set unions them with OR,
// which makes e.g. [class^="ad-"] dirty almost every element with a class.
fn static_user_style_subject(selector Selector) ?Selector {
	if selector.is_slotted() || selector.has_part_pseudo_element() { return none }
	compounds := selector.compound_selectors()
	if compounds.len == 0 { return none }
	mut required := []SimpleSelector{}
	for simple in compounds[compounds.len - 1].simple_selectors {
		if simple.type_ in [.id, .class, .tag_name, .attribute] { required << simple }
	}
	if required.len == 0 { return none }
	return selector_from_compound_selectors([CompoundSelector{
		combinator: .no_combinator
		simple_selectors: required
	}])
}

fn build_static_user_style_filter(document &dom.Document, sheets []&CSSStyleSheet) ?&StaticUserStyleFilter {
	if disable_static_user_style_filter { return none }
	mut cache := RuleCache.new()
	cache.fold_id_and_class_name_case = document.in_quirks_mode()
	mut fallback := &StyleSheetInvalidationSet{}
	mut projected := 0
	for sheet in sheets {
		for rule in sheet.rules.rules {
			mut mutable_rule := unsafe { &CSSRule(rule) }
			for selector in mutable_rule.absolutized_selectors().selectors {
				if subject := static_user_style_subject(selector) {
					cache.add_rule(&MatchingRule{selector: subject}, none, false)
					projected++
				} else {
					// Preserve anchor, pseudo-only and dynamic-only invalidation.
					mut single := CSSRule.create(.style)
					single.parent_style_sheet = rule.parent_style_sheet
					single.cached_absolutized_selectors = SelectorList{selectors: [selector]}
					extend_style_sheet_invalidation_set_with_style_rule(mut fallback, single)
					if fallback.invalidation_set.needs_invalidate_whole_subtree() { return none }
				}
			}
		}
	}
	if projected == 0 { return none }
	return &StaticUserStyleFilter{cache: cache, fallback: fallback}
}

struct StaticUserStyleFilterCounts {
mut:
	marked int
	rejected int
	already_dirty int
}

fn static_user_style_subject_matches(element &dom.Element, cache &RuleCache) bool {
	mut buckets := rule_bucket_iterator(cache, dom.AbstractElement.new(element, none))
	for {
		bucket := buckets.next() or { return false }
		for rule in bucket {
			mut context := MatchContext{}
			if matches(rule.selector, element, none, mut context, none, none, .normal, none) { return true }
		}
	}
	return false
}

fn invalidate_static_user_style_subtree(node &dom.Node, cache &RuleCache, mut counts StaticUserStyleFilterCounts) {
	if element := node.as_element() {
		if element.needs_style_update() {
			counts.already_dirty++
		} else if static_user_style_subject_matches(element, cache) {
			mark_style_sheet_invalidation_element(element)
			counts.marked++
		} else {
			counts.rejected++
		}
	}
	for child in node.children { invalidate_static_user_style_subtree(child, cache, mut counts) }
}

fn invalidate_static_user_style_subjects(root &dom.Node, filter &StaticUserStyleFilter) {
	invalidate_root_for_style_sheet_change(root, filter.fallback, .style_sheet_replace, false)
	mut counts := StaticUserStyleFilterCounts{}
	invalidate_static_user_style_subtree(root, filter.cache, mut counts)
	if static_user_style_filter_diagnostics {
		eprintln('Vox static user style filter: marked=${counts.marked} rejected=${counts.rejected} already_dirty=${counts.already_dirty}')
	}
}

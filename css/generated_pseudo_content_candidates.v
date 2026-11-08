module css

import dom
import os

const disable_generated_pseudo_content_candidates = os.getenv('VOX_DISABLE_GENERATED_PSEUDO_CONTENT_CANDIDATES') != ''
const generated_pseudo_content_diagnostics = os.getenv('VOX_GENERATED_PSEUDO_CONTENT_DIAGNOSTICS') != ''

__global generated_pseudo_content_candidates_reported bool
__global generated_pseudo_content_attempts u64
__global generated_pseudo_content_published u64
__global generated_pseudo_content_skips u64

fn declaration_name_may_set_content(name string) bool {
	return equals_ignoring_ascii_case(name, 'content') || equals_ignoring_ascii_case(name, 'all')
}

// Read declaration names without forcing lazy value parsing. Invalid content
// values stay conservative candidates; custom properties are not content.
fn declaration_may_set_content_without_parsing(declaration &CSSStyleProperties) bool {
	if deferred := declaration.deferred_declarations_ {
		for source in deferred.source_declarations {
			if declaration_name_may_set_content(source.name) { return true }
		}
		for source in deferred.declarations {
			if declaration_name_may_set_content(source.name) { return true }
		}
		return false
	}
	if declaration.typed_properties_cache_ != none { return declaration.typed_may_set_content_ }
	for property in declaration.properties {
		if declaration_name_may_set_content(property.name) { return true }
	}
	return false
}

fn (cache &RuleCache) has_generated_content_candidate(element dom.AbstractElement,
	pseudo PseudoElement, computer &StyleComputer) bool {
	selected := pseudo_subject_rule_cache_for_type(cache, pseudo) or { return false }
	mut buckets := rule_bucket_iterator(selected, element)
	for {
		bucket := buckets.next() or { break }
		for candidate in bucket {
			recorded := if target := candidate.pseudo_element { target == pseudo } else { false }
			if !recorded && !style_scope_selector_targets_pseudo_element(candidate.selector, pseudo) {
				continue
			}
			// Use the same rejection as the ordinary matcher, preserving its
			// involvement metadata rules for potentially matching selectors.
			if candidate.selector.can_use_ancestor_filter()
				&& computer.should_reject_with_ancestor_filter(candidate.selector) {
				continue
			}
			rule := candidate.rule or { return true }
			declaration := rule.declaration or { return true }
			if declaration_may_set_content_without_parsing(declaration) { return true }
		}
	}
	return false
}

fn (caches &RuleCaches) has_generated_content_candidate(element dom.AbstractElement,
	pseudo PseudoElement, computer &StyleComputer) bool {
	if caches.main == unsafe { nil }
		|| caches.main.has_generated_content_candidate(element, pseudo, computer) {
		return true
	}
	for _, cache in caches.by_layer {
		if cache.has_generated_content_candidate(element, pseudo, computer) { return true }
	}
	return false
}

// Host/slot/part scopes retain their complete matching paths. The caller still
// clears an old pseudo style and invalidates layout when creation returns none.
// Ordinary computed-style queries
// do not use this proof; only before/after creation can return early here.
fn (scope &StyleScope) generated_pseudo_has_no_content_candidates(element dom.AbstractElement,
	computer &StyleComputer) bool {
	if disable_generated_pseudo_content_candidates { return false }
	pseudo := style_scope_pseudo_element_from_abstract_element(element) or { return false }
	if pseudo !in [.before, .after] { return false }
	if generated_pseudo_content_diagnostics {
		generated_pseudo_content_attempts++
		if element.computed_properties() != none { generated_pseudo_content_published++ }
	}
	node := element.element().as_node()
	if !element.element().is_html_element() || node.root().is_shadow_root()
		|| element.element().shadow_root() != none || node.assigned_slot_internal() != none {
		return false
	}
	for caches in [scope.author_rule_cache, scope.user_rule_cache, scope.user_agent_rule_cache]! {
		if current := caches {
			if current.has_generated_content_candidate(element, pseudo, computer) { return false }
		}
	}
	if generated_pseudo_content_diagnostics && !generated_pseudo_content_candidates_reported {
		generated_pseudo_content_candidates_reported = true
		eprintln('Vox generated pseudo: skipped matching without content candidates')
	}
	if generated_pseudo_content_diagnostics { generated_pseudo_content_skips++ }
	return true
}

pub fn report_generated_pseudo_content_diagnostics() {
	if generated_pseudo_content_diagnostics {
		eprintln('Vox generated pseudo: attempts=${generated_pseudo_content_attempts} published=${generated_pseudo_content_published} skipped=${generated_pseudo_content_skips}')
	}
}

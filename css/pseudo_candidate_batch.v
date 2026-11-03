module css

import dom
import os

const retain_separate_pseudo_queries = os.getenv('VOX_RETAIN_SEPARATE_PSEUDO_QUERIES') != ''
const pseudo_candidate_batch_diagnostics = os.getenv('VOX_BATCHED_PSEUDO_CANDIDATE_DIAGNOSTICS') != ''

__global pseudo_candidate_batch_reported_document dom.UniqueNodeID

fn pseudo_candidate_bit(pseudo PseudoElement) u32 {
	index := int(pseudo)
	return if index >= 0 && index < 32 { u32(1) << u32(index) } else { u32(0) }
}

fn pseudo_candidate_bucket_mask(rules []&MatchingRule) u32 {
	mut mask := u32(0)
	for rule in rules {
		if pseudo := rule.pseudo_element { mask |= pseudo_candidate_bit(pseudo) }
	}
	return mask
}

fn (cache &RuleCache) originating_element_pseudo_candidates(element &dom.Element) u32 {
	mut mask := u32(0)
	// These buckets depend on the originating element, independently of which
	// pseudo is queried. Borrow their vectors once for the complete union.
	mut buckets := rule_bucket_iterator(cache, dom.AbstractElement.new(element, none))
	for {
		bucket := buckets.next() or { break }
		mask |= pseudo_candidate_bucket_mask(bucket)
	}
	// A query for ::before also visits its dedicated ::before bucket. A hint
	// stored under another key does not admit this query, even in hand-built
	// caches. Preserve the direct predicate's exact bucket semantics.
	for pseudo, rules in cache.rules_by_pseudo_element {
		bit := pseudo_candidate_bit(pseudo)
		if is_known_pseudo_element_type(pseudo) && bit != 0 && mask & bit == 0
			&& rule_cache_bucket_has_pseudo_element(rules, pseudo) {
			mask |= bit
		}
	}
	return mask
}

fn (caches &RuleCaches) originating_element_pseudo_candidates(element &dom.Element) u32 {
	mut mask := caches.main.originating_element_pseudo_candidates(element)
	for _, cache in caches.by_layer { mask |= cache.originating_element_pseudo_candidates(element) }
	return mask
}

fn (scope &StyleScope) originating_element_pseudo_candidates(element &dom.Element) u32 {
	scope.build_rule_cache_if_needed()
	mut mask := u32(0)
	for origin in [scope.author_rule_cache, scope.user_rule_cache, scope.user_agent_rule_cache]! {
		if caches := origin { mask |= caches.originating_element_pseudo_candidates(element) }
	}
	return mask
}

struct PseudoCandidateBatch {
mut:
	mask  u32
	valid bool
}

// This batch belongs to one recompute_style_with_invalidation call. Only
// consecutive rejected pseudo queries share its scalar mask. A positive query
// expires it before any cascade/font discovery can run cooperative callbacks;
// the next query observes the live scopes and attributes again.
fn (mut batch PseudoCandidateBatch) has_candidate(scope &StyleScope,
	element dom.AbstractElement, pseudo PseudoElement) bool {
	bit := pseudo_candidate_bit(pseudo)
	if retain_separate_pseudo_queries || bit == 0 {
		return scope.has_candidate_rule_for_pseudo_element(element, pseudo)
	}
	reused := batch.valid
	if !batch.valid {
		batch.mask = scope.originating_element_pseudo_candidates(element.element())
		batch.valid = true
	}
	result := batch.mask & bit != 0
	if result { batch.valid = false }
	if reused && pseudo_candidate_batch_diagnostics {
		document := element.element().document()
		identity := document.as_node().unique_id()
		if pseudo_candidate_batch_reported_document != identity {
			pseudo_candidate_batch_reported_document = identity
			eprintln('Vox pseudo candidates: reused per-element candidate union; document=${document.url.serialize()}')
		}
	}
	return result
}

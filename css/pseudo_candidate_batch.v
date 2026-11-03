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

struct PseudoCandidateMask {
mut:
	bits u32
}

fn (cache &RuleCache) has_direct_pseudo_candidate(pseudo PseudoElement) bool {
	if !is_known_pseudo_element_type(pseudo) { return false }
	if rules := cache.rules_by_pseudo_element[pseudo] {
		return rule_cache_bucket_has_pseudo_element(rules, pseudo)
	}
	return false
}

fn (cache &RuleCache) find_pseudo_candidate_and_common_mask(element &dom.Element,
	pseudo PseudoElement, mut mask PseudoCandidateMask) bool {
	// A universal ::before/::after rule can admit the first query immediately.
	// Avoid constructing a complete union on this positive path.
	if cache.has_direct_pseudo_candidate(pseudo) { return true }
	mut buckets := rule_bucket_iterator(cache, dom.AbstractElement.new(element, none))
	for {
		bucket := buckets.next() or { break }
		for rule in bucket {
			if target := rule.pseudo_element {
				if target == pseudo { return true }
				mask.bits |= pseudo_candidate_bit(target)
			}
		}
	}
	return false
}

fn (caches &RuleCaches) find_pseudo_candidate_and_common_mask(element &dom.Element,
	pseudo PseudoElement, mut mask PseudoCandidateMask) bool {
	if caches.main.find_pseudo_candidate_and_common_mask(element, pseudo, mut mask) { return true }
	for _, cache in caches.by_layer {
		if cache.find_pseudo_candidate_and_common_mask(element, pseudo, mut mask) { return true }
	}
	return false
}

fn (scope &StyleScope) find_pseudo_candidate_and_common_mask(element &dom.Element,
	pseudo PseudoElement, mut mask PseudoCandidateMask) bool {
	scope.build_rule_cache_if_needed()
	for origin in [scope.author_rule_cache, scope.user_rule_cache, scope.user_agent_rule_cache]! {
		if caches := origin {
			if caches.find_pseudo_candidate_and_common_mask(element, pseudo, mut mask) {
				return true
			}
		}
	}
	return false
}

fn (caches &RuleCaches) has_direct_pseudo_candidate(pseudo PseudoElement) bool {
	if caches.main.has_direct_pseudo_candidate(pseudo) { return true }
	for _, cache in caches.by_layer {
		if cache.has_direct_pseudo_candidate(pseudo) { return true }
	}
	return false
}

fn (scope &StyleScope) has_direct_pseudo_candidate(pseudo PseudoElement) bool {
	scope.build_rule_cache_if_needed()
	for origin in [scope.author_rule_cache, scope.user_rule_cache, scope.user_agent_rule_cache]! {
		if caches := origin {
			if caches.has_direct_pseudo_candidate(pseudo) { return true }
		}
	}
	return false
}

struct PseudoCandidateBatch {
mut:
	mask  PseudoCandidateMask
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
		batch.valid = false
		return scope.has_candidate_rule_for_pseudo_element(element, pseudo)
	}
	reused := batch.valid
	mut result := false
	if !batch.valid {
		batch.mask.bits = 0
		result = scope.find_pseudo_candidate_and_common_mask(element.element(), pseudo, mut batch.mask)
		// Only a complete rejection proves that every originating-element bucket
		// was visited. A positive query can leave a partial mask and expires it.
		batch.valid = !result
	} else {
		// Dedicated pseudo buckets were not part of the common rejection scan.
		result = batch.mask.bits & bit != 0 || scope.has_direct_pseudo_candidate(pseudo)
		if result { batch.valid = false }
	}
	if reused && pseudo_candidate_batch_diagnostics {
		document := element.element().document()
		identity := document.as_node().unique_id()
		if pseudo_candidate_batch_reported_document != identity {
			pseudo_candidate_batch_reported_document = identity
			eprintln('Vox pseudo candidates: reused completed rejection scan; document=${document.url.serialize()}')
		}
	}
	return result
}

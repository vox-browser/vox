module css

import dom
import os

const disable_batched_pseudo_candidates = os.getenv('VOX_DISABLE_BATCHED_PSEUDO_CANDIDATES') != ''
const batched_pseudo_candidates_diagnostics = os.getenv('VOX_BATCHED_PSEUDO_CANDIDATES_DIAGNOSTICS') != ''

__global batched_pseudo_candidates_reported bool

// Local to one element's recomputation. Never retain candidate results across
// DOM, rule-hint, stylesheet, or layer mutations.
struct PseudoElementCandidates {
mut:
	bits  u64
	cache &StyleCache = unsafe { nil }
}

fn pseudo_candidate_bit(pseudo PseudoElement) u64 {
	index := int(pseudo)
	return if is_known_pseudo_element_type(pseudo) && index >= 0 && index < 64 {
		u64(1) << u32(index)
	} else {
		u64(0)
	}
}

fn (candidates &PseudoElementCandidates) contains(pseudo PseudoElement) bool {
	bit := pseudo_candidate_bit(pseudo)
	// Future pseudo types outside the bitmap conservatively run the cascade.
	return bit == 0 || candidates.bits & bit != 0
}

fn (mut candidates PseudoElementCandidates) include_bucket(bucket []&MatchingRule) {
	for rule in bucket {
		if pseudo := rule.pseudo_element { candidates.bits |= pseudo_candidate_bit(pseudo) }
	}
}

fn (cache &RuleCache) collect_pseudo_candidates(element &dom.Element,
	mut candidates PseudoElementCandidates) {
	// These buckets are shared by every queried pseudo of the originating
	// element. The pseudo-specific bucket is handled separately below.
	abstract := dom.AbstractElement.new(element, none)
	mut iterator := rule_bucket_iterator(cache, abstract)
	for {
		bucket := iterator.next() or { break }
		candidates.include_bucket(bucket)
	}
	for pseudo in [PseudoElement.before, .after, .selection, .first_letter, .backdrop, .marker]! {
		if bucket := cache.rules_by_pseudo_element[pseudo] {
			// A mutable rule hint can disagree with its bucket key. Preserve the
			// single-query predicate rather than admitting another pseudo here.
			if rule_cache_bucket_has_pseudo_element(bucket, pseudo) {
				candidates.bits |= pseudo_candidate_bit(pseudo)
			}
		}
	}
}

fn (caches &RuleCaches) collect_pseudo_candidates(element &dom.Element,
	mut candidates PseudoElementCandidates) {
	caches.main.collect_pseudo_candidates(element, mut candidates)
	for _, cache in caches.by_layer { cache.collect_pseudo_candidates(element, mut candidates) }
}

fn (scope &StyleScope) pseudo_element_candidates(element &dom.Element) PseudoElementCandidates {
	scope.build_rule_cache_if_needed()
	mut candidates := PseudoElementCandidates{
		cache: scope.rule_cache or { unsafe { nil } }
	}
	for caches in [scope.author_rule_cache, scope.user_rule_cache, scope.user_agent_rule_cache]! {
		if value := caches { value.collect_pseudo_candidates(element, mut candidates) }
	}
	if batched_pseudo_candidates_diagnostics && !batched_pseudo_candidates_reported {
		batched_pseudo_candidates_reported = true
		eprintln('Vox pseudo candidates: batched originating-element buckets')
	}
	return candidates
}

fn (candidates &PseudoElementCandidates) is_current(scope &StyleScope) bool {
	cache := scope.rule_cache or { return false }
	if voidptr(cache) != voidptr(candidates.cache) || !scope.has_valid_rule_cache() { return false }
	if scope.adopted_user_agent_only_shadow_cache_ != unsafe { nil } {
		if !scope.adopted_user_agent_only_shadow_cache_.environment_matches(scope) { return false }
	}
	return true
}

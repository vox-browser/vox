module css

import dom

// Matching candidates are transient: only matching_rules leaves the collector.
// Keep reusable storage per nested call, so synchronous style queries cannot
// overwrite the candidates of a collector which is already matching a rule.
const max_matching_rule_candidate_buffers = 8
const max_retained_matching_rule_candidates = 8192

// Scope roots and proximity are resolved only after a selector matches. Keep
// only the inputs to that work in the transient candidate list.
struct MatchingRuleCandidate {
	rule        &MatchingRule = unsafe { nil }
	shadow_root ?&dom.ShadowRoot
}

@[heap]
struct MatchingRuleCandidateBuffer {
mut:
	rules []MatchingRuleCandidate
	depth int
	context MatchContext = MatchContext{has_result_cache: unsafe { nil }}
}

@[heap]
struct MatchingRuleCandidateScratch {
mut:
	buffers      []&MatchingRuleCandidateBuffer
	active_depth int
}

fn (computer &StyleComputer) acquire_matching_rule_candidates() &MatchingRuleCandidateBuffer {
	mut owner := unsafe { &StyleComputer(computer) }
	if owner.matching_rule_candidates_ == unsafe { nil } {
		owner.matching_rule_candidates_ = &MatchingRuleCandidateScratch{}
	}
	mut scratch := owner.matching_rule_candidates_
	depth := scratch.active_depth
	scratch.active_depth++
	if depth >= max_matching_rule_candidate_buffers {
		return &MatchingRuleCandidateBuffer{
			depth: depth
		}
	}
	if depth == scratch.buffers.len {
		scratch.buffers << &MatchingRuleCandidateBuffer{
			depth: depth
		}
	}
	return scratch.buffers[depth]
}

fn (computer &StyleComputer) release_matching_rule_candidates(mut buffer MatchingRuleCandidateBuffer,
	rules []MatchingRuleCandidate) {
	mut scratch := computer.matching_rule_candidates_
	assert scratch.active_depth == buffer.depth + 1
	scratch.active_depth--
	buffer.rules = unsafe { rules }
	buffer.context = MatchContext{has_result_cache: unsafe { nil }}
	// Clear the live prefix as well as its length. The collector must not retain
	// rules or shadow scopes from a sheet which is later removed from the page.
	unsafe { buffer.rules.reset() }
	buffer.rules.clear()
	if buffer.depth >= max_matching_rule_candidate_buffers
		|| buffer.rules.cap > max_retained_matching_rule_candidates {
		buffer.rules = []MatchingRuleCandidate{}
	}
}

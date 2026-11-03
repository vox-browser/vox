module css

import dom
import os
import platform

const disable_lazy_repeated_rule_memo = os.getenv('VOX_DISABLE_LAZY_REPEATED_RULE_MEMO') != ''

const repeated_rule_match_diagnostics = os.getenv('VOX_RULE_SELECTOR_MATCH_DIAGNOSTICS') != ''

__global repeated_rule_match_reported bool

struct RepeatedRuleMatch {
	sheet ?&CSSStyleSheet
	matched bool
	attempts PseudoClassBitmap
}

// Keep the optional map header in this call's stack record. Passing the
// optional map itself as mut requires a separate header allocation in V.
struct RepeatedRuleMatchMemo {
mut:
	entries ?map[u64]RepeatedRuleMatch
}

fn repeated_rule_sheets_are_identical(left ?&CSSStyleSheet, right ?&CSSStyleSheet) bool {
	if a := left {
		if b := right { return voidptr(a) == voidptr(b) }
		return false
	}
	return right == none
}

// This memo lives for one ordinary, unscoped matching operation on one subject
// and pseudo-element. Every matching rule still enters the ordered cascade.
// Repeated attempts retain their pseudo-class metadata; the first match already
// published the same element/ancestor involvement flags in this operation.
fn match_repeated_rule_selector(selector Selector, element &dom.Element,
	pseudo ?PseudoElement, mut context MatchContext, mut memo RepeatedRuleMatchMemo,
	storage &platform.Arena) bool {
	if selector.data_ == unsafe { nil } || !selector.data_.repeated_rule_parse {
		return matches(selector, element, none, mut context, pseudo, none, .normal, none)
	}
	key := u64(voidptr(selector.data_))
	if mut entries := memo.entries {
		if previous := entries[key] {
			if repeated_rule_sheets_are_identical(previous.sheet, context.style_sheet_for_rule) {
				context.attempted_pseudo_class_matches.merge(previous.attempts)
				if repeated_rule_match_diagnostics && !repeated_rule_match_reported {
					repeated_rule_match_reported = true
					eprintln('Vox rule selectors: reused repeated rule match with metadata')
				}
				return previous.matched
			}
		}
	}
	result := matches(selector, element, none, mut context, pseudo, none, .normal, none)
	if storage == unsafe { nil } {
		if memo.entries == none { memo.entries = map[u64]RepeatedRuleMatch{} }
		if mut entries := memo.entries {
			entries[key] = RepeatedRuleMatch{context.style_sheet_for_rule, result, context.attempted_pseudo_class_matches}
			// The optional unwrap borrows the map buffers but copies its header.
			// Publish len/capacity changes without cloning or resetting that view.
			unsafe { memo.entries = entries }
		}
	} else {
		mut arena := unsafe { &platform.Arena(storage) }
		entry := arena.enter()
		if memo.entries == none { memo.entries = map[u64]RepeatedRuleMatch{} }
		if mut entries := memo.entries {
			entries[key] = RepeatedRuleMatch{context.style_sheet_for_rule, result, context.attempted_pseudo_class_matches}
			// The optional unwrap borrows the map buffers but copies its header.
			// Publish len/capacity changes without cloning or resetting that view.
			unsafe { memo.entries = entries }
		}
		arena.leave(entry)
	}
	return result
}

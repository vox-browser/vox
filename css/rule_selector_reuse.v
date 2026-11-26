module css

import os
import dom
import platform

const disable_rule_selector_reuse = os.getenv('VOX_DISABLE_RULE_SELECTOR_REUSE') != ''
const rule_selector_reuse_diagnostics = os.getenv('VOX_RULE_SELECTOR_REUSE_DIAGNOSTICS') != ''
const maximum_reused_rule_selectors = 4096
const maximum_reused_rule_selector_bytes = 524288

__global rule_selector_reuse_reported bool
__global document_rule_selector_reuse_reported bool

const disable_document_rule_selector_reuse = os.getenv('VOX_DISABLE_DOCUMENT_RULE_SELECTOR_REUSE') != ''
const maximum_document_rule_selectors = 32768
const maximum_document_rule_selector_bytes = 4194304

@[heap]
struct DocumentRuleSelectorMemo {
mut:
	selectors map[string]RuleSelectorMemoEntry
	bytes     int
}

// One selector text has a validated graph per selector mode and per browser
// selector policy. Keying the memo by the text alone avoids building a
// combined key for every lookup; an absent graph has a nil handle.
struct RuleSelectorMemoEntry {
mut:
	selectors [4]Selector
}

fn (parser RuleSelectorParser) rule_selector_memo_slot(mode ParserSelectorType) int {
	mut slot := int(mode) * 2
	if parser.uses_chromium_selector_policy() { slot++ }
	return slot
}

fn memoized_rule_selector(memo map[string]RuleSelectorMemoEntry, text string, slot int) ?Selector {
	entry := memo[text] or { return none }
	selector := entry.selectors[slot]
	if selector.data_ == unsafe { nil } { return none }
	return selector
}

// Records a graph and returns the bytes a new text adds to the memo.
fn memoize_rule_selector(mut memo map[string]RuleSelectorMemoEntry, text string, slot int, selector Selector) int {
	mut entry := memo[text] or { RuleSelectorMemoEntry{} }
	added := if entry.selectors[0].data_ == unsafe { nil } && entry.selectors[1].data_ == unsafe { nil }
		&& entry.selectors[2].data_ == unsafe { nil } && entry.selectors[3].data_ == unsafe { nil } {
		text.len
	} else {
		0
	}
	entry.selectors[slot] = selector
	memo[text] = entry
	return added
}

// A document's stylesheet parsers publish into the same retained owner. Share
// validated, owner-free selector graphs there; ordinary/parser-only callers
// retain the original local memo and its lifetime.
fn (mut parser RuleSelectorParser) document_rule_selector_memo() &DocumentRuleSelectorMemo {
	if disable_document_rule_selector_reuse || !platform.is_main_thread()
		|| parser.document == unsafe { nil } {
		return unsafe { nil }
	}
	storage := parser.document.native_storage()
	if storage == unsafe { nil }
		|| voidptr(platform.current_retained_arena()) != voidptr(storage) {
		return unsafe { nil }
	}
	mut document := unsafe { &dom.Document(parser.document) }
	if document.rule_selector_memo_handle_ == unsafe { nil } {
		mut retained := platform.enter_retained_allocations()
		document.rule_selector_memo_handle_ = voidptr(&DocumentRuleSelectorMemo{})
		retained.finish()
	}
	return unsafe { &DocumentRuleSelectorMemo(document.rule_selector_memo_handle_) }
}

fn reused_rule_selector(selector Selector) Selector {
	mut data := unsafe { &SelectorData(selector.data_) }
	if !data.repeated_rule_parse { data.repeated_rule_parse = true }
	if rule_selector_reuse_diagnostics && !rule_selector_reuse_reported {
		rule_selector_reuse_reported = true
		eprintln('Vox rule selectors: reused validated selector graph')
	}
	return selector
}

fn reused_document_rule_selector(selector Selector) Selector {
	if rule_selector_reuse_diagnostics && !document_rule_selector_reuse_reported {
		document_rule_selector_reuse_reported = true
		eprintln('Vox rule selectors: reused document-owned selector graph')
	}
	return reused_rule_selector(selector)
}

// A parser's validated selector graphs have no rule owner. Each rule keeps its
// own selector vector, declarations and CSSOM identity. Namespace-bearing
// contexts stay on the ordinary path, and relative and standalone validation
// never share an entry. The bounded memo belongs to this parser, not a process
// cache. Native document parsers can additionally share their document memo.
fn (mut parser RuleSelectorParser) parse_memoized_rule_selector(text string, mode ParserSelectorType) ?Selector {
	if disable_rule_selector_reuse || parser.declared_namespaces.len > 0 {
		return parser.parse_supported_rule_selector(text, mode)
	}
	mut shared := parser.document_rule_selector_memo()
	slot := parser.rule_selector_memo_slot(mode)
	// Lookups allocate nothing; only a new graph and its memo entry belong to
	// the document's retained storage.
	if shared != unsafe { nil } {
		if selector := memoized_rule_selector(shared.selectors, text, slot) {
			return reused_document_rule_selector(selector)
		}
	}
	if selector := memoized_rule_selector(parser.parsed_rule_selectors, text, slot) {
		return reused_rule_selector(selector)
	}
	mut owner := if shared != unsafe { nil } {
		platform.enter_retained_allocations()
	} else {
		platform.RetainedAllocationScope{}
	}
	defer { owner.finish() }
	selector := parser.parse_supported_rule_selector(text, mode) or { return none }
	if shared != unsafe { nil } && shared.selectors.len < maximum_document_rule_selectors
		&& shared.bytes + text.len <= maximum_document_rule_selector_bytes {
		if existing := memoized_rule_selector(shared.selectors, text, slot) {
			return reused_document_rule_selector(existing)
		}
		shared.bytes += memoize_rule_selector(mut shared.selectors, text, slot, selector)
	} else if parser.parsed_rule_selectors.len < maximum_reused_rule_selectors
		&& parser.parsed_rule_selector_bytes + text.len <= maximum_reused_rule_selector_bytes {
		parser.parsed_rule_selector_bytes += memoize_rule_selector(mut parser.parsed_rule_selectors, text, slot, selector)
	}
	return selector
}

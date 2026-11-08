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
	selectors map[string]Selector
	bytes     int
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
	mut owner := if shared != unsafe { nil } {
		platform.enter_retained_allocations()
	} else {
		platform.RetainedAllocationScope{}
	}
	defer { owner.finish() }
	key := '${int(mode)}\x00${parser.uses_chromium_selector_policy()}\x00${text}'
	if shared != unsafe { nil } {
		if selector := shared.selectors[key] { return reused_document_rule_selector(selector) }
	}
	if selector := parser.parsed_rule_selectors[key] { return reused_rule_selector(selector) }
	selector := parser.parse_supported_rule_selector(text, mode) or { return none }
	if shared != unsafe { nil } && shared.selectors.len < maximum_document_rule_selectors
		&& shared.bytes + key.len <= maximum_document_rule_selector_bytes {
		if existing := shared.selectors[key] { return reused_document_rule_selector(existing) }
		shared.selectors[key] = selector
		shared.bytes += key.len
	} else if parser.parsed_rule_selectors.len < maximum_reused_rule_selectors
		&& parser.parsed_rule_selector_bytes + key.len <= maximum_reused_rule_selector_bytes {
		parser.parsed_rule_selectors[key] = selector
		parser.parsed_rule_selector_bytes += key.len
	}
	return selector
}

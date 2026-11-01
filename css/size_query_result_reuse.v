module css

import dom
import os
import platform

const disable_size_query_result_reuse = os.getenv('VOX_DISABLE_SIZE_QUERY_RESULT_REUSE') != ''
const size_query_result_diagnostics = os.getenv('VOX_SIZE_QUERY_RESULT_DIAGNOSTICS') != ''

__global size_query_result_reuse_reported bool

struct RecordedSizeQueryMatch {
	rule &CSSRule
	pseudo ?dom.PseudoElement
	matched bool
}

struct RecordedSizeQueryMatches {
mut:
	values []RecordedSizeQueryMatch
	complete bool = true
}

// Retain only queries whose selectors were admitted by the normal matching
// path. A changed boolean requires the full cascade; an unchanged answer does
// not change which declarations participate. Missing/overflowed records keep
// the original conservative invalidation behavior.
fn (mut computer StyleComputer) record_size_query_match(rule &CSSRule,
	element dom.AbstractElement, matched bool) {
	if disable_size_query_result_reuse { return }
	key := u64(element.element().as_node().unique_id().value())
	if key !in computer.size_query_matches_ && computer.size_query_matches_.len >= 4096 { return }
	mut storage := element.document().native_storage()
	mut allocations := platform.RetainedArenaScope{}
	if storage != unsafe { nil } { allocations = storage.enter_nested() }
	defer { allocations.finish() }
	persistent := platform.enter_persistent_if(storage == unsafe { nil })
	defer { platform.leave_persistent(persistent) }
	mut record := computer.size_query_matches_[key] or { RecordedSizeQueryMatches{} }
	if !record.complete { return }
	for previous in record.values {
		if voidptr(previous.rule) == voidptr(rule) && previous.pseudo == element.pseudo_element() {
			// An independent CSSOM computation can observe a new answer before
			// the installed style changes. Keep both answers: it must invalidate.
			if previous.matched == matched { return }
		}
	}
	if record.values.len >= 64 {
		record.complete = false
		record.values = []RecordedSizeQueryMatch{}
	} else {
		record.values << RecordedSizeQueryMatch{rule, element.pseudo_element(), matched}
	}
	computer.size_query_matches_[key] = record
}

fn size_query_results_unchanged(element &dom.Element) bool {
	if disable_size_query_result_reuse || element.style_depends_on_container_relative_units() {
		return false
	}
	bridge := element.document().style_computer()
	if bridge.css_handle == unsafe { nil } { return false }
	computer := unsafe { &StyleComputer(bridge.css_handle) }
	record := computer.size_query_matches_[u64(element.as_node().unique_id().value())] or { return false }
	if !record.complete || record.values.len == 0 { return false }
	for previous in record.values {
		if previous.rule.container_rule_matches_without_recording(dom.AbstractElement.new(element,
			previous.pseudo)) != previous.matched { return false }
	}
	if size_query_result_diagnostics && !size_query_result_reuse_reported {
		size_query_result_reuse_reported = true
		eprintln('Vox size query reuse: unchanged query answers avoided a recascade')
	}
	return true
}

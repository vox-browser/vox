module css

import dom
import os
import platform

const disable_unchanged_has_invalidation = os.getenv('VOX_DISABLE_UNCHANGED_HAS_INVALIDATION') != ''
const unchanged_has_diagnostics = os.getenv('VOX_UNCHANGED_HAS_DIAGNOSTICS') != ''

__global unchanged_has_reported bool

struct ObservedHasArgument {
	selector Selector
	sheet ?&CSSStyleSheet
	selector_text string
	sheet_identity u64
	matched bool
	attempted PseudoClassBitmap
	static_inputs bool
	input_stamp StaticHasInputStamp
}

struct ObservedHasAnchor {
mut:
	arguments []ObservedHasArgument
	complete bool = true
}

// These are observations from real style matching, including failed arguments.
// Keep them across font-only passes. Extra old rules are conservative; missing,
// unsupported or saturated observations always retain ordinary invalidation.
fn record_has_argument_for_invalidation(selector Selector, anchor &dom.Element,
	shadow_host ?&dom.Element, context &MatchContext, scope ?&dom.ParentNode, result bool,
	attempted PseudoClassBitmap) {
	if disable_unchanged_has_invalidation || !context.collect_per_element_selector_involvement_metadata { return }
	bridge := anchor.document().style_computer()
	if bridge.css_handle == unsafe { nil } { return }
	computer := unsafe { &StyleComputer(bridge.css_handle) }
	if voidptr(context.has_result_cache) != voidptr(computer.has_result_cache_) { return }
	mut cache := computer.has_result_cache_
	if cache.rechecking_arguments_ { return }
	key := u64(anchor.as_node().unique_id().value())
	if key !in cache.observed_arguments_ && cache.observed_arguments_.len >= 4096 { return }
	mut supported := shadow_host == none && scope == none && context.rule_shadow_root == none
		&& context.slotted_element == none && context.part_owning_parent == none
		&& !context.for_host_part_matching && !selector.contains_pseudo_class(.visited)
		&& !selector.contains_pseudo_class(.scope)
	mut sheet_identity := u64(0)
	if sheet := context.style_sheet_for_rule {
		sheet_identity = u64(voidptr(sheet))
		supported = supported && sheet.namespace_rules.len == 0
	}
	selector_text := selector.text()
	stamp := static_has_input_stamp(anchor)
	if previous_anchor := cache.observed_arguments_[key] {
		if !previous_anchor.complete { return }
		if supported {
			for previous in previous_anchor.arguments {
				if previous.selector_text == selector_text && previous.sheet_identity == sheet_identity
					&& previous.matched == result && previous.attempted == attempted {
					if !previous.static_inputs || previous.static_inputs_are_unchanged(stamp) { return }
				}
			}
		}
	}
	mut storage := anchor.document().native_storage()
	mut allocations := platform.RetainedArenaScope{}
	if storage != unsafe { nil } { allocations = storage.enter_nested() }
	defer { allocations.finish() }
	persistent := platform.enter_persistent_if(storage == unsafe { nil })
	defer { platform.leave_persistent(persistent) }
	mut observed := cache.observed_arguments_[key] or { ObservedHasAnchor{} }
	if !observed.complete { return }
	if !supported {
		observed.complete = false
		observed.arguments = []ObservedHasArgument{}
		cache.observed_arguments_[key] = observed
		return
	}
	for index, previous in observed.arguments {
		if previous.selector_text == selector_text && previous.sheet_identity == sheet_identity {
			observed.arguments[index] = observed_has_argument(selector, context.style_sheet_for_rule,
				selector_text, sheet_identity, result, attempted, anchor)
			cache.observed_arguments_[key] = observed
			return
		}
	}
	if observed.arguments.len >= 64 {
		observed.complete = false
		observed.arguments = []ObservedHasArgument{}
	} else {
		observed.arguments << observed_has_argument(selector, context.style_sheet_for_rule,
			selector_text, sheet_identity, result, attempted, anchor)
	}
	cache.observed_arguments_[key] = observed
}

fn has_argument_results_unchanged(anchor &dom.Element) bool {
	if disable_unchanged_has_invalidation || !anchor.as_node().root().is_document()
		|| anchor.as_node().assigned_slot_internal() != none || anchor.is_shadow_host() { return false }
	bridge := anchor.document().style_computer()
	if bridge.css_handle == unsafe { nil } { return false }
	computer := unsafe { &StyleComputer(bridge.css_handle) }
	mut cache := computer.has_result_cache_
	key := u64(anchor.as_node().unique_id().value())
	mut observed := cache.observed_arguments_[key] or { return false }
	if !observed.complete || observed.arguments.len == 0 || cache.rechecking_arguments_ { return false }
	cache.rechecking_arguments_ = true
	defer { cache.rechecking_arguments_ = false }
	scratch := platform.begin_thread_scratch('unchanged has argument recheck')
	defer { scratch.finish() }
	stamp := static_has_input_stamp(anchor)
	mut refresh_static_stamps := false
	for previous in observed.arguments {
		if sheet := previous.sheet { if sheet.namespace_rules.len > 0 { return false } }
		if !disable_static_has_input_stamps && previous.static_inputs_are_unchanged(stamp) {
			report_static_has_input_stamp()
			continue
		}
		mut context := MatchContext{
			style_sheet_for_rule: previous.sheet
			subject: anchor
			collect_per_element_selector_involvement_metadata: true
			inside_has_argument_match: true
			has_result_cache: unsafe { nil }
		}
		if matches_relative_selector(previous.selector,0,anchor,none,mut context,anchor,none) != previous.matched
			|| context.attempted_pseudo_class_matches != previous.attempted {
			return false
		}
		if previous.static_inputs { refresh_static_stamps = true }
	}
	if refresh_static_stamps {
		// Only scalar stamps change; selectors, strings and argument vectors
		// keep their existing retained owner. No recheck scratch is published.
		for index, previous in observed.arguments {
			if previous.static_inputs {
				observed.arguments[index] = ObservedHasArgument{ ...previous, input_stamp: stamp }
			}
		}
		mut retained := platform.enter_retained_allocations()
		cache.observed_arguments_[key] = observed
		retained.finish()
	}
	if unchanged_has_diagnostics && !unchanged_has_reported {
		unchanged_has_reported = true
		eprintln('Vox has invalidation: unchanged observed argument results avoided recascade; anchor=${anchor.local_name()} arguments=${observed.arguments.len}')
	}
	return true
}

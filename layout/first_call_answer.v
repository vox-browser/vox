module layout

import css
import os

// First-call answers. A column flex container lays each item out at its
// automatic height to find its flex base size, and then again at its flexed
// height (run_column_flex_formatting_context). The item's committed record is
// the second call's, so the first call of the next pass never matched it: it
// laid the item's whole subtree out, and the second call then restored that
// subtree from the record. Each pass laid out every clean item of the page's
// outer column containers once more.
//
// measurement_subtree_reuse.v keeps the first call's record. When the first
// call of this pass has its inputs and nothing below the item changed, apply
// that record to the item without laying its subtree out. The container then
// lays the answered item out again at its flexed height, even when that equals
// the automatic height: that call restores or rebuilds the descendants, so
// they end with the geometry of the call that ran last, as before.
const disable_first_call_answers = os.getenv('VOX_DISABLE_FIRST_CALL_ANSWERS') != ''

__global first_call_answer_count u64

// First calls answered from a first record in this process (tests and
// diagnostics).
pub fn first_call_answer_statistics() u64 {
	return first_call_answer_count
}

// Called before every committed-pass inner layout of `box`: whether this is
// the call the container named as a candidate (nested calls are not). A later
// call of an answered box lays out or restores its subtree.
fn take_first_call_answer_candidate(mut state LayoutState, box &Node) bool {
	if state.first_call_answered_box_ == voidptr(box) {
		state.first_call_answered_box_ = unsafe { nil }
	}
	if state.first_call_answer_candidate_ != voidptr(box) { return false }
	state.first_call_answer_candidate_ = unsafe { nil }
	return true
}

fn answer_first_call_from_first_record(mut state LayoutState, box &Node, mut box_state UsedValues,
	space AvailableSpace) ?FormattingContextResult {
	previous := state.subtree_reuse_source_
	if disable_first_call_answers || previous == unsafe { nil } || box.needs_layout_update()
		|| box.descendant_needs_layout_update_ {
		return none
	}
	if css.css_style_computer_for(box.document()).font_computer().environment_generation() !=
		previous.committed_pass_.font_generation {
		return none
	}
	styled := box.as_node_with_style() or { return none }
	lookup := committed_values_lookup(previous, styled)
	if lookup.values == unsafe { nil } { return none }
	first := previous.first_relayout_records_[lookup.index] or { return none }
	if voidptr(first.node) != voidptr(box) || first.space != space
		|| !subtree_layout_inputs_match(&first.before, box_state) {
		return none
	}
	if block_contents_need_alignment(box)
		|| subtree_reuse_blocked_with(previous, box, box, !retain_escaping_absolute_blocking) {
		return none
	}
	mut retained := retain_geometry_allocations()
	defer { retained.finish() }
	apply_recorded_inner_layout(mut box_state, &first.before, &first.after)
	// Kept as this pass's first record, so the next pass can answer the call
	// again; the container's second call keeps it (note_repeated_relayout_root).
	state.first_relayout_records_[styled.layout_index()] = RelayoutRecord{
		...first
		serial: state.pass_serial_
	}
	state.first_call_answered_box_ = voidptr(box)
	first_call_answer_count++
	return first.result
}

// Lays `item` out as layout_independent_child() does and reports whether the
// call was answered without laying out the item's subtree. The container must
// then lay the item out again.
fn layout_first_call_of_flex_item(mut state LayoutState, item &Node, mut container_state UsedValues,
	container_width CSSPixels, container_height ?CSSPixels, forced_width ?CSSPixels) (&UsedValues, bool) {
	return layout_first_call_of_flex_item_with_height(mut state, item, mut container_state,
		container_width, container_height, forced_width, none)
}

// A row flex container whose own height is automatic lays each item out at
// its automatic height to size the flex lines, and an item whose descendants
// need its definite height once more at the line's height
// (run_uncached_flex_formatting_context_with_mode). That second call is the
// committed record, as for column items above.
fn layout_first_call_of_flex_item_with_height(mut state LayoutState, item &Node, mut container_state UsedValues,
	container_width CSSPixels, container_height ?CSSPixels, forced_width ?CSSPixels, forced_height ?CSSPixels) (&UsedValues, bool) {
	state.first_call_answer_candidate_ = voidptr(item)
	state.first_call_answered_box_ = unsafe { nil }
	laid_out := layout_independent_child(mut state, item, mut container_state, container_width,
		container_height, forced_width, forced_height)
	answered := state.first_call_answered_box_ == voidptr(item)
	state.first_call_answer_candidate_ = unsafe { nil }
	state.first_call_answered_box_ = unsafe { nil }
	return laid_out, answered
}

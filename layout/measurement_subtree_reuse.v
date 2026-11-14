module layout

import css
import os

// Measurement subtree reuse. A flex or grid container measures an item by
// laying it out in a throwaway state (calculate_content_height_with_constraint
// and its width counterpart). Items of the containers inside that measurement
// are laid out in normal mode, with the inputs their final layout receives. A
// measurement of a box on a changed path therefore laid out every clean
// subtree below it again, although incremental_layout.v restores those
// subtrees in the committed pass itself.
//
// Restore a clean item's committed inner layout in a measurement when the
// measurement hands it the recorded inputs. The measurement reads the result
// and the box's baselines and then discards its state.
//
// An item whose container stretches it is laid out twice in a pass: with an
// automatic height, then with the definite stretched one. The committed record
// is the second call's, while measurements make the first call. Keep that
// first record as well. Its descendants were committed by the second call, so
// it answers a measurement only while the box reports the baselines it had
// after the first call; the committed pass keeps using the last record alone,
// because its descendants must end with the geometry of the call that ran last.
const disable_measurement_subtree_reuse = os.getenv('VOX_DISABLE_MEASUREMENT_SUBTREE_REUSE') != ''

__global layout_pass_serial_counter u64
__global measurement_subtree_reuse_counts [3]u64

fn next_layout_pass_serial() u64 {
	layout_pass_serial_counter++
	return layout_pass_serial_counter
}

// Subtrees restored in measurements from the last and from the first record,
// and first records kept, in this process (tests and diagnostics).
pub fn measurement_subtree_reuse_statistics() (u64, u64, u64) {
	return measurement_subtree_reuse_counts[0], measurement_subtree_reuse_counts[1], measurement_subtree_reuse_counts[2]
}

fn report_measurement_subtree_reuse() {
	if !incremental_layout_diagnostics { return }
	eprintln('VOX_MEASUREMENT_SUBTREE_REUSE last=${measurement_subtree_reuse_counts[0]} first=${measurement_subtree_reuse_counts[1]} first_records=${measurement_subtree_reuse_counts[2]}')
}

// Called before a committed-pass inner layout of `box`. When this pass already
// laid the box out with other inputs, keep that call's record with the
// baselines its descendants still have.
fn note_repeated_relayout_root(mut state LayoutState, box &Node, box_state &UsedValues, space AvailableSpace) {
	if disable_measurement_subtree_reuse || state.relayout_records_.len == 0 { return }
	styled := box.as_node_with_style() or { return }
	index := styled.layout_index()
	existing := state.relayout_records_[index] or { return }
	if voidptr(existing.node) != voidptr(box) || existing.serial != state.pass_serial_ { return }
	if first := state.first_relayout_records_[index] {
		if voidptr(first.node) == voidptr(box) && first.serial == state.pass_serial_ { return }
	}
	if existing.space == space && subtree_layout_inputs_match(&existing.before, box_state) { return }
	baselines := layout_box_baselines(state, box)
	mut retained := retain_geometry_allocations()
	defer { retained.finish() }
	state.first_relayout_records_[index] = RelayoutRecord{
		...existing
		baselines:     baselines
		has_baselines: true
	}
	measurement_subtree_reuse_counts[2]++
}

fn relayout_root_has_first_record_of_this_pass(state &LayoutState, box &Node, index u32) bool {
	if state.first_relayout_records_.len == 0 { return false }
	first := state.first_relayout_records_[index] or { return false }
	return first.serial == state.pass_serial_ && voidptr(first.node) == voidptr(box)
}

// A fresh inner layout replaces whatever an earlier pass recorded first.
fn drop_stale_first_relayout_record(mut state LayoutState, box &Node, index u32) {
	if state.first_relayout_records_.len == 0 { return }
	first := state.first_relayout_records_[index] or { return }
	if first.serial != state.pass_serial_ || voidptr(first.node) != voidptr(box) {
		state.first_relayout_records_.delete(index)
	}
}

// A restored subtree keeps the first record of the pass that committed it.
fn carry_first_relayout_record(mut state LayoutState, previous &LayoutState, node &Node, old_index u32, index u32) {
	if previous.first_relayout_records_.len == 0 { return }
	first := previous.first_relayout_records_[old_index] or { return }
	if voidptr(first.node) != voidptr(node) { return }
	if current := state.first_relayout_records_[index] {
		if voidptr(current.node) == voidptr(node) && current.serial == state.pass_serial_ { return }
	}
	state.first_relayout_records_[index] = RelayoutRecord{
		...first
		serial: state.pass_serial_
	}
}

// reuse_committed_subtree_layout() for a measurement state: the same proof
// of unchanged content and inputs, without publishing records or decisions
// into a state that is about to be discarded.
fn reuse_committed_subtree_layout_in_measurement(mut state LayoutState, box &Node, mut box_state UsedValues,
	space AvailableSpace) ?FormattingContextResult {
	previous := state.measurement_reuse_source_
	if disable_measurement_subtree_reuse || previous == unsafe { nil } || box.needs_layout_update()
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
	committed := lookup.values
	mut record := previous.relayout_records_[lookup.index] or { return none }
	if voidptr(record.node) != voidptr(box) { return none }
	mut from_first := false
	if record.space != space || !subtree_layout_inputs_match(&record.before, box_state) {
		first := previous.first_relayout_records_[lookup.index] or { return none }
		if voidptr(first.node) != voidptr(box) || first.space != space
			|| !subtree_layout_inputs_match(&first.before, box_state) {
			return none
		}
		// The restored descendants carry the last call's geometry, which must
		// report the baselines the box had after its first call.
		if !first.has_baselines || !record.has_baselines || first.baselines != record.baselines {
			return none
		}
		record = first
		from_first = true
	}
	if block_contents_need_alignment(box) || subtree_reuse_blocked(previous, box, box) {
		return none
	}
	apply_recorded_inner_layout(mut box_state, &record.before, &record.after)
	box_state.borrow_retained_line_boxes(committed.line_boxes)
	for child in box.children() {
		restore_committed_layout_node_in_measurement(mut state, previous, child)
	}
	measurement_subtree_reuse_counts[if from_first { 1 } else { 0 }]++
	return record.result
}

// restore_committed_layout_node() without retained allocations: the copies
// share the committed records' rare data and line boxes, which the committed
// state keeps alive and no longer changes, and detach before any write.
fn restore_committed_layout_node_in_measurement(mut state LayoutState, previous &LayoutState, node &Node) {
	if styled := node.as_node_with_style() {
		lookup := committed_values_lookup(previous, styled)
		if lookup.values != unsafe { nil } {
			values := lookup.values
			mut containing := ?&UsedValues(none)
			if parent := committed_geometry_parent(node, values) {
				containing = state.get(parent)
			}
			index := styled.layout_index()
			mut restored := state.used_values_store.get(index) or { state.used_values_store.allocate(index) }
			unsafe {
				*restored = *values
			}
			restored.containing_block_used_values_ = containing
			restored.borrow_retained_line_boxes(values.line_boxes)
			if values.rare_ != none {
				// As in populate_node_from(): both owners detach before a write.
				mut owner := unsafe { &UsedValues(values) }
				owner.rare_is_shared_ = true
				restored.rare_is_shared_ = true
			}
			restored.scrollable_overflow_rect_ = none
			restored.has_scrollable_overflow_ = false
		}
	}
	for child in node.children() {
		restore_committed_layout_node_in_measurement(mut state, previous, child)
	}
}

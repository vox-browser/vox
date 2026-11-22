module layout

import css
import os

// VOX_INLINE_RUN_REPEAT_DIAGNOSTICS=1: count the inline formatting runs that
// build their items, and how many repeat an earlier run of the same
// containing block with the same exact constraint key (used values, mode and
// available space) in the same layout pass, separately for runs inside
// measurement states. Such repeats are what a per-pass inline result cache
// would answer.
const inline_run_repeat_diagnostics = os.getenv('VOX_INLINE_RUN_REPEAT_DIAGNOSTICS') != ''

__global inline_run_repeat_seen map[string]bool
__global inline_run_repeat_seen_in_state map[string]bool
// Runs, repeats, measurement runs, measurement repeats, repeats within the
// same layout state, measurement repeats within the same state.
__global inline_run_repeat_counts [6]u64

__global inline_run_repeat_kinds map[string]u64

fn note_uncached_inline_run(state &LayoutState, containing_block &BlockContainer, used &UsedValues,
	mode LayoutMode, space AvailableSpace, width_only bool) {
	key := exact_inline_layout_key(used, mode, space)
	text := '${state.pass_serial_}:${u64(voidptr(containing_block))}:${key}'
	measurement := state.subtree_root != none
	inline_run_repeat_counts[0]++
	if measurement { inline_run_repeat_counts[2]++ }
	if text in inline_run_repeat_seen {
		inline_run_repeat_counts[1]++
		if measurement { inline_run_repeat_counts[3]++ }
	} else {
		inline_run_repeat_seen[text] = true
	}
	state_text := '${u64(voidptr(state))}:${text}'
	if state_text in inline_run_repeat_seen_in_state {
		blocker := inline_run_blocker(unsafe { &Node(containing_block) }, true)
		detail := if blocker == 'plain' { inline_run_collect_failure(unsafe { &Node(containing_block) }, true) } else { blocker }
		inline_run_repeat_kinds['${if measurement { 'measurement' } else { 'main' }}:${detail}']++
		inline_run_repeat_counts[4]++
		if measurement { inline_run_repeat_counts[5]++ }
	} else {
		inline_run_repeat_seen_in_state[state_text] = true
	}
	if inline_run_repeat_counts[0] % 1000 == 0 {
		c := inline_run_repeat_counts
		eprintln('VOX_INLINE_RUN_REPEATS runs=${c[0]} repeats=${c[1]} measurement_runs=${c[2]} measurement_repeats=${c[3]} same_state_repeats=${c[4]} same_state_measurement_repeats=${c[5]} kinds=${inline_run_repeat_kinds}')
	}
}

// The first content kind below an inline formatting root that retained inline
// snapshots cannot record (collect_retained_inline_inputs), or 'plain'.
fn inline_run_blocker(node &Node, root bool) string {
	if !root {
		if node.is_svg_box() || node.is_svg_svg_box() { return 'svg' }
		if node.is_replaced_box() { return 'replaced' }
		if node.is_floating() { return 'float' }
		if node.is_generated_for_pseudo_element() || node.is_generated_text_node() { return 'generated' }
		if node.is_list_item_marker_box() { return 'marker' }
		if !node.is_text_node() && node.is_break_node() { return 'br' }
		if !node.is_text_node() && !node.is_inline_node() { return 'atomic' }
		if node.is_atomic_inline() { return 'atomic' }
	}
	for child in node.children() {
		reason := inline_run_blocker(child, false)
		if reason != 'plain' { return reason }
	}
	return 'plain'
}

// The first collect_retained_inline_inputs() condition a plain context fails,
// or 'collectable' (then the backoff or the block context kept it uncached).
fn inline_run_collect_failure(node &Node, root bool) string {
	if root {
		if dom_node := node.dom_node() {
			if element := dom_node.as_element() {
				if css.computed_properties_for_pseudo_element(element, .first_line) != none { return 'first-line' }
			}
		}
		if !node.display().is_flow_inside() { return 'root-display:${node.display().to_string()}' }
		if node.computed_values().writing_mode() != .horizontal_tb { return 'writing-mode' }
	}
	computed := node.computed_values()
	if node.is_in_ua_internal_shadow_tree() { return 'ua-shadow' }
	if !retained_layout_position_is_unshifted(node) { return 'shifted' }
	if computed.has_animated_properties() { return 'animated' }
	if computed.mutation_revision() == 0 { return 'revision-zero:${layout_debug_tag(node)}' }
	if metrics := node.as_node_with_style_and_box_model_metrics() {
		if metrics.continuation_of_node() != none { return 'continuation' }
	}
	if value := node.as_text_node() {
		if value.first_letter_ != none { return 'first-letter' }
		if value.source_range_length_ != none { return 'source-range' }
		if value.is_empty_editable_ || value.produces_line_box_fragment_when_empty_ { return 'empty-fragment' }
	}
	for child in node.children() {
		reason := inline_run_collect_failure(child, false)
		if reason != 'collectable' { return reason }
	}
	return 'collectable'
}

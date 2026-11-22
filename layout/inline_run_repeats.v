module layout

import css
import os
import platform
import processmetrics

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
// Calling-thread instructions of the runs of each kind ('first:' for runs
// that repeat nothing in their state, by content), nested runs included in
// their outer run's cost too.
__global inline_run_repeat_costs map[string]u64

// The kind of a run starting now, for note_inline_run_cost().
fn note_uncached_inline_run(state &LayoutState, containing_block &BlockContainer, used &UsedValues,
	mode LayoutMode, space AvailableSpace, width_only bool, context ?&BlockFormattingContext) string {
	// The maps and their keys outlive the layout workspace this runs in.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
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
	mut kind := 'first'
	if inline_context_has_only_discarded_text(containing_block) {
		kind = 'discarded'
	} else if state_text !in inline_run_repeat_seen_in_state {
		blocker := inline_run_blocker(unsafe { &Node(containing_block) }, true)
		kind = 'first:${if measurement { 'measurement' } else { 'main' }}:${blocker}'
		inline_run_repeat_kinds[kind]++
	} else {
		blocker := inline_run_blocker(unsafe { &Node(containing_block) }, true)
		detail := if blocker == 'plain' { inline_run_collect_failure(unsafe { &Node(containing_block) }, true) } else { blocker }
		miss := inline_run_cache_miss(state, containing_block, used, mode, space, width_only, context)
		kind = '${if measurement { 'measurement' } else { 'main' }}:${detail}:${miss}'
		inline_run_repeat_kinds[kind]++
		inline_run_repeat_counts[4]++
		if measurement { inline_run_repeat_counts[5]++ }
	}
	if kind != 'discarded' && state_text !in inline_run_repeat_seen_in_state {
		inline_run_repeat_seen_in_state[state_text] = true
	}
	if inline_run_repeat_counts[0] % 1000 == 0 {
		c := inline_run_repeat_counts
		eprintln('VOX_INLINE_RUN_REPEATS runs=${c[0]} repeats=${c[1]} measurement_runs=${c[2]} measurement_repeats=${c[3]} same_state_repeats=${c[4]} same_state_measurement_repeats=${c[5]} kinds=${inline_run_repeat_kinds} costs=${inline_run_repeat_costs}')
	}
	return kind
}

fn note_inline_run_cost(kind string, start u64) {
	end := processmetrics.thread_instruction_snapshot().instructions
	if end < start { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	inline_run_repeat_costs[kind] += end - start
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

// Why the inline cache of this state did not answer a repeated run: the
// same-pass cache of a committed state (retained_inline_layout.v) or the
// measurement cache of a probe (inline_measurement_layout.v).
fn inline_run_cache_miss(state &LayoutState, containing_block &BlockContainer, used &UsedValues,
	mode LayoutMode, space AvailableSpace, width_only bool, context ?&BlockFormattingContext) string {
	root := unsafe { &Node(containing_block) }
	key := u64(voidptr(root))
	if state.subtree_root != none {
		pool := state.measurement_chunk_pool_
		if pool == unsafe { nil } || pool.closed { return 'no-pool' }
		if !inline_measurement_root_is_closed_with_policy(root, context, true) { return 'not-closed' }
		question := closed_inline_measurement_key(used, mode, space, width_only)
		entries := pool.inline_measurements_[key] or { []&InlineMeasurementLayout{} }
		for entry in entries {
			if entry.key == question {
				return if inline_measurement_inputs_are_current(entry.inputs) { 'entry-current' } else { 'entry-stale' }
			}
		}
		if entries.len >= 4 { return 'evicted' }
		if pool.backoff_ != unsafe { nil } {
			if backoff_key := retained_measurement_backoff_key(root, true) {
				if record := pool.backoff_.entries[backoff_key] {
					if record.skips > 0 { return 'backoff' }
				}
			}
		}
		return if entries.len > 0 { 'other-keys' } else { 'unrecorded' }
	}
	if mode != .normal { return 'mode-${mode}' }
	if width_only { return 'width-only' }
	if !space.width.is_definite() { return 'indefinite' }
	if bfc := context {
		if bfc.floating_boxes.len != 0 { return 'floats' }
		if bfc.has_line_clamp() || bfc.laying_out_invisible_clamped_content { return 'clamp' }
		if !bfc.margin_state.has_block_container_waiting_for_final_y_position()
			&& bfc.margin_state.current_collapsed_margin() != 0 {
			return 'pending-margin'
		}
	}
	if cached := state.inline_layouts_[key] {
		if cached.same_pass_key != exact_inline_layout_key(used, mode, space) { return 'other-key' }
		return if same_pass_inline_inputs_are_current(cached.inputs) { 'entry-current' } else { 'entry-stale' }
	}
	backoff := state.block_layout_backoff_
	if backoff != unsafe { nil } {
		if backoff_key := retained_inline_backoff_key(root) {
			if record := backoff.entries[backoff_key] {
				if record.skips > 0 { return 'backoff' }
			}
		}
	}
	return 'unrecorded'
}

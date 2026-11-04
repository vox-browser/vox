module layout

import css
import dom
import os
import platform

const disable_nested_inline_measurement_reuse = os.getenv('VOX_DISABLE_NESTED_INLINE_MEASUREMENT_REUSE') != ''
const nested_inline_measurement_diagnostics = os.getenv('VOX_NESTED_INLINE_MEASUREMENT_DIAGNOSTICS') != ''

__global nested_inline_measurement_reported bool

@[heap]
struct NestedInlineMeasurement {
	geometry          GridMeasurementKey
	mode              LayoutMode
	width_only        bool
	inputs            []RetainedInlineInput
	values            []RetainedBlockValues
	lines             []LineBox
	inline_end        ?StaticPositionRect
	font_generation   u64
	font_policy       dom.FontRenderingPolicy
	style_environment u64
	result            InlineFormattingResult
}

fn nested_inline_measurement_is_closed(root &Node, context ?&BlockFormattingContext) bool {
	if !inline_layout_workspace_is_closed(root, true) { return false }
	if bfc := context {
		if bfc.floating_boxes.len != 0 || bfc.has_line_clamp()
			|| bfc.laying_out_invisible_clamped_content
			|| (!bfc.margin_state.has_block_container_waiting_for_final_y_position()
				&& bfc.margin_state.current_collapsed_margin() != 0) {
			return false
		}
	}
	return true
}

// Nested inline boxes publish descendant UsedValues as well as the root's
// lines. Retain both in the pass owner, independently of producer scratch.
fn run_nested_inline_measurement(mut state LayoutState, container &BlockContainer,
	mut used UsedValues, mode LayoutMode, space AvailableSpace,
	context ?&BlockFormattingContext, width_only bool) InlineFormattingResult {
	root := unsafe { &Node(container) }
	mut pool := state.measurement_chunk_pool_
	if disable_inline_measurement_reuse || disable_nested_inline_measurement_reuse
		|| state.subtree_root == none || pool == unsafe { nil } || pool.closed
		|| used.containing_block_used_values_ == none
		|| !nested_inline_measurement_is_closed(root, context) {
		return run_uncached_inline_formatting_context_for_width(mut state, container,
			mut used, mode, space, context, width_only)
	}
	// This shared key records resolved outer percentage bases, root constraints
	// and box edges. Inline layout cannot observe an ancestor's intrinsic label
	// independently of those bases; its own mode and question remain separate.
	geometry := grid_measurement_key(state, root, used, space)
	node_key := u64(voidptr(root))
	font_generation := css.css_style_computer_for(root.document()).font_computer().environment_generation()
	style_environment := root.document().style_environment_version()
	previous := pool.nested_inline_measurements_[node_key] or { []&NestedInlineMeasurement{} }
	for cached in previous {
		if cached.geometry != geometry || cached.mode != mode || cached.width_only != width_only
			|| cached.font_generation != font_generation || cached.style_environment != style_environment
			|| cached.font_policy != root.document().font_rendering_policy()
			|| !grid_measurement_inputs_are_current(cached.inputs) {
			continue
		}
		used.borrow_retained_line_boxes(cached.lines)
		if !width_only {
			if position := cached.inline_end { used.set_inline_end_static_position_rect(position) }
		}
		for index in 0 .. cached.values.len {
			entry := unsafe { &cached.values[index] }
			containing := if parent := entry.containing { state.get(parent) } else { none }
			_ = state.restore_retained_values(entry.node, &entry.values, containing)
		}
		if mut bfc := context {
			assert bfc.commit_pending_margin_before_inline_content().raw_value() == 0
		}
		if nested_inline_measurement_diagnostics && !nested_inline_measurement_reported {
			nested_inline_measurement_reported = true
			eprintln('Vox inline measurement: reused nested inline geometry within pass')
		}
		return cached.result
	}
	result := run_uncached_inline_formatting_context_for_width(mut state, container,
		mut used, mode, space, context, width_only)
	if used.line_boxes.len == 0 || !used.line_boxes.any(it.fragments_.len > 0)
		|| font_generation != css.css_style_computer_for(root.document()).font_computer().environment_generation()
		|| style_environment != root.document().style_environment_version() {
		return result
	}
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	mut inputs := []RetainedInlineInput{}
	if !collect_retained_inline_inputs(root, true, mut inputs) { return result }
	mut owned_inputs := []RetainedInlineInput{cap: inputs.len}
	mut snapshots := []RetainedBlockValues{}
	for index, input in inputs {
		if index > 0 {
			containing := input.node.containing_block() or { return result }
			if voidptr(containing) != voidptr(root)
				&& !root.is_inclusive_ancestor_of(unsafe { &Node(containing) }) {
				return result
			}
		}
		owned_inputs << RetainedInlineInput{ ...input, text: input.text.clone() }
		if index == 0 { continue }
		styled := input.node.as_node_with_style() or { continue }
		values := state.try_get(styled) or { continue }
		append_retained_block_snapshot(mut snapshots, styled, values)
		mut snapshot := unsafe { &snapshots[snapshots.len - 1].values }
		snapshot.line_boxes = own_inline_layout_lines(values.line_boxes)
		snapshot.inline_end_static_position_snapshot_ = unsafe { nil }
		snapshot.inline_end_snapshot_arena_ = unsafe { nil }
		if position := values.inline_end_static_position_rect() {
			snapshot.set_inline_end_static_position_rect(position)
		}
	}
	mut entries := pool.nested_inline_measurements_[node_key] or { []&NestedInlineMeasurement{} }
	if entries.len == 4 { entries.delete(0) }
	entries << &NestedInlineMeasurement{
		geometry:          GridMeasurementKey{ ...geometry, external_bases: geometry.external_bases.clone() }
		mode:              mode
		width_only:        width_only
		inputs:            owned_inputs
		values:            snapshots
		lines:             own_inline_layout_lines(used.line_boxes)
		inline_end:        used.inline_end_static_position_rect()
		font_generation:   font_generation
		font_policy:       root.document().font_rendering_policy()
		style_environment: style_environment
		result:            result
	}
	pool.nested_inline_measurements_[node_key] = entries
	return result
}

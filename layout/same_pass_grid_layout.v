module layout

import css
import os
import platform

const disable_same_pass_grid_reuse = os.getenv('VOX_DISABLE_SAME_PASS_GRID_REUSE') != ''
const same_pass_grid_diagnostics = os.getenv('VOX_SAME_PASS_GRID_DIAGNOSTICS') != ''
const same_pass_grid_value_limit = 4096

__global same_pass_grid_reuse_reported bool

// The committed state can revisit a grid before the pass ends. Keep this
// separate from disposable-probe entries, whose eviction and rejection policy
// must not change when the final layout misses.
fn run_grid_formatting_context_internal(mut state LayoutState, container &Node,
	mut used UsedValues, mode LayoutMode, space AvailableSpace, width_only bool) FormattingContextResult {
	mut pool := state.measurement_chunk_pool_
	if disable_same_pass_grid_reuse || state.subtree_root != none
		|| disable_grid_measurement_reuse || disable_committed_grid_measurement_reuse
		|| mode != .normal || width_only || !space.width.is_definite()
		|| pool == unsafe { nil } || pool.closed || used.containing_block_used_values_ == none
		|| !retained_context_allows_grid(container) || container.document().in_quirks_mode()
		|| container.is_viewport() || container.is_root_element() || container.is_body() {
		return run_grid_formatting_context_with_measurement_reuse(mut state, container, mut used,
			mode, space, width_only)
	}
	node_key := u64(voidptr(container))
	if pool.same_pass_grid_rejections_[node_key] {
		return run_grid_formatting_context_with_measurement_reuse(mut state, container, mut used,
			mode, space, width_only)
	}
	key := grid_measurement_key(state, container, used, space)
	font_generation := css.css_style_computer_for(container.document()).font_computer().environment_generation()
	font_policy := container.document().font_rendering_policy()
	style_environment := container.document().style_environment_version()
	if cached := pool.same_pass_grids_[node_key] {
		if cached.key == key && cached.font_generation == font_generation
			&& cached.font_policy == font_policy && cached.style_environment == style_environment
			&& grid_measurement_inputs_are_current(cached.inputs) {
			used.set_grid_template_columns(cached.columns)
			used.set_grid_template_rows(cached.rows)
			used.set_grid_line_names(cached.column_names, cached.row_names)
			used.set_grid_subgridded_axes(false, false)
			for index in 0 .. cached.values.len {
				entry := unsafe { &cached.values[index] }
				containing := if parent := entry.containing { state.get(parent) } else { none }
				_ = state.restore_retained_values(entry.node, &entry.values, containing)
			}
			if same_pass_grid_diagnostics && !same_pass_grid_reuse_reported {
				same_pass_grid_reuse_reported = true
				eprintln('Vox same-pass grid: reused committed grid geometry')
			}
			return cached.result
		}
	}
	mut retained_inputs := platform.enter_retained_allocations()
	mut inputs := []RetainedInlineInput{}
	mut rejected := map[u64]bool{}
	eligible := collect_grid_measurement_inputs(container, mut inputs, mut rejected)
	if !eligible { pool.same_pass_grid_rejections_[node_key] = true }
	previous_count := if old := pool.same_pass_grids_[node_key] { old.values.len } else { 0 }
	can_store := eligible && inputs.len > 1
		&& pool.same_pass_grid_values_ - previous_count + inputs.len - 1 <= same_pass_grid_value_limit
	mut owned_inputs := []RetainedInlineInput{}
	if can_store {
		for input in inputs { owned_inputs << own_image_measurement_input(input) }
	}
	retained_inputs.finish()
	result := run_grid_formatting_context_with_measurement_reuse(mut state, container, mut used,
		mode, space, width_only)
	if !can_store || font_generation != css.css_style_computer_for(container.document()).font_computer().environment_generation()
		|| font_policy != container.document().font_rendering_policy()
		|| style_environment != container.document().style_environment_version()
		|| !grid_measurement_inputs_are_current(owned_inputs) { return result }
	// Nested grids can reserve their own snapshots during the ordinary run.
	if pool.same_pass_grid_values_ - previous_count + owned_inputs.len - 1
		> same_pass_grid_value_limit { return result }
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	mut values := []RetainedBlockValues{cap: owned_inputs.len - 1}
	for input in owned_inputs[1..] {
		styled := input.node.as_node_with_style() or { continue }
		snapshot := state.try_get(styled) or { continue }
		append_owned_measurement_values(mut values, styled, snapshot)
	}
	pool.same_pass_grids_[node_key] = &GridMeasurementLayout{
		key: GridMeasurementKey{ ...key, external_bases: key.external_bases.clone() }
		inputs: owned_inputs
		values: values
		columns: used.grid_template_columns().clone()
		rows: used.grid_template_rows().clone()
		column_names: own_grid_line_names(used.grid_column_line_names())
		row_names: own_grid_line_names(used.grid_row_line_names())
		font_generation: font_generation
		font_policy: font_policy
		style_environment: style_environment
		result: result
	}
	pool.same_pass_grid_values_ += values.len - previous_count
	return result
}

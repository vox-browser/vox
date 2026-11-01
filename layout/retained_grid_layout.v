module layout

import os

const disable_retained_grid_layout = os.getenv('VOX_DISABLE_RETAINED_GRID_LAYOUT') != ''
const retained_grid_layout_diagnostics = os.getenv('VOX_RETAINED_GRID_LAYOUT_DIAGNOSTICS') != ''

__global retained_grid_layout_reported bool

fn retained_context_allows_grid(node &Node) bool {
	if disable_retained_grid_layout || !node.display().is_grid_inside() { return false }
	computed := node.computed_values()
	// Subgrid consumes per-pass track data from its parent formatting context.
	// Ordinary grids retain all their own used tracks in UsedValues instead.
	return !computed.grid_template_columns().is_subgrid()
		&& !computed.grid_template_rows().is_subgrid()
}

fn report_retained_grid_layout(inputs []RetainedInlineInput) {
	if !retained_grid_layout_diagnostics || retained_grid_layout_reported { return }
	for input in inputs {
		if input.node.display().is_grid_inside() {
			retained_grid_layout_reported = true
			eprintln('Vox retained grid layout: reused unchanged independent geometry')
			return
		}
	}
}

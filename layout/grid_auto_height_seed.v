module layout

import os
import platform

const disable_grid_auto_height_seed = os.getenv('VOX_DISABLE_GRID_AUTO_HEIGHT_SEED') == '1'
const grid_auto_height_seed_diagnostics = os.getenv('VOX_GRID_AUTO_HEIGHT_SEED_DIAGNOSTICS') == '1'

__global grid_auto_height_seed_reported bool

// At a fixed inline size, an unconstrained grid with only automatic rows has
// the same automatic block size under indefinite and max-content block space.
// Keep specialized descendants and height-dependent tracks on the full probe.
fn grid_auto_height_seed_is_closed(root &Node) bool {
	if disable_grid_auto_height_seed || !root.display().is_grid_inside()
		|| !flex_grid_has_only_implicit_auto_rows(root) { return false }
	mut scratch := platform.begin_thread_scratch('grid automatic height proof')
	defer { scratch.finish() }
	mut inputs := []RetainedInlineInput{}
	mut rejected := map[u64]bool{}
	if !collect_grid_measurement_inputs(root, mut inputs, mut rejected)
		|| !grid_measurement_external_heights_are_unused(inputs) { return false }
	for input in inputs {
		// Flex intrinsic modes, replaced elements and SVG keep their separate
		// algorithms. This proof admits only ordinary flow and auto-row grids.
		if input.node.display().is_flex_inside() || input.node.is_replaced_box()
			|| input.node.is_svg_box() { return false }
	}
	return true
}

fn report_grid_auto_height_seed() {
	if grid_auto_height_seed_diagnostics && !grid_auto_height_seed_reported {
		grid_auto_height_seed_reported = true
		eprintln('Vox grid automatic height: retained max-content row measurement')
	}
}

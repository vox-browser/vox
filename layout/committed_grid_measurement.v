module layout

import css
import os

const disable_committed_grid_measurement_reuse = os.getenv('VOX_DISABLE_COMMITTED_GRID_MEASUREMENT_REUSE') != ''
const committed_grid_measurement_diagnostics = os.getenv('VOX_COMMITTED_GRID_MEASUREMENT_DIAGNOSTICS') != ''
const disable_unused_measurement_heights = os.getenv('VOX_DISABLE_UNUSED_MEASUREMENT_HEIGHTS') != ''
const unused_measurement_height_diagnostics = os.getenv('VOX_UNUSED_MEASUREMENT_HEIGHT_DIAGNOSTICS') != ''

__global committed_grid_measurement_reported bool
__global unused_measurement_height_reported bool

// A closed subtree with only implicit auto rows and no height-dependent
// descendants cannot read a more distant ancestor's block-size basis. The
// root's dimensions, available space and immediate containing block remain
// exact in the key. Inspect the full captured tree, including below fixed
// heights, so mutation validation also protects this conservative proof.
fn grid_measurement_external_heights_are_unused(inputs []RetainedInlineInput) bool {
	for input in inputs {
		node := input.node
		computed := input.style
		if node.is_absolutely_positioned() || computed.writing_mode() != .horizontal_tb
			|| (node.display().is_grid_inside() && !flex_grid_has_only_implicit_auto_rows(node)) {
			return false
		}
		for property in [css.PropertyID.height, .min_height, .max_height, .top, .bottom] {
			if computed.size_value(property).contains_percentage() { return false }
		}
		if computed.flex_basis().size.contains_percentage()
			|| computed.gap_value(.row_gap).length_percentage.contains_percentage() {
			return false
		}
		if node.is_flex_item() && property_is_auto(computed, .height) {
			if box := node.as_box() {
				if box.has_preferred_aspect_ratio() { return false }
			}
		}
	}
	return true
}

fn committed_grid_measurement_keys_match(a &GridMeasurementKey, b &GridMeasurementKey) bool {
	return grid_measurement_keys_match_with_height_policy(a, b, false)
}

// Only a caller with a current, height-independent closed-subtree proof may
// ignore these numeric values. Definite root sizes and immediate containing
// block definiteness still participate, as do all widths, constraints and edges.
fn grid_measurement_keys_match_with_height_policy(a &GridMeasurementKey, b &GridMeasurementKey,
	unused_heights bool) bool {
	if a.space != b.space || a.width != b.width
		|| ((!unused_heights || a.definite_height) && a.height != b.height)
		|| a.definite_width != b.definite_width || a.definite_height != b.definite_height
		|| a.width_constraint != b.width_constraint || a.height_constraint != b.height_constraint
		|| a.edges != b.edges || a.containing_node != b.containing_node
		|| a.containing_width != b.containing_width
		|| (!unused_heights && a.containing_height != b.containing_height)
		|| a.containing_definite_width != b.containing_definite_width
		|| a.containing_definite_height != b.containing_definite_height
		|| a.external_bases.len != b.external_bases.len {
		return false
	}
	for index in 0 .. a.external_bases.len {
		x := a.external_bases[index]
		y := b.external_bases[index]
		if x.node != y.node || x.present != y.present || x.width != y.width
			|| x.definite_width != y.definite_width { return false }
	}
	return true
}

fn report_unused_measurement_heights() {
	if unused_measurement_height_diagnostics && !unused_measurement_height_reported {
		unused_measurement_height_reported = true
		eprintln('Vox measurement heights: reused closed geometry across unused stored heights')
	}
}

fn report_committed_grid_measurement_reuse() {
	if committed_grid_measurement_diagnostics && !committed_grid_measurement_reported {
		committed_grid_measurement_reported = true
		eprintln('Vox grid measurement: promoted measured grid into committed geometry')
	}
}

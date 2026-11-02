module layout

import os

const retain_definite_intrinsic_measurement = os.getenv('VOX_RETAIN_DEFINITE_INTRINSIC_MEASUREMENT') != ''
const definite_intrinsic_contribution_diagnostics = os.getenv('VOX_DEFINITE_INTRINSIC_CONTRIBUTION_DIAGNOSTICS') != ''

fn definite_preferred_intrinsic_width(node &Node, values &UsedValues, containing_width CSSPixels) ?CSSPixels {
	if retain_definite_intrinsic_measurement { return none }
	preferred := node.computed_values().size_value(.width)
	// Percentages are cyclic here, even when a copied ancestor happens to have
	// definite geometry. Intrinsic keywords still need content measurement.
	if preferred.contains_percentage() { return none }
	return resolve_layout_content_size(node, preferred, containing_width, values, true)
}

fn report_definite_intrinsic_contribution() {
	if definite_intrinsic_contribution_diagnostics {
		eprintln('Vox intrinsic contribution: definite preferred width skips content probe')
	}
}

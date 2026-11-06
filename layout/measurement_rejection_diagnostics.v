module layout

import css
import os

const measurement_rejection_diagnostics = os.getenv('VOX_MEASUREMENT_REJECTION_DIAGNOSTICS') != ''

__global measurement_rejection_reports int

// A bounded, diagnostic-only description of an input which a measurement
// collector actually rejected. Print scalar flags and DOM labels, never an
// owner graph or a sampled style payload. This supplies no performance credit.
fn report_measurement_rejection(node &Node, style &css.ComputedValues, reason string) {
	if !measurement_rejection_diagnostics || measurement_rejection_reports >= 256 { return }
	measurement_rejection_reports++
	mut tag := 'anonymous'
	mut id := ''
	if owner := node.dom_node() {
		tag = owner.node_name()
		if element := owner.as_element() { id = element.get_attribute_value('id') }
	}
	eprintln('Vox measurement rejected: reason=${reason} node=${u64(voidptr(node))} tag=${tag} id=${id} pseudo=${node.is_generated_for_pseudo_element()} generated_text=${node.is_generated_text_node()} ua_shadow=${node.is_in_ua_internal_shadow_tree()} svg=${node.is_svg_box()} replaced=${node.is_replaced_box()} floating=${node.is_floating()} unshifted=${retained_layout_position_is_unshifted(node)} position=${style.position()} animated=${style.has_animated_properties()} opacity_only=${style.has_only_animated_property(.opacity)} custom_animated=${style.has_animated_custom_properties()} contained=${node.has_layout_containment() || node.has_paint_containment()} horizontal=${style.writing_mode() == .horizontal_tb} visible=${style.content_visibility() == .visible} clamped=${line_clamp_is_active(style)} revision=${style.mutation_revision()} flow=${node.display().is_flow_inside()} flex=${node.display().is_flex_inside()} grid=${node.display().is_grid_inside()}')
}

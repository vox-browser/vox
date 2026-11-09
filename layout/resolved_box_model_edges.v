module layout

import css
import os

const retain_property_edge_resolution = os.getenv('VOX_RETAIN_PROPERTY_EDGE_RESOLUTION') != ''
const resolved_box_model_edge_diagnostics = os.getenv('VOX_RESOLVED_BOX_MODEL_EDGE_DIAGNOSTICS') != ''

__global resolved_box_model_edges_reported_document u64

fn resolve_box_model_edges(computed &css.ComputedValues, mut used_values UsedValues, containing_block_width f64) {
	basis := used_values.box_model_percentage_basis() or { CSSPixels.nearest_value_for(containing_block_width) }
	if retain_property_edge_resolution {
		resolve_box_model_edges_by_property(computed, mut used_values, basis.to_double())
		return
	}
	edges := computed.resolved_box_model_edges(basis.to_double())
	used_values.padding_left = edges.padding_left
	used_values.padding_right = edges.padding_right
	used_values.padding_top = edges.padding_top
	used_values.padding_bottom = edges.padding_bottom
	used_values.border_left = edges.border_left
	used_values.border_right = edges.border_right
	used_values.border_top = edges.border_top
	used_values.border_bottom = edges.border_bottom
	used_values.margin_left = edges.margin_left
	used_values.margin_right = edges.margin_right
	used_values.margin_top = edges.margin_top
	used_values.margin_bottom = edges.margin_bottom
	if resolved_box_model_edge_diagnostics && used_values.node_ != unsafe { nil } {
		document := used_values.node_.document()
		identity := document.as_node().unique_id()
		if resolved_box_model_edges_reported_document != identity {
			resolved_box_model_edges_reported_document = identity
			eprintln('Vox box edges: resolved typed snapshot without property round trips; document=${document.url.serialize()}')
		}
	}
}

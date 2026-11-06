module layout

import os

const retain_clamped_inline_allocations = os.getenv('VOX_RETAIN_CLAMPED_INLINE_ALLOCATIONS') != ''
const clamped_inline_workspace_diagnostics = os.getenv('VOX_CLAMPED_INLINE_WORKSPACE_DIAGNOSTICS') != ''

__global clamped_inline_workspace_reported bool

// This is an allocation boundary, not a geometry cache. The complete line
// builder still consumes and updates the live clamp/margin context on every
// call. Only a closed inline tree owned by that context may enter the workspace.
fn clamped_inline_workspace_is_closed(root &Node, context ?&BlockFormattingContext) bool {
	if retain_clamped_inline_allocations { return false }
	bfc := context or { return false }
	owner := bfc.root or { return false }
	if !layout_nodes_same(owner, root) || !bfc.has_line_clamp()
		|| bfc.floating_boxes.len != 0 || bfc.laying_out_invisible_clamped_content {
		return false
	}
	return clamped_inline_tree_has_owned_outputs(root, true)
}

fn clamped_inline_tree_has_owned_outputs(node &Node, root bool) bool {
	if node.is_svg_box() || node.is_replaced_box() || node.is_atomic_inline()
		|| node.is_floating() || !retained_layout_position_is_unshifted(node)
		|| node.is_list_item_box() || node.is_list_item_marker_box() { return false }
	if root {
		// Legacy -webkit-box can use this caller's inline algorithm for its
		// clamped text. The chosen child algorithm, rather than that display
		// label, proves the same closed output boundary here.
		if !node.children_are_inline()
			|| node.computed_values().writing_mode() != .horizontal_tb { return false }
	} else if !node.is_text_node() && !node.is_inline_node() && !node.is_break_node() {
		return false
	}
	if node.is_break_node() && node.computed_values().clear() != .none_ { return false }
	if metrics := node.as_node_with_style_and_box_model_metrics() {
		if metrics.continuation_of_node() != none { return false }
	}
	if text := node.as_text_node() {
		if text.first_letter_ != none || text.source_range_length_ != none
			|| text.is_empty_editable_ || text.produces_line_box_fragment_when_empty_ {
			return false
		}
	}
	for child in node.children() {
		if !clamped_inline_tree_has_owned_outputs(child, false) { return false }
	}
	return true
}

fn report_clamped_inline_workspace() {
	if clamped_inline_workspace_diagnostics && !clamped_inline_workspace_reported {
		clamped_inline_workspace_reported = true
		eprintln('Vox clamped inline workspace: built full clamp layout in temporary storage')
	}
}

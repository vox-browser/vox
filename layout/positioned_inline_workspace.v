module layout

import os

const retain_positioned_inline_allocations = os.getenv('VOX_RETAIN_POSITIONED_INLINE_ALLOCATIONS') != ''
const positioned_inline_workspace_diagnostics = os.getenv('VOX_POSITIONED_INLINE_WORKSPACE_DIAGNOSTICS') != ''

__global positioned_inline_workspace_reported bool

// The inline iterator skips an absolute box's descendants and emits only a
// static-position marker. Its Box remains document-owned; UsedValues publishes
// the resolved static rectangle through its retained rare-data setter.
fn positioned_inline_workspace_is_closed(node &Node, root bool) bool {
	if retain_positioned_inline_allocations || node.is_svg_box() { return false }
	if !root && node.is_absolutely_positioned() && !node.is_fixed_position()
		&& node.as_box() != none { return true }
	if node.is_replaced_box() || node.is_atomic_inline() || node.is_floating()
		|| !retained_layout_position_is_unshifted(node) || node.is_list_item_box()
		|| node.is_list_item_marker_box() { return false }
	if root {
		if !node.display().is_flow_inside()
			|| node.computed_values().writing_mode() != .horizontal_tb
			|| line_clamp_is_active(node.computed_values()) { return false }
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
		if !positioned_inline_workspace_is_closed(child, false) { return false }
	}
	return true
}

fn report_positioned_inline_workspace() {
	if positioned_inline_workspace_diagnostics && !positioned_inline_workspace_reported {
		positioned_inline_workspace_reported = true
		eprintln('Vox positioned inline workspace: owned lines and static positions')
	}
}

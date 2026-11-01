module layout

import os

const disable_relative_flow_layout_reuse = os.getenv('VOX_DISABLE_RELATIVE_FLOW_LAYOUT_REUSE') != ''
const relative_flow_layout_diagnostics = os.getenv('VOX_RELATIVE_FLOW_LAYOUT_DIAGNOSTICS') != ''

__global relative_flow_layout_reported bool

fn retained_layout_position_is_unshifted(node &Node) bool {
	styled := node.as_node_with_style() or { return true }
	computed := styled.computed_values()
	position := computed.position()
	if position == .static_ { return true }
	if disable_relative_flow_layout_reuse || position != .relative { return false }
	// All-auto relative insets leave normal-flow geometry unchanged. Absolute
	// descendants still reject the enclosing cache during recursive collection;
	// explicit insets and sticky offsets retain the normal layout algorithm.
	insets := computed.inset()
	return insets.top().is_auto() && insets.right().is_auto()
		&& insets.bottom().is_auto() && insets.left().is_auto()
}

fn report_relative_flow_layout_reuse(inputs []RetainedInlineInput) {
	if !relative_flow_layout_diagnostics || relative_flow_layout_reported { return }
	for input in inputs {
		if input.node.is_positioned() {
			relative_flow_layout_reported = true
			eprintln('Vox relative flow layout: reused unshifted positioned geometry')
			return
		}
	}
}

module layout

import os

const disable_lazy_internal_line_buffers = os.getenv('VOX_DISABLE_LAZY_INTERNAL_LINE_BUFFERS') != ''

// Internal box-model updates and whole-line disposal do not mutate retained
// fragments. The public mutable accessors keep their eager detachment contract.
fn (mut state LayoutState) mutable_internal_box_values(node &NodeWithStyle) &UsedValues {
	if disable_lazy_internal_line_buffers { return state.get_mutable(node) }
	return state.mutable_box_values(node)
}

fn (state &LayoutState) values_for_line_disposal(node &NodeWithStyle) ?&UsedValues {
	if disable_lazy_internal_line_buffers { return state.try_get_mutable(node) }
	return state.try_get(node)
}

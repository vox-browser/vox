// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

// Literal translation of ReplacedWithChildrenFormattingContext::run(). Media
// controls and other replaced elements with a shadow child delegate the
// anonymous wrapper to a block formatting context while retaining the
// dimensions resolved by their parent context.
fn run_replaced_with_children_formatting_context(mut state LayoutState, context_box &Node, mut root_state UsedValues, available_space AvailableSpace) FormattingContextResult {
	content_width := root_state.content_width()
	natural_size := context_box.as_box() or { return FormattingContextResult{} }.natural_size()
	if natural_size.has_width() {
		root_state.set_has_definite_width(true)
	}
	if natural_size.has_height() {
		root_state.set_has_definite_height(true)
	}
	child_available_height := if root_state.has_definite_height() {
		AvailableSize.make_definite(root_state.content_height())
	} else {
		available_space.height
	}
	child_available_space := AvailableSpace.new(AvailableSize.make_definite(content_width),
		child_available_height)

	mut wrapper := ?&Node(none)
	for child in context_box.children() {
		if child.is_block_container() {
			wrapper = child
			break
		}
	}
	wrapper_node := wrapper or {
		return FormattingContextResult{
			automatic_content_width: content_width
		}
	}

	wrapper_styled := wrapper_node.as_node_with_style() or { return FormattingContextResult{} }
	mut wrapper_state := state.get_mutable(wrapper_styled)
	wrapper_state.set_content_width(content_width)
	wrapper_state.set_content_offset(CSSPixelPoint{})
	wrapper_state.set_containing_block_used_values(root_state)

	result := layout_inside_independent_formatting_context(mut state, wrapper_node, mut
		wrapper_state, child_available_space)
	wrapper_state.set_content_height(result.automatic_content_height)
	return FormattingContextResult{
		automatic_content_width:  content_width
		automatic_content_height: result.automatic_content_height
	}
}

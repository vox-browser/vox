// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

// Literal translation of ReplacedWithChildrenFormattingContext::run(). Media
// controls and other replaced elements with a shadow child delegate the
// anonymous wrapper to a block formatting context while retaining the
// dimensions resolved by their parent context.
fn run_replaced_with_children_formatting_context(mut state LayoutState, context_box &Node, mut root_state UsedValues, _ AvailableSpace) FormattingContextResult {
	content_width := root_state.content_width()
	// The parent formatting context has already resolved the replaced box from
	// its natural, explicit, or default object size. Both axes are therefore
	// definite percentage bases for its shadow children.
	root_state.set_has_definite_width(true)
	root_state.set_has_definite_height(true)
	child_available_space := AvailableSpace.new(AvailableSize.make_definite(content_width),
		AvailableSize.make_definite(root_state.content_height()))

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
	// constraints_for_child_context() gives the anonymous wrapper the replaced
	// root's definite percentage bases even though the wrapper itself is auto
	// sized. UsedValues has no separate constraint record, so retain that basis
	// here while its BFC lays out percentage-sized shadow children.
	wrapper_state.set_content_height(root_state.content_height())
	wrapper_state.set_has_definite_width(true)
	wrapper_state.set_has_definite_height(true)
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

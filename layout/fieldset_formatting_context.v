// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

fn run_fieldset_formatting_context(mut state LayoutState, fieldset &FieldSetBox, mut fieldset_state UsedValues, available_space AvailableSpace) FormattingContextResult {
	legend := fieldset.rendered_legend() or {
		mut ordinary_context := BlockFormattingContext.for_root(unsafe { &Node(fieldset) }, .normal, has_definite_inline_size(unsafe { &Node(fieldset) },fieldset_state))
		height := ordinary_context.layout_block_level_children(mut state, unsafe { &Node(fieldset) }.as_node_with_style() or { return FormattingContextResult{} }, fieldset_state.content_width().to_double(), if available_space.height.is_definite() {
			available_space.height.to_px_or_zero().to_double()
		} else {
			none
		})
		return FormattingContextResult{
			automatic_content_width: fieldset_state.content_width()
			automatic_content_height: css_px(height)
		}
	}
	fieldset_styled := unsafe { &Node(fieldset) }.as_node_with_style() or {
		return FormattingContextResult{}
	}
	legend_styled := unsafe { &Node(legend) }.as_node_with_style() or {
		return FormattingContextResult{}
	}
	mut context := BlockFormattingContext.for_root(unsafe { &Node(fieldset) }, .normal, has_definite_inline_size(unsafe { &Node(fieldset) },fieldset_state))
	context.y_offset_of_current_block_container = 0
	_ = context.layout_block_level_box(mut state, legend_styled, fieldset_styled, fieldset_state.content_width().to_double(), if available_space.height.is_definite() {
		available_space.height.to_px_or_zero().to_double()
	} else {
		none
	})
	mut legend_state := state.get_mutable(legend_styled)
	if property_is_auto(legend.computed_values(), .width) {
		legend_state.set_content_width(calculate_fit_content_width(mut state, unsafe { &Box(legend) }, available_space.width))
	}
	effective_border := css_pixels_max(fieldset_state.border_top, legend_state.margin_box_height())
	extra_top := effective_border.minus(fieldset_state.border_top)
	context.margin_state.reset()
	context.y_offset_of_current_block_container = extra_top.to_double()
	mut bottom := extra_top.to_double()
	for child in fieldset.children() {
		if layout_nodes_same(child, unsafe { &Node(legend) }) {
			continue
		}
		child_styled := child.as_node_with_style() or { continue }
		child_bottom := context.layout_block_level_box(mut state, child_styled, fieldset_styled, fieldset_state.content_width().to_double(), if available_space.height.is_definite() {
			available_space.height.to_px_or_zero().to_double()
		} else {
			none
		})
		if child_bottom > bottom {
			bottom = child_bottom
		}
	}
	legend_centering := effective_border.minus(legend_state.border_box_height()).divided_by_float(2)
	fieldset_border_top_in_content := CSSPixels.new(0).minus(fieldset_state.border_top).minus(fieldset_state.padding_top)
	legend_state.set_content_y(fieldset_border_top_in_content.plus(legend_centering).plus(legend_state.border_box_top()))
	return FormattingContextResult{
		automatic_content_width: fieldset_state.content_width()
		automatic_content_height: css_px(bottom)
	}
}

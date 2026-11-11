module layout

import css

// The legend replaces the block-start border. In vertical writing that is
// a physical side border, and the anonymous content box starts after its
// excess width. Baselines come from that content box, excluding the legend.
fn run_vertical_fieldset_formatting_context(mut state LayoutState, fieldset &FieldSetBox, mut values UsedValues, space AvailableSpace) FormattingContextResult {
	root := unsafe { &Node(fieldset) }
	reverse := grid_axis_reversed(root, true)
	mut legend_extent := CSSPixels.new(0)
	legend := fieldset.rendered_legend()
	if box := legend {
		node := unsafe { &Node(box) }
		styled := node.as_node_with_style() or { return FormattingContextResult{} }
		mut used := state.get_mutable(styled)
		used.set_containing_block_used_values(values)
		resolve_box_model_edges(node.computed_values(), mut used, values.content_height().to_double())
		width := resolve_layout_content_size(node, node.computed_values().size_value(.width), values.content_width(), used, true) or { calculate_max_content_width(mut state, unsafe { &Box(box) }) }
		height := resolve_layout_content_size(node, node.computed_values().size_value(.height), values.content_height(), used, false) or { calculate_fit_content_height(mut state, unsafe { &Box(box) }, width, space.height) }
		used = layout_independent_child(mut state, node, mut values, values.content_width(), if space.height.is_definite() {
			?CSSPixels(space.height.to_px_or_zero())
		} else {
			none
		}, width, height)
		legend_extent = used.margin_box_width()
	}
	border_start := if reverse { values.border_right } else { values.border_left }
	effective_border := css_pixels_max(border_start, legend_extent)
	extra := effective_border.minus(border_start)
	mut natural_width := extra
	mut inline_size := CSSPixels.new(0)
	mut content := []&Node{}
	for child in root.children() {
		if child.is_out_of_flow() { continue }
		if box := legend {
			if layout_nodes_same(child, unsafe { &Node(box) }) { continue }
		}
		styled := child.as_node_with_style() or { continue }
		box := child.as_box() or { continue }
		mut used := state.get_mutable(styled)
		used.set_containing_block_used_values(values)
		resolve_box_model_edges(child.computed_values(), mut used, values.content_height().to_double())
		width := resolve_layout_content_size(child, child.computed_values().size_value(.width), values.content_width(), used, true) or { calculate_max_content_width(mut state, box) }
		height := resolve_layout_content_size(child, child.computed_values().size_value(.height), values.content_height(), used, false) or { calculate_fit_content_height(mut state, box, width, space.height) }
		used = layout_independent_child(mut state, child, mut values, values.content_width(), if space.height.is_definite() {
			?CSSPixels(space.height.to_px_or_zero())
		} else {
			none
		}, width, height)
		natural_width = natural_width.plus(used.margin_box_width())
		inline_size = css_pixels_max(inline_size, used.margin_box_height())
		content << child
	}
	block_size := if space.width.is_definite() && values.has_definite_width() {
		values.content_width()
	} else {
		natural_width
	}
	values.set_content_width(block_size)
	mut cursor := extra
	mut first := ?CSSPixels(none)
	mut last := ?CSSPixels(none)
	for child in content {
		styled := child.as_node_with_style() or { continue }
		mut used := state.get_mutable(styled)
		used.set_content_x(if reverse {
			block_size.minus(cursor).minus(used.margin_box_width()).plus(used.margin_box_left())
		} else {
			cursor.plus(used.margin_box_left())
		})
		used.set_content_y(used.margin_box_top())
		if first == none {
			first = used.offset.x().minus(used.margin_box_left()).plus(grid_baseline_from_low(state, root, child, true, .first, 0))
		}
		last = used.offset.x().minus(used.margin_box_left()).plus(grid_baseline_from_low(state, root, child, true, .last, 0))
		cursor = cursor.plus(used.margin_box_width())
	}
	values.set_derived_vertical_baselines(first, last)
	if box := legend {
		styled := unsafe { &Node(box) }.as_node_with_style() or { return FormattingContextResult{} }
		mut used := state.get_mutable(styled)
		centering := effective_border.minus(used.border_box_width()).divided_by_float(2)
		x := if reverse {
			block_size.plus(values.padding_right).plus(values.border_right).minus(centering).minus(used.border_box_width())
		} else {
			CSSPixels.new(0).minus(values.padding_left).minus(values.border_left).plus(centering)
		}
		used.set_content_x(x.plus(used.border_box_left()))
		used.set_content_y(used.margin_box_top())
	}
	return FormattingContextResult{ automatic_content_width: block_size, automatic_content_height: inline_size }
}

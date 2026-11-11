module layout

import css

// Separate-border vertical tables with unspanned, baseline-aligned cells use
// logical columns in the physical y axis and logical rows in the x axis.
// Other table models retain the general table algorithm.
fn vertical_table_for_wrapper(wrapper &Node) ?&Node {
	if !wrapper.is_table_wrapper() || !grid_is_vertical(wrapper) { return none }
	for table in wrapper.children() {
		if !table.display().is_table_inside() { continue }
		style := table.computed_values()
		if style.border_collapse() != .separate || !style.size_value(.width).is_auto() || !style.size_value(.height).is_auto() {
			return none
		}
		mut rows := []&Node{}
		collect_table_rows_in_layout_order(table, mut rows)
		placements, columns := calculate_table_cell_placements(rows)
		if rows.len == 0 || columns == 0 { return none }
		for placement in placements {
			if placement.column_span != 1 || placement.row_span != 1 || !table_cell_is_baseline_aligned(placement.cell)
				|| placement.cell.computed_values().writing_mode() != style.writing_mode()
				|| !placement.cell.computed_values().size_value(.width).is_auto() || !placement.cell.computed_values().size_value(.height).is_auto() {
				return none
			}
		}
		return table
	}
	return none
}

fn layout_vertical_table_wrapper(mut state LayoutState, wrapper &Node, mut wrapper_values UsedValues) ?FormattingContextResult {
	table := vertical_table_for_wrapper(wrapper) or { return none }
	table_styled := table.as_node_with_style() or { return none }
	mut values := state.get_mutable(table_styled)
	values.set_containing_block_used_values(wrapper_values)
	resolve_box_model_edges(table.computed_values(), mut values, wrapper_values.content_height().to_double())
	mut rows := []&Node{}
	collect_table_rows_in_layout_order(table, mut rows)
	placements, column_count := calculate_table_cell_placements(rows)
	mut columns := []CSSPixels{len: column_count}
	inline_gap := table.computed_values().border_spacing_horizontal().to_px(layout_length_resolution_context(table))
	block_gap := table.computed_values().border_spacing_vertical().to_px(layout_length_resolution_context(table))
	for placement in placements {
		cell := placement.cell
		styled := cell.as_node_with_style() or { return none }
		box := cell.as_box() or { return none }
		mut used := state.get_mutable(styled)
		used.set_containing_block_used_values(values)
		resolve_box_model_edges(cell.computed_values(), mut used, wrapper_values.content_height().to_double())
		intrinsic := calculate_max_content_height(mut state, box, CSSPixels.new(0)).plus(used.border_box_top()).plus(used.border_box_bottom())
		columns[placement.column] = css_pixels_max(columns[placement.column], intrinsic)
	}
	mut inline_size := inline_gap.scaled(f64(column_count + 1))
	for size in columns { inline_size = inline_size.plus(size) }
	values.set_content_height(inline_size)
	values.set_has_definite_height(true)
	mut row_widths := []CSSPixels{len: rows.len}
	mut ascents := []CSSPixels{len: rows.len}
	mut descents := []CSSPixels{len: rows.len}
	reverse := grid_axis_reversed(table, true)
	for placement in placements {
		cell := placement.cell
		styled := cell.as_node_with_style() or { return none }
		box := cell.as_box() or { return none }
		mut used := state.get_mutable(styled)
		used.set_content_height(css_pixels_max(CSSPixels.new(0), columns[placement.column].minus(used.border_box_top()).minus(used.border_box_bottom())))
		used.set_has_definite_height(true)
		used.set_indefinite_content_width()
		width := calculate_max_content_width(mut state, box)
		used = layout_independent_child(mut state, cell, mut values, CSSPixels.new(0), inline_size, width, used.content_height())
		used.margin_left = CSSPixels.new(0)
		used.margin_right = CSSPixels.new(0)
		used.margin_top = CSSPixels.new(0)
		used.margin_bottom = CSSPixels.new(0)
		physical := grid_baseline_from_low(state, table, cell, true, .first, 0)
		ascent := if reverse { used.border_box_width().minus(physical) } else { physical }
		descent := used.border_box_width().minus(ascent)
		ascents[placement.row] = css_pixels_max(ascents[placement.row], ascent)
		descents[placement.row] = css_pixels_max(descents[placement.row], descent)
	}
	mut block_size := block_gap.scaled(f64(rows.len + 1))
	for index in 0 .. rows.len {
		row_widths[index] = ascents[index].plus(descents[index])
		block_size = block_size.plus(row_widths[index])
	}
	values.set_content_width(block_size)
	values.set_has_definite_width(true)
	mut row_starts := []CSSPixels{len: rows.len}
	mut block_cursor := block_gap
	for index, row in rows {
		row_starts[index] = if reverse {
			block_size.minus(block_cursor).minus(row_widths[index])
		} else {
			block_cursor
		}
		styled := row.as_node_with_style() or { return none }
		mut used := state.get_mutable(styled)
		used.set_containing_block_used_values(values)
		used.set_content_offset(css.CSSPixelPoint.new(row_starts[index], CSSPixels.new(0)))
		used.set_content_width(row_widths[index])
		used.set_content_height(inline_size)
		baseline := if reverse { row_widths[index].minus(ascents[index]) } else { ascents[index] }
		used.set_derived_vertical_baselines(baseline, baseline)
		block_cursor = block_cursor.plus(row_widths[index]).plus(block_gap)
	}
	for group in table_row_containers_in_layout_order(table) {
		if group.display().is_table_row() { continue }
		styled := group.as_node_with_style() or { continue }
		mut used := state.get_mutable(styled)
		used.set_containing_block_used_values(values)
		used.set_content_offset(css.CSSPixelPoint.new(CSSPixels.new(0), CSSPixels.new(0)))
		used.set_content_width(block_size)
		used.set_content_height(inline_size)
	}
	mut column_starts := []CSSPixels{len: column_count}
	mut inline_cursor := inline_gap
	for index, size in columns {
		column_starts[index] = if grid_axis_reversed(table, false) {
			inline_size.minus(inline_cursor).minus(size)
		} else {
			inline_cursor
		}
		inline_cursor = inline_cursor.plus(size).plus(inline_gap)
	}
	for placement in placements {
		cell := placement.cell
		styled := cell.as_node_with_style() or { return none }
		mut used := state.get_mutable(styled)
		physical := grid_baseline_from_low(state, table, cell, true, .first, 0)
		ascent := if reverse { used.border_box_width().minus(physical) } else { physical }
		before := ascents[placement.row].minus(ascent)
		after := row_widths[placement.row].minus(used.border_box_width()).minus(before)
		if reverse {
			used.padding_right = used.padding_right.plus(before)
			used.padding_left = used.padding_left.plus(after)
		} else {
			used.padding_left = used.padding_left.plus(before)
			used.padding_right = used.padding_right.plus(after)
		}
		used.set_content_offset(css.CSSPixelPoint.new(row_starts[placement.row].plus(used.border_box_left()), column_starts[placement.column].plus(used.border_box_top())))
	}
	mut before_captions := CSSPixels.new(0)
	mut after_captions := CSSPixels.new(0)
	mut captions := []&Node{}
	for caption in table.children() {
		if !caption.display().is_table_caption() || caption.is_out_of_flow() { continue }
		styled := caption.as_node_with_style() or { return none }
		box := caption.as_box() or { return none }
		mut used := state.get_mutable(styled)
		used.set_containing_block_used_values(wrapper_values)
		resolve_box_model_edges(caption.computed_values(), mut used, inline_size.to_double())
		width := resolve_layout_content_size(caption, caption.computed_values().size_value(.width), block_size, used, true) or { calculate_max_content_width(mut state, box) }
		height := css_pixels_max(CSSPixels.new(0), values.border_box_height().minus(flex_or_grid_item_outer_block_edges(used)))
		used = layout_independent_child(mut state, caption, mut wrapper_values, block_size, inline_size, width, height)
		if caption.computed_values().caption_side() == .top {
			before_captions = before_captions.plus(used.margin_box_width())
		} else {
			after_captions = after_captions.plus(used.margin_box_width())
		}
		captions << caption
	}
	total := before_captions.plus(values.margin_box_width()).plus(after_captions)
	wrapper_values.set_content_width(total)
	wrapper_values.set_content_height(values.margin_box_height())
	values.set_content_x(if reverse {
		total.minus(before_captions).minus(values.margin_box_width()).plus(values.margin_box_left())
	} else {
		before_captions.plus(values.margin_box_left())
	})
	values.set_content_y(values.margin_box_top())
	mut before_cursor := CSSPixels.new(0)
	mut after_cursor := before_captions.plus(values.margin_box_width())
	for caption in captions {
		styled := caption.as_node_with_style() or { continue }
		mut used := state.get_mutable(styled)
		start := if caption.computed_values().caption_side() == .top {
			before_cursor
		} else {
			after_cursor
		}
		used.set_content_x(if reverse {
			total.minus(start).minus(used.margin_box_width()).plus(used.margin_box_left())
		} else {
			start.plus(used.margin_box_left())
		})
		used.set_content_y(used.margin_box_top())
		if caption.computed_values().caption_side() == .top {
			before_cursor = before_cursor.plus(used.margin_box_width())
		} else {
			after_cursor = after_cursor.plus(used.margin_box_width())
		}
	}
	first := row_starts[0].plus(if reverse { row_widths[0].minus(ascents[0]) } else { ascents[0] })
	last_index := rows.len - 1
	last := row_starts[last_index].plus(if reverse {
		row_widths[last_index].minus(ascents[last_index])
	} else {
		ascents[last_index]
	})
	values.set_derived_vertical_baselines(first, last)
	wrapper_values.set_derived_vertical_baselines(values.offset.x().plus(first), values.offset.x().plus(last))
	return FormattingContextResult{ automatic_content_width: total, automatic_content_height: wrapper_values.content_height() }
}

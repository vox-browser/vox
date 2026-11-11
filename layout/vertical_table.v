module layout

import css

// Separate-border vertical tables whose cells span one row and one column use
// logical columns in the physical y axis and logical rows in the x axis. Their
// table and cell sizes may be auto or definite lengths. Other table models
// retain the general table algorithm.
fn vertical_table_for_wrapper(wrapper &Node) ?&Node {
	if !wrapper.is_table_wrapper() || !grid_is_vertical(wrapper) { return none }
	for table in wrapper.children() {
		if !table.display().is_table_inside() { continue }
		style := table.computed_values()
		if style.border_collapse() != .separate || !vertical_table_size_is_supported(style.size_value(.width))
			|| !vertical_table_size_is_supported(style.size_value(.height)) {
			return none
		}
		mut rows := []&Node{}
		collect_table_rows_in_layout_order(table, mut rows)
		placements, _ := calculate_table_cell_placements(rows)
		for placement in placements {
			cell_style := placement.cell.computed_values()
			if placement.column_span != 1 || placement.row_span != 1
				|| cell_style.writing_mode() != style.writing_mode()
				|| !vertical_table_size_is_supported(cell_style.size_value(.width))
				|| !vertical_table_size_is_supported(cell_style.size_value(.height)) {
				return none
			}
		}
		return table
	}
	return none
}

fn vertical_table_size_is_supported(size css.Size) bool {
	return size.is_auto() || size.is_length()
}

// A table's specified size is a minimum for its grid. Columns share the extra
// inline size in proportion to their sizes and rows share the extra block size
// equally, as auto-sized tracks do.
fn distribute_vertical_table_extra_size(mut sizes []CSSPixels, extra CSSPixels, proportional bool) {
	if sizes.len == 0 || extra.raw_value() <= 0 { return }
	mut total := CSSPixels.new(0)
	for size in sizes { total = total.plus(size) }
	for index in 0 .. sizes.len {
		share := if proportional && total.raw_value() > 0 {
			extra.times_float(sizes[index].to_double() / total.to_double())
		} else {
			extra.divided_by(CSSPixels.new(sizes.len)).to_css_pixels()
		}
		sizes[index] = sizes[index].plus(share)
	}
}

// A caption is a block-level box in the vertical wrapper's flow, so its
// physical top and bottom margins are its inline-axis margins: auto values
// share the wrapper's inline size that the caption leaves free, and are
// treated as zero when the caption leaves none.
fn resolve_vertical_table_caption_auto_margins(computed &css.ComputedValues, mut used UsedValues, containing_inline_size CSSPixels) {
	top_auto := property_is_auto(computed, .margin_top)
	bottom_auto := property_is_auto(computed, .margin_bottom)
	if !top_auto && !bottom_auto { return }
	fixed_top := if top_auto { CSSPixels.new(0) } else { used.margin_top }
	fixed_bottom := if bottom_auto { CSSPixels.new(0) } else { used.margin_bottom }
	remaining := containing_inline_size.minus(used.border_box_height()).minus(fixed_top).minus(fixed_bottom)
	if remaining.raw_value() < 0 {
		if top_auto { used.margin_top = CSSPixels.new(0) }
		if bottom_auto { used.margin_bottom = CSSPixels.new(0) }
		return
	}
	if top_auto && bottom_auto {
		half := CSSPixels.from_raw(remaining.raw_value() / 2)
		used.margin_top = half
		used.margin_bottom = remaining.minus(half)
	} else if top_auto {
		used.margin_top = remaining
	} else {
		used.margin_bottom = remaining
	}
}

fn layout_vertical_table_wrapper(mut state LayoutState, wrapper &Node, mut wrapper_values UsedValues) ?FormattingContextResult {
	table := vertical_table_for_wrapper(wrapper) or { return none }
	table_styled := table.as_node_with_style() or { return none }
	table_style := table.computed_values()
	mut values := state.get_mutable(table_styled)
	values.set_containing_block_used_values(wrapper_values)
	resolve_box_model_edges(table_style, mut values, wrapper_values.content_height().to_double())
	mut rows := []&Node{}
	collect_table_rows_in_layout_order(table, mut rows)
	placements, column_count := calculate_table_cell_placements(rows)
	mut columns := []CSSPixels{len: column_count}
	inline_gap := table_style.border_spacing_horizontal().to_px(layout_length_resolution_context(table))
	block_gap := table_style.border_spacing_vertical().to_px(layout_length_resolution_context(table))
	for placement in placements {
		cell := placement.cell
		styled := cell.as_node_with_style() or { return none }
		box := cell.as_box() or { return none }
		mut used := state.get_mutable(styled)
		used.set_containing_block_used_values(values)
		resolve_box_model_edges(cell.computed_values(), mut used, wrapper_values.content_height().to_double())
		mut content_height := calculate_max_content_height(mut state, box, CSSPixels.new(0))
		// A cell's definite physical height is its specified inline size, which
		// is a minimum for its column.
		if specified := resolve_layout_content_size(cell, cell.computed_values().size_value(.height), CSSPixels.new(0), used, false) {
			content_height = css_pixels_max(content_height, specified)
		}
		intrinsic := content_height.plus(used.border_box_top()).plus(used.border_box_bottom())
		columns[placement.column] = css_pixels_max(columns[placement.column], intrinsic)
	}
	// The border spacing is undistributable space only for a grid that has
	// columns (rows).
	mut inline_size := if column_count > 0 { inline_gap.scaled(f64(column_count + 1)) } else { CSSPixels.new(0) }
	for size in columns { inline_size = inline_size.plus(size) }
	if specified := resolve_layout_content_size(table, table_style.size_value(.height), CSSPixels.new(0), values, false) {
		if specified.raw_value() > inline_size.raw_value() {
			distribute_vertical_table_extra_size(mut columns, specified.minus(inline_size), true)
			inline_size = specified
		}
	}
	values.set_content_height(inline_size)
	values.set_has_definite_height(true)
	mut row_widths := []CSSPixels{len: rows.len}
	mut ascents := []CSSPixels{len: rows.len}
	mut descents := []CSSPixels{len: rows.len}
	mut cell_ascents := []CSSPixels{len: placements.len}
	reverse := grid_axis_reversed(table, true)
	for placement_index, placement in placements {
		cell := placement.cell
		styled := cell.as_node_with_style() or { return none }
		box := cell.as_box() or { return none }
		mut used := state.get_mutable(styled)
		used.set_content_height(css_pixels_max(CSSPixels.new(0), columns[placement.column].minus(used.border_box_top()).minus(used.border_box_bottom())))
		used.set_has_definite_height(true)
		used.set_indefinite_content_width()
		mut width := calculate_max_content_width(mut state, box)
		// A cell's definite physical width is its specified block size, which is
		// a minimum for its row.
		if specified := resolve_layout_content_size(cell, cell.computed_values().size_value(.width), CSSPixels.new(0), used, true) {
			width = css_pixels_max(width, specified)
		}
		used = layout_independent_child(mut state, cell, mut values, CSSPixels.new(0), inline_size, width, used.content_height())
		used.margin_left = CSSPixels.new(0)
		used.margin_right = CSSPixels.new(0)
		used.margin_top = CSSPixels.new(0)
		used.margin_bottom = CSSPixels.new(0)
		if table_cell_is_baseline_aligned(cell) {
			physical := grid_baseline_from_low(state, table, cell, true, .first, 0)
			ascent := if reverse { used.border_box_width().minus(physical) } else { physical }
			descent := used.border_box_width().minus(ascent)
			cell_ascents[placement_index] = ascent
			ascents[placement.row] = css_pixels_max(ascents[placement.row], ascent)
			descents[placement.row] = css_pixels_max(descents[placement.row], descent)
		} else {
			row_widths[placement.row] = css_pixels_max(row_widths[placement.row], used.border_box_width())
		}
	}
	mut block_size := if rows.len > 0 { block_gap.scaled(f64(rows.len + 1)) } else { CSSPixels.new(0) }
	for index in 0 .. rows.len {
		row_widths[index] = css_pixels_max(row_widths[index], ascents[index].plus(descents[index]))
		block_size = block_size.plus(row_widths[index])
	}
	if specified := resolve_layout_content_size(table, table_style.size_value(.width), CSSPixels.new(0), values, true) {
		if specified.raw_value() > block_size.raw_value() {
			distribute_vertical_table_extra_size(mut row_widths, specified.minus(block_size), false)
			block_size = specified
		}
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
	for placement_index, placement in placements {
		cell := placement.cell
		styled := cell.as_node_with_style() or { return none }
		mut used := state.get_mutable(styled)
		// The cell is placed in its row's block axis like vertical-align places
		// a horizontal table's cells: baseline cells align their first
		// baselines, the others go to the row's block-start, center or end.
		free := row_widths[placement.row].minus(used.border_box_width())
		before := if table_cell_is_baseline_aligned(cell) {
			ascents[placement.row].minus(cell_ascents[placement_index])
		} else {
			match cell.computed_values().vertical_align() {
				.middle { CSSPixels.from_raw(free.raw_value() / 2) }
				.bottom { free }
				else { CSSPixels.new(0) }
			}
		}
		after := free.minus(before)
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
	// Captions flow in the wrapper's block axis. The wrapper's inline size is
	// the table box's, so it is the basis of the captions' percentage margins
	// and the space their inline-axis auto margins share.
	caption_inline_size := values.border_box_height()
	for caption in table.children() {
		if !caption.display().is_table_caption() || caption.is_out_of_flow() { continue }
		styled := caption.as_node_with_style() or { return none }
		box := caption.as_box() or { return none }
		caption_style := caption.computed_values()
		mut used := state.get_mutable(styled)
		used.set_containing_block_used_values(wrapper_values)
		resolve_box_model_edges(caption_style, mut used, caption_inline_size.to_double())
		width := resolve_layout_content_size(caption, caption_style.size_value(.width), block_size, used, true) or { calculate_max_content_width(mut state, box) }
		// A caption in the wrapper's writing mode fills the wrapper's inline
		// size. An orthogonal caption's physical height is its block size, which
		// its contents determine unless it is specified.
		height := if specified := resolve_layout_content_size(caption, caption_style.size_value(.height), caption_inline_size, used, false) {
			?CSSPixels(specified)
		} else if caption_style.writing_mode() != .horizontal_tb {
			?CSSPixels(css_pixels_max(CSSPixels.new(0), caption_inline_size.minus(flex_or_grid_item_outer_block_edges(used))))
		} else {
			?CSSPixels(none)
		}
		used = layout_independent_child(mut state, caption, mut wrapper_values, caption_inline_size, caption_inline_size, width, height)
		resolve_vertical_table_caption_auto_margins(caption_style, mut used, caption_inline_size)
		if caption_style.caption_side() == .top {
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
	if rows.len > 0 {
		first := row_starts[0].plus(if reverse { row_widths[0].minus(ascents[0]) } else { ascents[0] })
		last_index := rows.len - 1
		last := row_starts[last_index].plus(if reverse {
			row_widths[last_index].minus(ascents[last_index])
		} else {
			ascents[last_index]
		})
		values.set_derived_vertical_baselines(first, last)
		wrapper_values.set_derived_vertical_baselines(values.offset.x().plus(first), values.offset.x().plus(last))
	}
	return FormattingContextResult{ automatic_content_width: total, automatic_content_height: wrapper_values.content_height() }
}

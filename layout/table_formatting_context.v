// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import math

struct TableCellPlacement {
	cell        &Node = unsafe { nil }
	row         int
	column      int
	row_span    int = 1
	column_span int = 1
}

struct TableColumnDefinition {
	node  &Node = unsafe { nil }
	index int
	span  int = 1
}

enum TableBorderSide {
	left
	right
	top
	bottom
}

struct TableBorderCandidate {
	width CSSPixels
	style string
	kind  int
}

fn table_border_property_ids(side TableBorderSide) (css.PropertyID, css.PropertyID) {
	return match side {
		.left { css.PropertyID.border_left_width, css.PropertyID.border_left_style }
		.right { css.PropertyID.border_right_width, css.PropertyID.border_right_style }
		.top { css.PropertyID.border_top_width, css.PropertyID.border_top_style }
		.bottom { css.PropertyID.border_bottom_width, css.PropertyID.border_bottom_style }
	}
}

fn table_border_candidate(node &Node, side TableBorderSide, kind int) TableBorderCandidate {
	width_property, style_property := table_border_property_ids(side)
	computed := node.computed_values()
	style_value := computed.property(style_property, .yes)
	style := if value := style_value { value.css_text.trim_space().to_lower() } else { 'none' }
	width := css_px(computed.length_percentage_to_px(width_property, 0) or { 0.0 })
	return TableBorderCandidate{
		width: width
		style: style
		kind:  kind
	}
}

fn table_border_style_rank(style string) int {
	return match style {
		'inset' { 0 }
		'groove' { 1 }
		'outset' { 2 }
		'ridge' { 3 }
		'dotted' { 4 }
		'dashed' { 5 }
		'solid' { 6 }
		'double' { 7 }
		else { -1 }
	}
}

fn winning_table_border(a TableBorderCandidate, b TableBorderCandidate) TableBorderCandidate {
	if a.style == 'hidden' {
		return a
	}
	if b.style == 'hidden' {
		return b
	}
	if a.style == 'none' {
		return b
	}
	if b.style == 'none' {
		return a
	}
	if a.width.raw_value() != b.width.raw_value() {
		return if a.width.raw_value() > b.width.raw_value() { a } else { b }
	}
	a_rank := table_border_style_rank(a.style)
	b_rank := table_border_style_rank(b.style)
	if a_rank != b_rank {
		return if a_rank > b_rank { a } else { b }
	}
	// Cell, row, row group, column, column group, table.
	return if a.kind >= b.kind { a } else { b }
}

fn table_placement_at_anchor(placements []TableCellPlacement, row int, column int) ?TableCellPlacement {
	if row < 0 || column < 0 {
		return none
	}
	for placement in placements {
		if row == placement.row && column == placement.column {
			return placement
		}
	}
	return none
}

fn table_column_definition_covering(definitions []TableColumnDefinition, column int) ?TableColumnDefinition {
	for definition in definitions {
		if column >= definition.index && column < definition.index + definition.span {
			return definition
		}
	}
	return none
}

fn table_row_group_bounds(rows []&Node, row_index int) (?&Node, int, int) {
	if row_index < 0 || row_index >= rows.len {
		return ?&Node(none), -1, -1
	}
	parent := rows[row_index].parent() or { return ?&Node(none), -1, -1 }
	if !parent.display().is_table_row_group() && !parent.display().is_table_header_group()
		&& !parent.display().is_table_footer_group() {
		return ?&Node(none), -1, -1
	}
	mut first := -1
	mut last := -1
	for index, row in rows {
		row_parent := row.parent() or { continue }
		if row_parent == parent {
			if first < 0 {
				first = index
			}
			last = index
		}
	}
	return parent, first, last
}

fn resolved_collapsed_table_cell_border(table &Node, rows []&Node, placements []TableCellPlacement, column_definitions []TableColumnDefinition, column_count int, placement TableCellPlacement, side TableBorderSide) CSSPixels {
	// Element-kind values are ordered by CSS 2.2 conflict specificity.
	mut winner := table_border_candidate(placement.cell, side, 6)
	neighbor_row, neighbor_column, neighbor_side := match side {
		.left { placement.row, placement.column - 1, TableBorderSide.right }
		.right { placement.row, placement.column + placement.column_span, TableBorderSide.left }
		.top { placement.row - 1, placement.column, TableBorderSide.bottom }
		.bottom { placement.row + placement.row_span, placement.column, TableBorderSide.top }
	}
	if neighbor := table_placement_at_anchor(placements, neighbor_row, neighbor_column) {
		winner = winning_table_border(winner,
			table_border_candidate(neighbor.cell, neighbor_side, 6))
	}

	// Row borders conflict with horizontal cell edges. Row left/right borders
	// participate only at the outside edge of the grid.
	if side == .top || side == .bottom {
		winner = winning_table_border(winner, table_border_candidate(rows[placement.row], side, 5))
		adjacent_row := if side == .top {
			placement.row - 1
		} else {
			placement.row + placement.row_span
		}
		if adjacent_row >= 0 && adjacent_row < rows.len {
			winner = winning_table_border(winner, table_border_candidate(rows[adjacent_row], if side == .top {
				TableBorderSide.bottom
			} else {
				TableBorderSide.top
			}, 5))
		}
	} else if (side == .left && placement.column == 0)
		|| (side == .right && placement.column + placement.column_span == column_count) {
		winner = winning_table_border(winner, table_border_candidate(rows[placement.row], side, 5))
	}

	group, group_first, group_last := table_row_group_bounds(rows, placement.row)
	if row_group := group {
		if (side == .top && placement.row == group_first)
			|| (side == .bottom && placement.row + placement.row_span - 1 == group_last)
			|| (side == .left && placement.column == 0)
			|| (side == .right && placement.column + placement.column_span == column_count) {
			winner = winning_table_border(winner, table_border_candidate(row_group, side, 4))
		}
	}
	adjacent_group_row := if side == .top {
		placement.row - 1
	} else if side == .bottom {
		placement.row + placement.row_span
	} else {
		-1
	}
	if adjacent_group_row >= 0 && adjacent_group_row < rows.len {
		adjacent_group, adjacent_first, adjacent_last := table_row_group_bounds(rows,
			adjacent_group_row)
		if row_group := adjacent_group {
			if (side == .top && adjacent_group_row == adjacent_last)
				|| (side == .bottom && adjacent_group_row == adjacent_first) {
				winner = winning_table_border(winner, table_border_candidate(row_group, if side == .top {
					TableBorderSide.bottom
				} else {
					TableBorderSide.top
				}, 4))
			}
		}
	}

	column_index := if side == .right {
		placement.column + placement.column_span - 1
	} else {
		placement.column
	}
	column_edge_participates := side == .left || side == .right
		|| (side == .top && placement.row == 0)
		|| (side == .bottom && placement.row + placement.row_span == rows.len)
	if column_edge_participates {
		if definition := table_column_definition_covering(column_definitions, column_index) {
			winner = winning_table_border(winner, table_border_candidate(definition.node, side, 3))
			if parent := definition.node.parent() {
				if parent.display().is_table_column_group() {
					winner = winning_table_border(winner, table_border_candidate(parent, side, 2))
				}
			}
		}
	}
	if side == .left && placement.column > 0 {
		if definition := table_column_definition_covering(column_definitions, placement.column - 1) {
			winner = winning_table_border(winner,
				table_border_candidate(definition.node, .right, 3))
		}
	} else if side == .right && placement.column + placement.column_span < column_count {
		if definition := table_column_definition_covering(column_definitions, placement.column +
			placement.column_span)
		{
			winner = winning_table_border(winner, table_border_candidate(definition.node, .left, 3))
		}
	}

	if (side == .top && placement.row == 0)
		|| (side == .bottom && placement.row + placement.row_span == rows.len)
		|| (side == .left && placement.column == 0)
		|| (side == .right && placement.column + placement.column_span == column_count) {
		winner = winning_table_border(winner, table_border_candidate(table, side, 1))
	}
	if winner.style == 'hidden' || winner.style == 'none' {
		return CSSPixels.new(0)
	}
	return winner.width
}

fn resolve_collapsed_table_borders(mut state LayoutState, table &Node, rows []&Node, placements []TableCellPlacement, column_definitions []TableColumnDefinition, column_count int) {
	if table.computed_values().border_collapse() != .collapse {
		return
	}
	for placement in placements {
		styled := placement.cell.as_node_with_style() or { continue }
		mut cell_state := state.get_mutable(styled)
		cell_state.use_collapsing_borders_model_ = true
		cell_state.border_left = resolved_collapsed_table_cell_border(table, rows, placements,
			column_definitions, column_count, placement, .left)
		cell_state.border_right = resolved_collapsed_table_cell_border(table, rows, placements,
			column_definitions, column_count, placement, .right)
		cell_state.border_top = resolved_collapsed_table_cell_border(table, rows, placements,
			column_definitions, column_count, placement, .top)
		cell_state.border_bottom = resolved_collapsed_table_cell_border(table, rows, placements,
			column_definitions, column_count, placement, .bottom)
	}
}

fn initialize_trailing_table_whitespace_state(mut state LayoutState, node &Node) {
	for child in node.children() {
		initialize_trailing_table_whitespace_state(mut state, child)
	}
	parent := node.parent() or { return }
	if !is_trailing_whitespace_of_inline_table(node)
		|| !ignorable_table_whitespace(node)
		|| (!parent.display().is_table_inside() && !parent.display().is_table_row_group()
		&& !parent.display().is_table_header_group() && !parent.display().is_table_footer_group()
		&& !parent.display().is_table_row()) {
		return
	}
	styled := node.as_node_with_style() or { return }
	mut values := state.get_mutable(styled)
	if containing_box := node.containing_block() {
		containing_node := unsafe { &Node(containing_box) }
		if containing_styled := containing_node.as_node_with_style() {
			if containing_values := state.try_get(containing_styled) {
				values.set_containing_block_used_values(containing_values)
			}
		}
	}
	values.set_content_width(CSSPixels.new(0))
	values.set_content_height(CSSPixels.new(0))
	values.set_content_offset(CSSPixelPoint.new(CSSPixels.new(0), CSSPixels.new(0)))
}

fn collect_typed_table_rows(node &Node, mut rows []&Node) {
	for child in node.children() {
		if child.display().is_table_row() {
			rows << child
		} else if child.display().is_table_row_group() || child.display().is_table_header_group()
			|| child.display().is_table_footer_group() {
			collect_typed_table_rows(child, mut rows)
		}
	}
}

fn table_span(node &Node, attribute string) int {
	dom_node := node.dom_node() or { return 1 }
	element := dom_node.as_element() or { return 1 }
	authored_value := element.get_attribute_value(attribute).trim_space()
	if attribute == 'rowspan' && authored_value == '0' {
		return 0
	}
	value := authored_value.int()
	if value < 1 {
		return 1
	}
	return if value > 65534 { 65534 } else { value }
}

fn collect_typed_table_columns(table &Node) []TableColumnDefinition {
	mut columns := []TableColumnDefinition{}
	mut index := 0
	for child in table.children() {
		if child.display().is_table_column() {
			span := table_span(child, 'span')
			columns << TableColumnDefinition{
				node:  child
				index: index
				span:  span
			}
			index += span
			continue
		}
		if !child.display().is_table_column_group() {
			continue
		}
		mut found_child_column := false
		for column in child.children() {
			if !column.display().is_table_column() {
				continue
			}
			found_child_column = true
			span := table_span(column, 'span')
			columns << TableColumnDefinition{
				node:  column
				index: index
				span:  span
			}
			index += span
		}
		if !found_child_column {
			span := table_span(child, 'span')
			columns << TableColumnDefinition{
				node:  child
				index: index
				span:  span
			}
			index += span
		}
	}
	return columns
}

fn calculate_table_cell_placements(rows []&Node) ([]TableCellPlacement, int) {
	mut placements := []TableCellPlacement{}
	mut occupied_until_row := map[int]int{}
	mut column_count := 0
	for row_index, row in rows {
		mut column := 0
		for cell in row.children() {
			if !cell.display().is_table_cell() {
				continue
			}
			for occupied_until_row[column] > row_index {
				column++
			}
			column_span := table_span(cell, 'colspan')
			authored_row_span := table_span(cell, 'rowspan')
			row_span := if authored_row_span == 0 { rows.len - row_index } else { authored_row_span }
			placement := TableCellPlacement{
				cell:        cell
				row:         row_index
				column:      column
				row_span:    row_span
				column_span: column_span
			}
			placements << placement
			for occupied_column in column .. column + column_span {
				occupied_until_row[occupied_column] = row_index + row_span
			}
			column += column_span
			if column > column_count {
				column_count = column
			}
		}
	}
	return placements, column_count
}

fn table_column_range_width(widths []CSSPixels, start int, span int, spacing CSSPixels) CSSPixels {
	mut width := spacing.scaled(f64(if span > 0 { span - 1 } else { 0 }))
	for column in start .. start + span {
		if column < widths.len {
			width = width.plus(widths[column])
		}
	}
	return width
}

fn table_column_offset(widths []CSSPixels, column int, spacing CSSPixels) CSSPixels {
	mut offset := spacing.scaled(f64(column + 1))
	for index in 0 .. column {
		if index < widths.len {
			offset = offset.plus(widths[index])
		}
	}
	return offset
}

fn table_cell_physical_offset(table &Node, table_width CSSPixels, widths []CSSPixels, placement TableCellPlacement, spacing CSSPixels) CSSPixels {
	logical_offset := table_column_offset(widths, placement.column, spacing)
	if table.computed_values().direction() != .rtl {
		return logical_offset
	}
	cell_width := table_column_range_width(widths, placement.column, placement.column_span, spacing)
	return table_width.minus(logical_offset).minus(cell_width)
}

fn distribute_table_cell_minimum_across_columns(mut widths []CSSPixels, placement TableCellPlacement, spacing CSSPixels, contribution CSSPixels) {
	current := table_column_range_width(widths, placement.column, placement.column_span, spacing)
	shortfall := contribution.minus(current)
	if shortfall.raw_value() <= 0 || placement.column_span <= 0 {
		return
	}
	mut baseline := CSSPixels.new(0)
	for column in placement.column .. placement.column + placement.column_span {
		if column >= 0 && column < widths.len {
			baseline = baseline.plus(widths[column])
		}
	}
	if baseline.raw_value() != 0 {
		for column in placement.column .. placement.column + placement.column_span {
			if column >= 0 && column < widths.len {
				ratio :=
					CSSPixels.nearest_value_for(widths[column].to_double() / baseline.to_double())
				widths[column] = widths[column].plus(ratio.times(shortfall))
			}
		}
	} else {
		addition := CSSPixels.from_raw(shortfall.raw_value() / placement.column_span)
		for column in placement.column .. placement.column + placement.column_span {
			if column >= 0 && column < widths.len {
				widths[column] = widths[column].plus(addition)
			}
		}
	}
}

fn table_columns_total_width(widths []CSSPixels) CSSPixels {
	mut total := CSSPixels.new(0)
	for width in widths {
		total = total.plus(width)
	}
	return total
}

fn assign_table_column_widths_linear_combination(mut widths []CSSPixels, candidate_widths []CSSPixels, available_width CSSPixels) {
	used_total := table_columns_total_width(widths)
	candidate_total := table_columns_total_width(candidate_widths)
	if candidate_total.raw_value() == used_total.raw_value() {
		return
	}
	candidate_weight := available_width.minus(used_total).to_double() / candidate_total.minus(used_total).to_double()
	for index in 0 .. widths.len {
		widths[index] = CSSPixels.nearest_value_for(
			candidate_weight * candidate_widths[index].to_double() +
			(1.0 - candidate_weight) * widths[index].to_double())
	}
}

fn collapsed_table_border_layout_width(width CSSPixels) CSSPixels {
	return css.css_pixels_round(width.divided_by_float(2.0))
}

fn table_cell_measurement_inline_edges(values UsedValues, collapsed bool) CSSPixels {
	left_border := if collapsed {
		collapsed_table_border_layout_width(values.border_left)
	} else {
		values.border_left
	}
	right_border := if collapsed {
		collapsed_table_border_layout_width(values.border_right)
	} else {
		values.border_right
	}
	return values.margin_left.plus(left_border).plus(values.padding_left).plus(values.padding_right).plus(right_border).plus(values.margin_right)
}

fn table_cell_measurement_block_edges(values UsedValues, collapsed bool) CSSPixels {
	top_border := if collapsed {
		collapsed_table_border_layout_width(values.border_top)
	} else {
		values.border_top
	}
	bottom_border := if collapsed {
		collapsed_table_border_layout_width(values.border_bottom)
	} else {
		values.border_bottom
	}
	return values.margin_top.plus(top_border).plus(values.padding_top).plus(values.padding_bottom).plus(bottom_border).plus(values.margin_bottom)
}

fn table_cell_measurement_outer_height(values UsedValues, collapsed bool) CSSPixels {
	return values.content_height().plus(table_cell_measurement_block_edges(values, collapsed))
}

fn table_cell_content_offset_left(values UsedValues, collapsed bool) CSSPixels {
	border := if collapsed {
		collapsed_table_border_layout_width(values.border_left)
	} else {
		values.border_left
	}
	return values.margin_left.plus(border).plus(values.padding_left)
}

fn table_cell_content_offset_top(values UsedValues, collapsed bool) CSSPixels {
	border := if collapsed {
		collapsed_table_border_layout_width(values.border_top)
	} else {
		values.border_top
	}
	return values.margin_top.plus(border).plus(values.padding_top)
}

// TableFormattingContext::position_cell_boxes()'s
// cell_is_anonymous_wrapper_for_flex_or_grid predicate. A table-cell box that
// exists only to wrap a flex/grid container is top-aligned; the child
// formatting context owns alignment of its contents.
fn table_cell_is_anonymous_wrapper_for_flex_or_grid(cell &Node) bool {
	if !cell.is_anonymous() || cell.children_.len != 1 {
		return false
	}
	display := cell.children_[0].computed_values().display()
	return display.is_flex_inside() || display.is_grid_inside()
}

fn table_cell_intrinsic_outer_width_contribution(mut state LayoutState, cell &Node, constraint SizeConstraint, collapsed bool) CSSPixels {
	box := cell.as_box() or { return CSSPixels.new(0) }
	// Anonymous table cells are created after their descendants have already
	// participated in table fixup. Measure their current subtree directly so a
	// pre-fixup intrinsic cache cannot hide floats wrapped by that cell.
	styled := cell.as_node_with_style() or { return CSSPixels.new(0) }
	mut values := state.get_mutable(styled)
	containing_width := if containing := values.containing_block_used_values() {
		containing.content_width()
	} else {
		CSSPixels.new(0)
	}
	winning_left := values.border_left
	winning_right := values.border_right
	winning_top := values.border_top
	winning_bottom := values.border_bottom
	resolve_box_model_edges(styled.computed_values(), mut values, containing_width.to_double())
	computed_left := values.border_left
	computed_right := values.border_right
	mut contribution := if cell.is_anonymous() {
		calculate_content_width_with_constraint(mut state, box, constraint).plus(flex_or_grid_item_outer_inline_edges(values))
	} else {
		intrinsic_outer_width_contribution(mut state, box, constraint)
	}
	// TableFormattingContext::compute_cell_measures(). A definite width on a
	// table cell constrains its max-content measure, but it never replaces the
	// cell's min-content floor. Generic intrinsic contribution sizing does let
	// a definite preferred width replace descendant intrinsic width, so restore
	// the table-specific outer min-content formula here.
	min_content_floor :=
		calculate_min_content_width(mut state, box).plus(flex_or_grid_item_outer_inline_edges(values))
	contribution = css_pixels_max(contribution, min_content_floor)
	if collapsed {
		contribution =
			contribution.minus(computed_left).minus(computed_right).plus(collapsed_table_border_layout_width(winning_left)).plus(collapsed_table_border_layout_width(winning_right))
		values.border_left = winning_left
		values.border_right = winning_right
		values.border_top = winning_top
		values.border_bottom = winning_bottom
	}
	return contribution
}

// The anonymous table wrapper's used width is the table grid's intrinsic
// width, not the fill-available width of an ordinary block. This is the width
// phase of TableFormattingContext::run_until_width_calculation().
fn calculate_table_grid_intrinsic_width(mut state LayoutState, table &Node, percentage_basis CSSPixels, constraint SizeConstraint) CSSPixels {
	mut rows := []&Node{}
	collect_typed_table_rows(table, mut rows)
	placements, placement_column_count := calculate_table_cell_placements(rows)
	column_definitions := collect_typed_table_columns(table)
	mut column_count := placement_column_count
	for definition in column_definitions {
		if definition.index + definition.span > column_count {
			column_count = definition.index + definition.span
		}
	}
	computed := table.computed_values()
	resolve_collapsed_table_borders(mut state, table, rows, placements, column_definitions,
		column_count)
	spacing := if computed.border_collapse() == .collapse {
		CSSPixels.new(0)
	} else {
		computed.border_spacing_horizontal().to_px(layout_length_resolution_context(table))
	}
	if column_count == 0 {
		return spacing
	}
	mut widths := []CSSPixels{len: column_count, init: CSSPixels.new(0)}
	for definition in column_definitions {
		definition_width := resolve_layout_size(definition.node,
			definition.node.computed_values().size_value(.width), percentage_basis) or { continue }
		per_column := definition_width.divided_by_float(f64(definition.span))
		for column in definition.index .. definition.index + definition.span {
			if column < widths.len {
				widths[column] = css_pixels_max(widths[column], per_column)
			}
		}
	}
	for placement in placements {
		if placement.column_span != 1 {
			continue
		}
		contribution := table_cell_intrinsic_outer_width_contribution(mut state, placement.cell,
			constraint, computed.border_collapse() == .collapse)
		widths[placement.column] = css_pixels_max(widths[placement.column], contribution)
	}
	mut maximum_span := 1
	for placement in placements {
		if placement.column_span > maximum_span {
			maximum_span = placement.column_span
		}
	}
	for span in 2 .. maximum_span + 1 {
		for placement in placements {
			if placement.column_span != span {
				continue
			}
			distribute_table_cell_minimum_across_columns(mut widths, placement, spacing, table_cell_intrinsic_outer_width_contribution(mut state,
				placement.cell, constraint, computed.border_collapse() == .collapse))
		}
	}
	mut result := spacing.scaled(f64(column_count + 1))
	for width in widths {
		result = result.plus(width)
	}
	// With width:auto, a percentage cell is also a constraint on the table
	// width. CSS 2.2 auto table layout asks the UA to enlarge the grid enough
	// for the cell's outer max-content width to occupy that percentage.
	if constraint == .max_content {
		for placement in placements {
			cell_width := placement.cell.computed_values().size_value(.width)
			if !cell_width.is_percentage() || cell_width.percentage().value() == 0 {
				continue
			}
			outer_max_width := table_cell_intrinsic_outer_width_contribution(mut state,
				placement.cell, .max_content, computed.border_collapse() == .collapse)
			adjusted :=
				spacing.scaled(f64(column_count + 1)).plus(CSSPixels.nearest_value_for(math.ceil(100.0 / cell_width.percentage().value() * outer_max_width.to_double())))
			result = css_pixels_max(result, adjusted)
		}
	}
	for child in table.children() {
		if !child.display().is_table_caption() {
			continue
		}
		caption := child.as_box() or { continue }
		// CAPMIN is the caption's min-content width, not its outer
		// max-content contribution.
		result = css_pixels_max(result, calculate_min_content_width(mut state, caption))
	}
	return result
}

fn compute_table_wrapper_content_width(mut state LayoutState, wrapper &Node, mut wrapper_state UsedValues, containing_width CSSPixels) CSSPixels {
	mut table := ?&Node(none)
	for child in wrapper.children() {
		if child.display().is_table_inside() {
			table = child
			break
		}
	}
	table_node := table or { return CSSPixels.new(0) }
	table_styled := table_node.as_node_with_style() or { return CSSPixels.new(0) }
	mut table_state := state.get_mutable(table_styled)
	table_state.set_containing_block_used_values(wrapper_state)
	resolve_box_model_edges(table_styled.computed_values(), mut table_state,
		containing_width.to_double())
	table_width := table_styled.computed_values().size_value(.width)
	grid_min := calculate_table_grid_intrinsic_width(mut state, table_node, containing_width,
		.min_content)
	grid_max := calculate_table_grid_intrinsic_width(mut state, table_node, containing_width,
		.max_content)
	mut table_content_width := grid_min
	if table_width.is_min_content() || wrapper_state.width_constraint == .min_content {
		table_content_width = grid_min
	} else if table_width.is_max_content() || wrapper_state.width_constraint == .max_content {
		table_content_width = grid_max
	} else if table_width.is_auto() {
		available_wrapper_content_width :=
			containing_width.minus(wrapper_state.margin_box_left()).minus(wrapper_state.margin_box_right())
		available_table_content_width :=
			available_wrapper_content_width.minus(table_state.border_box_left()).minus(table_state.border_box_right())
		table_content_width = css_pixels_max(css_pixels_min(grid_max, available_table_content_width),
			grid_min)
	} else if specified := resolve_layout_content_size(table_node, table_width, containing_width,
		table_state, true)
	{
		table_content_width = css_pixels_max(specified, grid_min)
	}
	table_content_width = clamp_layout_content_size(table_node, table_content_width,
		containing_width, table_state, true)
	table_border_box_width :=
		table_content_width.plus(table_state.border_left).plus(table_state.padding_left).plus(table_state.padding_right).plus(table_state.border_right)
	return table_border_box_width
}

fn table_wrapper_participates_as_grid_item(table &Node) bool {
	mut ancestor := table.parent()
	for ancestor != none {
		current := ancestor or { break }
		if current.is_grid_item() {
			return true
		}
		ancestor = current.parent()
	}
	return false
}

// Grid intrinsic track sizing can run the table wrapper at its min-content
// width before the grid item is stretched. The principal table's later table
// width calculation replaces its content width, but the CSS 2.1 block-width
// pass's consumed end margin remains from that intrinsic wrapper pass.
fn preserve_grid_intrinsic_table_end_margin(mut state LayoutState, table &Node, mut table_state UsedValues, percentage_basis CSSPixels) {
	if !table_wrapper_participates_as_grid_item(table)
		|| !table.computed_values().size_value(.width).contains_percentage() {
		return
	}
	grid_min := calculate_table_grid_intrinsic_width(mut state, table, percentage_basis,
		.min_content)
	intrinsic_wrapper_width :=
		grid_min.plus(table_state.border_box_left()).plus(table_state.border_box_right())
	mut intrinsic_table_state := UsedValues{}
	resolve_box_model_edges(table.computed_values(), mut intrinsic_table_state,
		intrinsic_wrapper_width.to_double())
	compute_block_used_width(table.computed_values(), mut intrinsic_table_state,
		intrinsic_wrapper_width.to_double())
	table_state.margin_left = intrinsic_table_state.margin_left
	table_state.margin_right = intrinsic_table_state.margin_right
}

fn layout_table_captions(mut state LayoutState, table &Node, mut table_state UsedValues, side css.CaptionSide, start_y CSSPixels) CSSPixels {
	mut cursor := start_y
	caption_available_width := table_state.border_box_width()
	for child in table.children() {
		if !child.display().is_table_caption() || child.computed_values().caption_side() != side {
			continue
		}
		styled := child.as_node_with_style() or { continue }
		mut caption_state := state.get_mutable(styled)
		mut has_caption_containing_state := false
		// Captions are principal block boxes in the table wrapper; the table
		// grid itself is not their containing block.
		if containing_box := table.containing_block() {
			containing_node := unsafe { &Node(containing_box) }
			if containing_styled := containing_node.as_node_with_style() {
				caption_state.set_containing_block_used_values(state.get_mutable(containing_styled))
				has_caption_containing_state = true
			}
		}
		if !has_caption_containing_state {
			caption_state.set_containing_block_used_values(table_state)
		}
		mut caption_containing_state := caption_state.containing_block_used_values() or {
			table_state
		}
		resolve_box_model_edges(styled.computed_values(), mut caption_state,
			caption_available_width.to_double())
		if child.computed_values().size_value(.width).is_auto() {
			// TableFormattingContext::run_caption_layout() enters the caption's
			// independent BFC with the table border-box width, then resolves the
			// caption's own horizontal metrics. Thus auto-width descendants see
			// the full caption available space even though the caption content box
			// is narrowed by its own border and padding afterwards.
			caption_state.set_content_width(caption_available_width)
			caption_state.set_has_definite_width(true)
			result := layout_inside_independent_formatting_context(mut state, child, mut
				caption_state, AvailableSpace.new(AvailableSize.make_definite(caption_available_width), if table_state.has_definite_height() {
				AvailableSize.make_definite(table_state.content_height())
			} else {
				AvailableSize.make_indefinite()
			}))
			caption_state.set_content_width(caption_available_width.minus(flex_or_grid_item_outer_inline_edges(caption_state)))
			if child.computed_values().size_value(.height).is_auto() {
				caption_state.set_content_height(result.automatic_content_height)
			}
		} else {
			caption_state = layout_independent_child(mut state, child, mut
				caption_containing_state, caption_available_width, if table_state.has_definite_height() {
				table_state.content_height()
			} else {
				none
			}, none, none)
		}
		caption_state.set_content_x(caption_state.margin_box_left())
		caption_state.set_content_y(cursor.plus(if side == .bottom {
			caption_state.margin_box_top()
		} else {
			caption_state.margin_top
		}))
		cursor = cursor.plus(caption_state.margin_box_height())
	}
	return cursor.minus(start_y)
}

fn run_table_formatting_context(mut state LayoutState, table &Node, mut table_state UsedValues, available_space AvailableSpace) FormattingContextResult {
	_ = available_space
	mut rows := []&Node{}
	collect_typed_table_rows(table, mut rows)
	placements, placement_column_count := calculate_table_cell_placements(rows)
	column_definitions := collect_typed_table_columns(table)
	mut defined_column_count := 0
	for definition in column_definitions {
		defined_column_count = if definition.index + definition.span > defined_column_count {
			definition.index + definition.span
		} else {
			defined_column_count
		}
	}
	column_count := if placement_column_count > defined_column_count {
		placement_column_count
	} else {
		defined_column_count
	}
	top_caption_height := layout_table_captions(mut state, table, mut table_state, .top,
		CSSPixels.new(0))
	for child in table.children() {
		if !child.display().is_table_caption() || child.computed_values().caption_side() != .top {
			continue
		}
		if styled := child.as_node_with_style() {
			caption_state := state.get(styled)
			table_state.set_content_y(caption_state.content_height().plus(caption_state.margin_box_bottom()))
		}
	}
	computed := table.computed_values()
	resolve_collapsed_table_borders(mut state, table, rows, placements, column_definitions,
		column_count)
	if computed.size_value(.width).contains_percentage() {
		// Percentages on the principal table are relative to the table wrapper's
		// containing block, not to the anonymous wrapper itself. The generic
		// child-width pass intentionally ran first so its over-constraint end
		// margin is retained, as in LibWeb.
		if wrapper_state := table_state.containing_block_used_values() {
			if outer_containing_state := wrapper_state.containing_block_used_values() {
				preserve_grid_intrinsic_table_end_margin(mut state, table, mut table_state,
					outer_containing_state.content_width())
				if resolved := resolve_layout_content_size(table, computed.size_value(.width),
					outer_containing_state.content_width(), table_state, true)
				{
					table_state.set_content_width(clamp_layout_content_size(table, resolved,
						outer_containing_state.content_width(), table_state, true))
					table_state.set_has_definite_width(true)
				}
			}
		}
	}
	if computed.size_value(.width).is_intrinsic_sizing_constraint() {
		// The wrapper width phase has already resolved an intrinsic table width.
		// Copy that border-box width back into the principal table before running
		// the grid, rather than letting the generic block equation retain a stale
		// end margin from its independent intrinsic measurement.
		if wrapper_state := table_state.containing_block_used_values() {
			table_state.set_content_width(wrapper_state.content_width().minus(table_state.border_box_left()).minus(table_state.border_box_right()))
			table_state.margin_left = CSSPixels.new(0)
			table_state.margin_right = CSSPixels.new(0)
		}
	}
	horizontal_spacing := if computed.border_collapse() == .collapse {
		CSSPixels.new(0)
	} else {
		computed.border_spacing_horizontal().to_px(layout_length_resolution_context(table))
	}
	vertical_spacing := if computed.border_collapse() == .collapse {
		CSSPixels.new(0)
	} else {
		computed.border_spacing_vertical().to_px(layout_length_resolution_context(table))
	}
	mut column_widths := []CSSPixels{len: column_count, init: CSSPixels.new(0)}
	mut column_min_widths := []CSSPixels{len: column_count, init: CSSPixels.new(0)}
	mut constrained_columns := []bool{len: column_count}
	mut intrinsic_percentages := []f64{len: column_count}
	mut has_intrinsic_percentage := []bool{len: column_count}
	for definition in column_definitions {
		definition_width := resolve_layout_size(definition.node,
			definition.node.computed_values().size_value(.width), table_state.content_width()) or {
			continue
		}
		per_column := definition_width.divided_by_float(f64(definition.span))
		for column in definition.index .. definition.index + definition.span {
			if column >= column_widths.len {
				continue
			}
			column_widths[column] = css_pixels_max(column_widths[column], per_column)
			column_min_widths[column] = css_pixels_max(column_min_widths[column], per_column)
			constrained_columns[column] = true
		}
	}
	preferred_table_width := computed.size_value(.width)
	fixed_mode := computed.table_layout() == .fixed && !preferred_table_width.is_auto()
	if fixed_mode {
		// In fixed mode only cells in the first row contribute column measures.
		// Percentage widths are intrinsic percentages, not constrained columns;
		// auto cells contribute zero. This is the fixed-mode specialization of
		// CSS Tables 3's cell-measure and column-measure algorithms.
		for placement in placements {
			if placement.row != 0 || placement.column_span != 1 {
				continue
			}
			styled := placement.cell.as_node_with_style() or { continue }
			mut cell_state := state.get_mutable(styled)
			resolve_box_model_edges(styled.computed_values(), mut cell_state,
				table_state.content_width().to_double())
			cell_width := placement.cell.computed_values().size_value(.width)
			if cell_width.is_percentage() {
				has_intrinsic_percentage[placement.column] = true
				intrinsic_percentages[placement.column] = math.max(intrinsic_percentages[placement.column],
					cell_width.percentage().value())
				column_min_widths[placement.column] = css_pixels_max(column_min_widths[placement.column], table_cell_intrinsic_outer_width_contribution(mut state,
					placement.cell, .min_content, computed.border_collapse() == .collapse))
			} else if cell_width.is_length()
				|| (cell_width.is_calculated() && !cell_width.contains_percentage()) {
				resolved_width := resolve_layout_content_size(placement.cell, cell_width,
					table_state.content_width(), cell_state, true) or { continue }
				outer_width := resolved_width.plus(flex_or_grid_item_outer_inline_edges(cell_state))
				column_min_widths[placement.column] = css_pixels_max(column_min_widths[placement.column],
					outer_width)
				column_widths[placement.column] = css_pixels_max(column_widths[placement.column],
					outer_width)
				constrained_columns[placement.column] = true
			}
		}
		assignable_width := table_state.content_width().minus(horizontal_spacing.scaled(f64(
			column_count + 1)))
		// 1. Min-content sizing guess. Percent and auto columns start at zero
		// in fixed mode; constrained length columns start at their minimum.
		for index in 0 .. column_widths.len {
			if constrained_columns[index] {
				column_widths[index] = column_min_widths[index]
			}
		}
		// 2. Min-content-percentage sizing guess.
		mut candidate_widths := column_widths.clone()
		for index in 0 .. candidate_widths.len {
			if has_intrinsic_percentage[index] {
				percentage_width :=
					CSSPixels.nearest_value_for(intrinsic_percentages[index] / 100.0 * assignable_width.to_double())
				candidate_widths[index] = css_pixels_max(column_min_widths[index], percentage_width)
			}
		}
		if assignable_width.raw_value() < table_columns_total_width(candidate_widths).raw_value() {
			assign_table_column_widths_linear_combination(mut column_widths, candidate_widths,
				assignable_width)
		} else {
			column_widths = candidate_widths.clone()
			// The min-content-specified and max-content guesses do not add
			// anything in fixed mode. Distribute the remaining width using the
			// fixed-mode priority order.
			remaining_width := assignable_width.minus(table_columns_total_width(column_widths))
			mut unconstrained_auto_count := 0
			for index in 0 .. column_widths.len {
				if !constrained_columns[index] && !has_intrinsic_percentage[index] {
					unconstrained_auto_count++
				}
			}
			if remaining_width.raw_value() > 0 && unconstrained_auto_count > 0 {
				addition :=
					CSSPixels.from_raw(remaining_width.raw_value() / unconstrained_auto_count)
				for index in 0 .. column_widths.len {
					if !constrained_columns[index] && !has_intrinsic_percentage[index] {
						column_widths[index] = column_widths[index].plus(addition)
					}
				}
			} else if remaining_width.raw_value() > 0 {
				used_width := table_columns_total_width(column_widths)
				if used_width.raw_value() > 0 {
					for index in 0 .. column_widths.len {
						if column_widths[index].raw_value() > 0 {
							addition :=
								CSSPixels.nearest_value_for(remaining_width.times(column_widths[index]).to_double() / used_width.to_double())
							column_widths[index] = column_widths[index].plus(addition)
						}
					}
				} else {
					mut percentage_total := 0.0
					for percentage in intrinsic_percentages {
						percentage_total += percentage
					}
					if percentage_total > 0 {
						for index in 0 .. column_widths.len {
							if intrinsic_percentages[index] > 0 {
								addition :=
									CSSPixels.nearest_value_for(remaining_width.to_double() * intrinsic_percentages[index] / percentage_total)
								column_widths[index] = column_widths[index].plus(addition)
							}
						}
					} else if column_count > 0 {
						equal_width := remaining_width.divided_by_float(f64(column_count))
						for index in 0 .. column_widths.len {
							column_widths[index] = column_widths[index].plus(equal_width)
						}
					}
				}
			}
		}
	} else {
		for placement in placements {
			if placement.column_span == 1 {
				cell_preferred_width := placement.cell.computed_values().size_value(.width)
				column_min_widths[placement.column] = css_pixels_max(column_min_widths[placement.column], table_cell_intrinsic_outer_width_contribution(mut state,
					placement.cell, .min_content, computed.border_collapse() == .collapse))
				column_widths[placement.column] = css_pixels_max(column_widths[placement.column], table_cell_intrinsic_outer_width_contribution(mut state,
					placement.cell, .max_content, computed.border_collapse() == .collapse))
				if cell_preferred_width.is_length() {
					constrained_columns[placement.column] = true
				}
				if cell_preferred_width.is_percentage() {
					has_intrinsic_percentage[placement.column] = true
					intrinsic_percentages[placement.column] = math.max(intrinsic_percentages[placement.column],
						cell_preferred_width.percentage().value())
				}
			}
		}
		mut maximum_column_span := 1
		for placement in placements {
			if placement.column_span > maximum_column_span {
				maximum_column_span = placement.column_span
			}
		}
		// Intrinsic percentages from spanning cells are distributed using the
		// non-spanning max-content measures of the columns they cover.
		for span in 2 .. maximum_column_span + 1 {
			mut next_percentages := intrinsic_percentages.clone()
			for placement in placements {
				if placement.column_span != span {
					continue
				}
				cell_width := placement.cell.computed_values().size_value(.width)
				if !cell_width.is_percentage() {
					continue
				}
				end_column := if placement.column + placement.column_span < column_count {
					placement.column + placement.column_span
				} else {
					column_count
				}
				mut cell_contribution :=
					CSSPixels.nearest_value_for(cell_width.percentage().value())
				for column in placement.column .. end_column {
					cell_contribution =
						cell_contribution.minus(CSSPixels.nearest_value_for(intrinsic_percentages[column]))
					cell_contribution = css_pixels_max(cell_contribution, CSSPixels.new(0))
				}
				mut zero_percentage_max_sum := CSSPixels.new(0)
				mut zero_percentage_count := 0
				for column in placement.column .. end_column {
					if intrinsic_percentages[column] == 0 {
						zero_percentage_max_sum =
							zero_percentage_max_sum.plus(column_widths[column])
						zero_percentage_count++
					}
				}
				for column in placement.column .. end_column {
					if intrinsic_percentages[column] > 0 {
						continue
					}
					adjusted := if zero_percentage_max_sum.raw_value() != 0 {
						cell_contribution.times_float(column_widths[column].to_double() / zero_percentage_max_sum.to_double())
					} else if zero_percentage_count > 0 {
						CSSPixels.from_raw(cell_contribution.raw_value() / zero_percentage_count)
					} else {
						CSSPixels.new(0)
					}
					next_percentages[column] = math.max(next_percentages[column],
						adjusted.to_double())
				}
			}
			intrinsic_percentages = next_percentages.clone()
		}
		mut total_intrinsic_percentage := 0.0
		for index in 0 .. intrinsic_percentages.len {
			intrinsic_percentages[index] = math.max(math.min(100.0 - total_intrinsic_percentage,
				intrinsic_percentages[index]), 0.0)
			total_intrinsic_percentage += intrinsic_percentages[index]
			has_intrinsic_percentage[index] = intrinsic_percentages[index] > 0
		}
		for span in 2 .. maximum_column_span + 1 {
			for placement in placements {
				if placement.column_span != span {
					continue
				}
				min_contribution := table_cell_intrinsic_outer_width_contribution(mut state,
					placement.cell, .min_content, computed.border_collapse() == .collapse)
				distribute_table_cell_minimum_across_columns(mut column_min_widths, placement,
					horizontal_spacing, min_contribution)
				contribution := table_cell_intrinsic_outer_width_contribution(mut state,
					placement.cell, .max_content, computed.border_collapse() == .collapse)
				distribute_table_cell_minimum_across_columns(mut column_widths, placement,
					horizontal_spacing, contribution)
			}
		}
		// The used table width is never smaller than GRIDMIN. A specified table
		// width is therefore allowed to grow when its cells' min-content measures
		// do not fit (CSS Tables 3, "Computing the table width").
		mut grid_min := horizontal_spacing.scaled(f64(column_count + 1))
		for width in column_min_widths {
			grid_min = grid_min.plus(width)
		}
		if grid_min.raw_value() > table_state.content_width().raw_value() {
			table_state.set_content_width(grid_min)
		}
		column_max_widths := column_widths.clone()
		assignable_width := table_state.content_width().minus(horizontal_spacing.scaled(f64(
			column_count + 1)))
		column_widths = column_min_widths.clone()
		mut candidate_widths := column_min_widths.clone()
		// Min-content-percentage sizing guess.
		for index in 0 .. candidate_widths.len {
			if has_intrinsic_percentage[index] {
				percentage_width :=
					CSSPixels.nearest_value_for(intrinsic_percentages[index] / 100.0 * assignable_width.to_double())
				candidate_widths[index] = css_pixels_max(column_min_widths[index], percentage_width)
			}
		}
		mut width_distribution_complete := false
		if assignable_width.raw_value() < table_columns_total_width(candidate_widths).raw_value() {
			assign_table_column_widths_linear_combination(mut column_widths, candidate_widths,
				assignable_width)
			width_distribution_complete = true
		} else {
			column_widths = candidate_widths.clone()
		}
		// Min-content-specified sizing guess.
		if !width_distribution_complete {
			for index in 0 .. candidate_widths.len {
				if constrained_columns[index] {
					candidate_widths[index] = column_max_widths[index]
				}
			}
			if assignable_width.raw_value() < table_columns_total_width(candidate_widths).raw_value() {
				assign_table_column_widths_linear_combination(mut column_widths, candidate_widths,
					assignable_width)
				width_distribution_complete = true
			} else {
				column_widths = candidate_widths.clone()
			}
		}
		// Max-content sizing guess.
		if !width_distribution_complete {
			for index in 0 .. candidate_widths.len {
				if !has_intrinsic_percentage[index] {
					candidate_widths[index] = column_max_widths[index]
				}
			}
			if assignable_width.raw_value() < table_columns_total_width(candidate_widths).raw_value() {
				assign_table_column_widths_linear_combination(mut column_widths, candidate_widths,
					assignable_width)
				width_distribution_complete = true
			} else {
				column_widths = candidate_widths.clone()
			}
		}
		mut remaining := assignable_width.minus(table_columns_total_width(column_widths))
		if !width_distribution_complete && remaining.raw_value() > 0 {
			// First excess-width rule: grow non-constrained, non-percentage
			// originating columns in proportion to max-content width.
			mut zero_percentage_max_total := CSSPixels.new(0)
			for index in 0 .. column_widths.len {
				if !constrained_columns[index] && intrinsic_percentages[index] == 0
					&& column_max_widths[index].raw_value() > 0 {
					zero_percentage_max_total =
						zero_percentage_max_total.plus(column_max_widths[index])
				}
			}
			if zero_percentage_max_total.raw_value() > 0 {
				for index in 0 .. column_widths.len {
					if !constrained_columns[index] && intrinsic_percentages[index] == 0
						&& column_max_widths[index].raw_value() > 0 {
						addition :=
							CSSPixels.nearest_value_for(remaining.times(column_max_widths[index]).to_double() / zero_percentage_max_total.to_double())
						column_widths[index] = column_widths[index].plus(addition)
					}
				}
				remaining = assignable_width.minus(table_columns_total_width(column_widths))
			}
			mut percentage_total := 0.0
			for percentage in intrinsic_percentages {
				percentage_total += percentage
			}
			if percentage_total > 0 && remaining.raw_value() > 0 {
				for index in 0 .. column_widths.len {
					if intrinsic_percentages[index] > 0 {
						addition :=
							CSSPixels.nearest_value_for(remaining.to_double() * intrinsic_percentages[index] / percentage_total)
						column_widths[index] = column_widths[index].plus(addition)
					}
				}
			}
			remaining_after_percentages :=
				assignable_width.minus(table_columns_total_width(column_widths))
			mut growth_column_count := 0
			for index, constrained in constrained_columns {
				if !constrained && intrinsic_percentages[index] == 0 {
					growth_column_count++
				}
			}
			if growth_column_count == 0 && percentage_total == 0 {
				growth_column_count = column_count
			}
			intrinsic_columns_width := table_columns_total_width(column_max_widths)
			if growth_column_count == column_count && intrinsic_columns_width.raw_value() > 0
				&& remaining_after_percentages.raw_value() > 0 {
				// In the final auto-layout distribution step, columns without a
				// specified width grow in proportion to their max-content widths.
				// This also preserves the ratio established by spanning cells.
				for index in 0 .. column_widths.len {
					addition :=
						CSSPixels.nearest_value_for(remaining_after_percentages.times(column_max_widths[index]).to_double() / intrinsic_columns_width.to_double())
					column_widths[index] = column_widths[index].plus(addition)
				}
			} else if growth_column_count > 0 && remaining_after_percentages.raw_value() > 0 {
				addition := remaining_after_percentages.divided_by_float(f64(growth_column_count))
				for index in 0 .. column_widths.len {
					if !constrained_columns[index] && intrinsic_percentages[index] == 0 {
						column_widths[index] = column_widths[index].plus(addition)
					}
				}
			}
		}
	}

	mut row_heights := []CSSPixels{len: rows.len, init: CSSPixels.new(0)}
	mut row_baselines := []CSSPixels{len: rows.len, init: CSSPixels.new(0)}
	mut cell_baselines := []CSSPixels{len: placements.len, init: CSSPixels.new(0)}
	for index, row in rows {
		// First pass: definite row lengths participate in the base height.
		// Percentages are resolved only after the table grid height is known.
		row_height := row.computed_values().size_value(.height)
		if row_height.is_length()
			|| (row_height.is_calculated() && !row_height.contains_percentage()) {
			if specified_height := resolve_layout_size(row, row_height,
				table_state.content_height())
			{
				row_heights[index] = specified_height
			}
		}
	}
	for placement_index, placement in placements {
		cell_width := table_column_range_width(column_widths, placement.column,
			placement.column_span, horizontal_spacing)
		styled := placement.cell.as_node_with_style() or { continue }
		mut cell_state := state.get_mutable(styled)
		cell_state.set_containing_block_used_values(table_state)
		collapsed := computed.border_collapse() == .collapse
		collapsed_left := if collapsed { ?CSSPixels(cell_state.border_left) } else { none }
		collapsed_right := if collapsed { ?CSSPixels(cell_state.border_right) } else { none }
		collapsed_top := if collapsed { ?CSSPixels(cell_state.border_top) } else { none }
		collapsed_bottom := if collapsed { ?CSSPixels(cell_state.border_bottom) } else { none }
		resolve_box_model_edges(styled.computed_values(), mut cell_state, cell_width.to_double())
		if border := collapsed_left {
			cell_state.border_left = border
		}
		if border := collapsed_right {
			cell_state.border_right = border
		}
		if border := collapsed_top {
			cell_state.border_top = border
		}
		if border := collapsed_bottom {
			cell_state.border_bottom = border
		}
		content_width :=
			cell_width.minus(table_cell_measurement_inline_edges(cell_state, collapsed))
		// CSS Tables computes a definite cell height as the used height of the
		// cell's border box. UsedValues stores the content height, so subtract
		// the resolved padding and borders before laying out the cell contents.
		// This is intentionally different from ordinary box height resolution.
		mut forced_cell_height := ?CSSPixels(none)
		cell_computed_height := placement.cell.computed_values().size_value(.height)
		if cell_computed_height.is_length()
			|| (cell_computed_height.is_calculated() && !cell_computed_height.contains_percentage()) {
			if cell_used_height := resolve_layout_size(placement.cell, cell_computed_height,
				table_state.content_height())
			{
				forced_cell_height = cell_used_height.minus(table_cell_measurement_block_edges(cell_state,
					collapsed))
			}
		}
		cell_state = layout_independent_child_using_automatic_height(mut state, placement.cell, mut
			table_state, table_state.content_width(), if table_state.has_definite_height() {
			table_state.content_height()
		} else {
			none
		}, content_width, forced_cell_height)
		if border := collapsed_left {
			cell_state.border_left = border
		}
		if border := collapsed_right {
			cell_state.border_right = border
		}
		if border := collapsed_top {
			cell_state.border_top = border
		}
		if border := collapsed_bottom {
			cell_state.border_bottom = border
		}
		cell_baselines[placement_index] = layout_box_baseline(state, placement.cell)
		if placement.row >= 0 && placement.row < row_baselines.len {
			row_baselines[placement.row] = css_pixels_max(row_baselines[placement.row],
				cell_baselines[placement_index])
		}
		if placement.row_span == 1 {
			row_heights[placement.row] = css_pixels_max(row_heights[placement.row], table_cell_measurement_outer_height(cell_state,
				collapsed))
			cell_height := placement.cell.computed_values().size_value(.height)
			if cell_height.is_length()
				|| (cell_height.is_calculated() && !cell_height.contains_percentage()) {
				if specified_height := resolve_layout_size(placement.cell, cell_height,
					table_state.content_height())
				{
					row_heights[placement.row] = css_pixels_max(row_heights[placement.row],
						specified_height)
				}
			}
		}
	}
	// A spanning cell's minimum height is distributed over the rows it spans
	// after single-row cells have established their row minima.
	for placement in placements {
		if placement.row_span <= 1 {
			continue
		}
		styled := placement.cell.as_node_with_style() or { continue }
		cell_state := state.get(styled)
		mut current := vertical_spacing.scaled(f64(placement.row_span - 1))
		for row in placement.row .. placement.row + placement.row_span {
			if row < row_heights.len {
				current = current.plus(row_heights[row])
			}
		}
		shortfall := table_cell_measurement_outer_height(cell_state,
			computed.border_collapse() == .collapse).minus(current)
		if shortfall.raw_value() > 0 {
			addition := shortfall.divided_by_float(f64(placement.row_span))
			for row in placement.row .. placement.row + placement.row_span {
				if row < row_heights.len {
					row_heights[row] = row_heights[row].plus(addition)
				}
			}
		}
	}

	// CSS Tables 3 table-height distribution. The specified table height is a
	// minimum for the grid. Once it is known, percentage row/cell heights can
	// contribute their reference sizes. Remaining height first goes to auto
	// rows, or to every row when none are auto-sized.
	mut table_grid_height := CSSPixels.new(0)
	for height in row_heights {
		table_grid_height = table_grid_height.plus(height)
	}
	table_height := computed.size_value(.height)
	if !table_height.is_auto() {
		mut percentage_basis := CSSPixels.new(0)
		if wrapper_state := table_state.containing_block_used_values() {
			if outer_containing_state := wrapper_state.containing_block_used_values() {
				percentage_basis = outer_containing_state.content_height()
			}
		}
		if specified_height := resolve_layout_content_size(table, table_height, percentage_basis,
			table_state, false)
		{
			table_grid_height = css_pixels_max(table_grid_height, specified_height)
		}
	}
	mut reference_heights := row_heights.clone()
	for index, row in rows {
		row_height := row.computed_values().size_value(.height)
		if row_height.is_percentage()
			|| (row_height.is_calculated() && row_height.contains_percentage()) {
			if specified_height := resolve_layout_size(row, row_height, table_grid_height) {
				reference_heights[index] = css_pixels_max(reference_heights[index],
					specified_height)
			}
		}
	}
	for placement in placements {
		if placement.row_span != 1 {
			continue
		}
		cell_height := placement.cell.computed_values().size_value(.height)
		if !cell_height.is_percentage() && !(cell_height.is_calculated()
			&& cell_height.contains_percentage()) {
			continue
		}
		if specified_height := resolve_layout_size(placement.cell, cell_height, table_grid_height) {
			reference_heights[placement.row] = css_pixels_max(reference_heights[placement.row],
				specified_height)
		}
	}
	mut sum_reference_height := CSSPixels.new(0)
	for height in reference_heights {
		sum_reference_height = sum_reference_height.plus(height)
	}
	if sum_reference_height.raw_value() > 0 {
		if table_grid_height.raw_value() <= sum_reference_height.raw_value() {
			for index in 0 .. row_heights.len {
				weight := reference_heights[index].to_double() / sum_reference_height.to_double()
				row_heights[index] =
					CSSPixels.nearest_value_for(table_grid_height.to_double() * weight)
			}
		} else if table_grid_height.raw_value() > sum_reference_height.raw_value() {
			mut auto_row_count := 0
			for row in rows {
				if row.computed_values().size_value(.height).is_auto() {
					auto_row_count++
				}
			}
			if auto_row_count > 0 {
				increment :=
					table_grid_height.minus(sum_reference_height).divided_by_float(f64(auto_row_count))
				for index, row in rows {
					row_heights[index] = reference_heights[index]
					if row.computed_values().size_value(.height).is_auto() {
						row_heights[index] = row_heights[index].plus(increment)
					}
				}
			} else if row_heights.len > 0 {
				increment :=
					table_grid_height.minus(sum_reference_height).divided_by_float(f64(row_heights.len))
				for index in 0 .. row_heights.len {
					row_heights[index] = reference_heights[index].plus(increment)
				}
			}
		} else {
			row_heights = reference_heights.clone()
		}
	}

	mut row_offsets := []CSSPixels{len: rows.len}
	table_grid_content_width := if column_count > 0 {
		table_columns_total_width(column_widths).plus(horizontal_spacing.scaled(f64(column_count - 1)))
	} else {
		CSSPixels.new(0)
	}
	mut cursor_y := vertical_spacing
	for index, row in rows {
		row_offsets[index] = cursor_y
		if styled := row.as_node_with_style() {
			mut row_state := state.get_mutable(styled)
			row_state.set_containing_block_used_values(table_state)
			row_state.set_content_width(table_grid_content_width)
			row_state.set_content_height(row_heights[index])
			row_state.set_content_offset(CSSPixelPoint.new(horizontal_spacing, cursor_y))
		}
		cursor_y = cursor_y.plus(row_heights[index]).plus(vertical_spacing)
	}
	for group in table.children() {
		if !group.display().is_table_row_group() && !group.display().is_table_header_group()
			&& !group.display().is_table_footer_group() {
			continue
		}
		mut first_row := -1
		mut last_row := -1
		for index, row in rows {
			parent := row.parent() or { continue }
			if parent != group {
				continue
			}
			if first_row < 0 {
				first_row = index
			}
			last_row = index
		}
		if first_row < 0 {
			// Empty row groups still start at the table grid's first spacing
			// edge. They have no row-derived width or height.
			styled := group.as_node_with_style() or { continue }
			mut group_state := state.get_mutable(styled)
			group_state.set_containing_block_used_values(table_state)
			group_state.set_content_width(CSSPixels.new(0))
			group_state.set_content_height(CSSPixels.new(0))
			group_state.set_content_offset(CSSPixelPoint.new(horizontal_spacing, vertical_spacing))
			continue
		}
		styled := group.as_node_with_style() or { continue }
		mut group_state := state.get_mutable(styled)
		group_state.set_containing_block_used_values(table_state)
		mut group_height := vertical_spacing.scaled(f64(last_row - first_row))
		for row_index in first_row .. last_row + 1 {
			group_height = group_height.plus(row_heights[row_index])
		}
		group_state.set_content_width(table_grid_content_width)
		group_state.set_content_height(group_height)
		group_state.set_content_offset(CSSPixelPoint.new(horizontal_spacing, row_offsets[first_row]))
	}
	for placement_index, placement in placements {
		styled := placement.cell.as_node_with_style() or { continue }
		mut cell_state := state.get_mutable(styled)
		mut spanned_height := vertical_spacing.scaled(f64(placement.row_span - 1))
		for row in placement.row .. placement.row + placement.row_span {
			if row < row_heights.len {
				spanned_height = spanned_height.plus(row_heights[row])
			}
		}
		collapsed := computed.border_collapse() == .collapse
		alignment_space := spanned_height.minus(table_cell_measurement_outer_height(cell_state,
			collapsed))
		if alignment_space.raw_value() > 0 {
			if table_cell_is_anonymous_wrapper_for_flex_or_grid(placement.cell) {
				cell_state.padding_bottom = cell_state.padding_bottom.plus(alignment_space)
			} else {
				match placement.cell.computed_values().vertical_align() {
					.middle {
						leading := CSSPixels.from_raw(alignment_space.raw_value() / 2)
						cell_state.padding_top = cell_state.padding_top.plus(leading)
						cell_state.padding_bottom = cell_state.padding_bottom.plus(leading)
					}
					.bottom {
						cell_state.padding_top = cell_state.padding_top.plus(alignment_space)
					}
					.baseline, .sub, .super_, .text_top, .text_bottom {
						baseline_adjustment :=
							row_baselines[placement.row].minus(cell_baselines[placement_index])
						cell_state.padding_top = cell_state.padding_top.plus(baseline_adjustment)
						cell_state.padding_bottom =
							cell_state.padding_bottom.plus(alignment_space.minus(baseline_adjustment))
					}
					.top {
						cell_state.padding_bottom = cell_state.padding_bottom.plus(alignment_space)
					}
				}
			}
		}
		cell_state.set_content_x(table_cell_physical_offset(table, table_state.content_width(),
			column_widths, placement, horizontal_spacing).plus(table_cell_content_offset_left(cell_state,
			collapsed)))
		cell_state.set_content_y(row_offsets[placement.row].plus(table_cell_content_offset_top(cell_state,
			collapsed)))
	}
	final_table_height := css_pixels_max(cursor_y, table_grid_height)
	table_state.set_content_height(final_table_height)
	bottom_caption_height := layout_table_captions(mut state, table, mut table_state, .bottom,
		table_state.margin_box_height())
	table_state.margin_bottom =
		table_state.margin_bottom.plus(top_caption_height).plus(bottom_caption_height)
	if table.is_inline_table() {
		initialize_trailing_table_whitespace_state(mut state, table)
	}
	return FormattingContextResult{
		automatic_content_width:  table_state.content_width()
		automatic_content_height: final_table_height
	}
}

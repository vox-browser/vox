// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
module layout

import css
import math
import os
import painting
import time
import platform

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

struct TableRowGroupInfo {
	node        &Node = unsafe { nil }
	start_index int
	last_index  int
}

// TableFormattingContext::Cell stores these two measures together. Keeping the
// pair is important: column initialization, spanning-cell distribution, and
// percentage width constraints all consume the same computed cell measures.
struct TableCellIntrinsicWidthMeasures {
	outer_min_width CSSPixels
	outer_max_width CSSPixels
}

struct TableCellIntrinsicHeightMeasures {
	outer_min_height       CSSPixels
	outer_max_height       CSSPixels
	outer_specified_height CSSPixels
}

@[heap]
struct TableGridIntrinsicWidths {
	grid_min                  CSSPixels
	grid_max                  CSSPixels
	capmin                    CSSPixels
	percentage_adjusted_width CSSPixels
	percentage_basis          CSSPixels
	rows                      []&Node
	placements                []TableCellPlacement
	column_definitions        []TableColumnDefinition
	column_count              int
	cell_measures             []TableCellIntrinsicWidthMeasures
	nonspanning_min_widths    []CSSPixels
	nonspanning_max_widths    []CSSPixels
	column_min_widths         []CSSPixels
	column_max_widths         []CSSPixels
	constrained_columns       []bool
	intrinsic_percentages     []f64
	has_intrinsic_percentage  []bool
	percentage_offsets        []CSSPixels
	has_originating_cells     []bool
	collapsed_columns         []bool
}

enum TableBorderSide {
	left
	right
	top
	bottom
}

struct TableBorderCandidate {
	border_data  painting.BorderData
	element_kind painting.ConflictingElementKind
	row          ?int
	column       ?int
}

fn table_painting_line_style(style css.LineStyle) painting.LineStyle {
	return match style {
		.none_ { .none }
		.hidden { .hidden }
		.dotted { .dotted }
		.dashed { .dashed }
		.solid { .solid }
		.double_ { .double }
		.groove { .groove }
		.ridge { .ridge }
		.inset { .inset }
		.outset { .outset }
	}
}

fn table_border_candidate(node &Node, side TableBorderSide, element_kind painting.ConflictingElementKind, row ?int, column ?int) TableBorderCandidate {
	computed := node.computed_values()
	border := match side {
		.left { computed.border_left() }
		.right { computed.border_right() }
		.top { computed.border_top() }
		.bottom { computed.border_bottom() }
	}
	line_style := table_painting_line_style(border.line_style)
	color := border.color
	return TableBorderCandidate{
		border_data: painting.BorderData{
			color: painting.Color{color.r, color.g, color.b, color.a}
			line_style: line_style
			width: border.width.to_double()
		}
		element_kind: element_kind
		row: row
		column: column
	}
}

fn table_border_style_rank(style painting.LineStyle) int {
	return match style {
		.inset { 0 }
		.groove { 1 }
		.outset { 2 }
		.ridge { 3 }
		.dotted { 4 }
		.dashed { 5 }
		.solid { 6 }
		.double { 7 }
		else { -1 }
	}
}

fn table_border_is_less_specific(a painting.BorderData, b painting.BorderData) bool {
	if a.line_style == .hidden {
		return false
	}
	if b.line_style == .hidden {
		return true
	}
	if a.line_style == .none {
		return true
	}
	if b.line_style == .none {
		return false
	}
	if a.width != b.width {
		return a.width < b.width
	}
	return table_border_style_rank(a.line_style) < table_border_style_rank(b.line_style)
}

fn winning_table_border(a TableBorderCandidate, b TableBorderCandidate) TableBorderCandidate {
	// Step 4 is checked first upstream: equal style and width are resolved by
	// element kind, then by the leftmost/topmost source edge.
	if a.border_data.line_style == b.border_data.line_style && a.border_data.width == b.border_data.width {
		if int(a.element_kind) != int(b.element_kind) {
			return if int(a.element_kind) < int(b.element_kind) { a } else { b }
		}
		if a_column := a.column {
			if b_column := b.column {
				if a_column != b_column {
					return if a_column < b_column { a } else { b }
				}
			}
		}
		if a_row := a.row {
			if b_row := b.row {
				if a_row != b_row {
					return if a_row < b_row { a } else { b }
				}
			}
		}
		return a
	}
	return if table_border_is_less_specific(a.border_data, b.border_data) { b } else { a }
}

fn table_placement_key(row int, column int) u64 {
	return (u64(u32(row)) << 32) | u64(u32(column))
}

fn table_row_groups_by_index(rows []&Node) map[int]TableRowGroupInfo {
	mut result := map[int]TableRowGroupInfo{}
	mut index := 0
	for index < rows.len {
		parent := rows[index].parent() or {
			index++
			continue
		}
		if !parent.display().is_table_row_group() && !parent.display().is_table_header_group() && !parent.display().is_table_footer_group() {
			index++
			continue
		}
		start_index := index
		for index + 1 < rows.len {
			next_parent := rows[index + 1].parent() or { break }
			if voidptr(next_parent) != voidptr(parent) {
				break
			}
			index++
		}
		info := TableRowGroupInfo{
			node: parent
			start_index: start_index
			last_index: index
		}
		for row_index in start_index .. index + 1 {
			result[row_index] = info
		}
		index++
	}
	return result
}

fn table_row_is_collapsed(row &Node) bool {
	if row.computed_values().visibility() == .collapse {
		return true
	}
	if row_group := row.parent() {
		if (row_group.display().is_table_row_group()
			|| row_group.display().is_table_header_group()
			|| row_group.display().is_table_footer_group())
			&& row_group.computed_values().visibility() == .collapse {
			return true
		}
	}
	return false
}

fn resolved_collapsed_table_cell_border(table &Node, rows []&Node, placements_by_coordinate map[u64]TableCellPlacement, row_groups_by_index map[int]TableRowGroupInfo, column_definitions_by_index map[int]TableColumnDefinition, column_count int, placement TableCellPlacement, side TableBorderSide) TableBorderCandidate {
	mut winner := table_border_candidate(placement.cell, side, .cell, placement.row, placement.column)
	neighbor_row, neighbor_column, neighbor_side := match side {
		.left { placement.row, placement.column - placement.column_span, TableBorderSide.right }
		.right { placement.row, placement.column + placement.column_span, TableBorderSide.left }
		.top { placement.row - placement.row_span, placement.column, TableBorderSide.bottom }
		.bottom { placement.row + placement.row_span, placement.column, TableBorderSide.top }
	}
	if neighbor_row >= 0 && neighbor_column >= 0 {
		if neighbor := placements_by_coordinate[table_placement_key(neighbor_row, neighbor_column)] {
			winner = winning_table_border(winner, table_border_candidate(neighbor.cell, neighbor_side, .cell, neighbor.row, neighbor.column))
		}
	}

	// Row borders conflict with horizontal cell edges. Row left/right borders
	// participate only at the outside edge of the grid.
	if side == .top || side == .bottom {
		winner = winning_table_border(winner, table_border_candidate(rows[placement.row], side, .row, placement.row, none))
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
			}, .row, adjacent_row, none))
		}
	} else if (side == .left && placement.column == 0) || (side == .right && placement.column + placement.column_span == column_count) {
		winner = winning_table_border(winner, table_border_candidate(rows[placement.row], side, .row, placement.row, none))
	}

	if group := row_groups_by_index[placement.row] {
		if (side == .top && placement.row == group.start_index) || (side == .bottom && placement.row == group.last_index) || (side == .left && placement.column == 0) || (side == .right && placement.column + placement.column_span == column_count) {
			winner = winning_table_border(winner, table_border_candidate(group.node, side, .row_group, group.start_index, none))
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
		if adjacent_group := row_groups_by_index[adjacent_group_row] {
			if (side == .top && placement.row == adjacent_group.last_index + 1) || (side == .bottom && adjacent_group_row == adjacent_group.start_index) {
				winner = winning_table_border(winner, table_border_candidate(adjacent_group.node, if side == .top {
					TableBorderSide.bottom
				} else {
					TableBorderSide.top
				}, .row_group, adjacent_group.start_index, none))
			}
		}
	}

	column_index := if side == .right {
		placement.column + placement.column_span - 1
	} else {
		placement.column
	}
	column_edge_participates := side == .left || side == .right || (side == .top && placement.row == 0) || (side == .bottom && placement.row + placement.row_span == rows.len)
	if column_edge_participates {
		if definition := column_definitions_by_index[column_index] {
			winner = winning_table_border(winner, table_border_candidate(definition.node, side, .column, none, definition.index))
			if parent := definition.node.parent() {
				if parent.display().is_table_column_group() {
					winner = winning_table_border(winner, table_border_candidate(parent, side, .column_group, none, definition.index))
				}
			}
		}
	}
	if side == .left && placement.column > 0 {
		if definition := column_definitions_by_index[placement.column - 1] {
			winner = winning_table_border(winner, table_border_candidate(definition.node, .right, .column, none, definition.index))
		}
	} else if side == .right && placement.column + placement.column_span < column_count {
		if definition := column_definitions_by_index[placement.column + placement.column_span] {
			winner = winning_table_border(winner, table_border_candidate(definition.node, .left, .column, none, definition.index))
		}
	}

	if (side == .top && placement.row == 0) || (side == .bottom && placement.row + placement.row_span == rows.len) || (side == .left && placement.column == 0) || (side == .right && placement.column + placement.column_span == column_count) {
		winner = winning_table_border(winner, table_border_candidate(table, side, .table, none, none))
	}
	return winner
}

fn resolve_collapsed_table_borders(mut state LayoutState, table &Node, rows []&Node, placements []TableCellPlacement, column_definitions []TableColumnDefinition, column_count int) {
	collapsed := table.computed_values().border_collapse() == .collapse
	if table_styled := table.as_node_with_style() {
		mut table_state := state.get_mutable(table_styled)
		table_state.set_use_collapsing_borders_model(collapsed)
		table_state.set_is_collapsed_borders_table_box(collapsed)
	}
	// TableGrid::m_cells_by_coordinate provides constant-time neighboring-cell
	// lookup upstream. Preserve that complexity instead of rescanning every
	// placement for all four edges of every cell.
	mut placements_by_coordinate := map[u64]TableCellPlacement{}
	for placement in placements {
		placements_by_coordinate[table_placement_key(placement.row, placement.column)] = placement
	}
	row_groups_by_index := table_row_groups_by_index(rows)
	mut column_definitions_by_index := map[int]TableColumnDefinition{}
	for definition in column_definitions {
		for column in definition.index .. definition.index + definition.span {
			column_definitions_by_index[column] = definition
		}
	}
	// A collapsed table has no independently used border. Its four used
	// borders are the widest winning segments on the corresponding outside
	// edges of the grid. Start with the table candidate because it covers every
	// outer segment, including segments for which the grid has no originating
	// cell.
	mut outer_left := CSSPixels.nearest_value_for(table_border_candidate(table, .left, .table, none, none).border_data.width)
	mut outer_right := CSSPixels.nearest_value_for(table_border_candidate(table, .right, .table, none, none).border_data.width)
	mut outer_top := CSSPixels.nearest_value_for(table_border_candidate(table, .top, .table, none, none).border_data.width)
	mut outer_bottom := CSSPixels.nearest_value_for(table_border_candidate(table, .bottom, .table, none, none).border_data.width)
	for placement in placements {
		styled := placement.cell.as_node_with_style() or { continue }
		mut cell_state := state.get_mutable(styled)
		cell_state.set_use_collapsing_borders_model(collapsed)
		cell_state.set_is_collapsed_borders_table_box(false)
		cell_state.set_table_cell_coordinates(painting.TableCellCoordinates{
			row_index: placement.row
			column_index: placement.column
			row_span: placement.row_span
			column_span: placement.column_span
		})
		if !collapsed {
			cell_state.clear_override_borders_data()
			continue
		}
		left := resolved_collapsed_table_cell_border(table, rows, placements_by_coordinate, row_groups_by_index, column_definitions_by_index, column_count, placement, .left)
		right := resolved_collapsed_table_cell_border(table, rows, placements_by_coordinate, row_groups_by_index, column_definitions_by_index, column_count, placement, .right)
		top := resolved_collapsed_table_cell_border(table, rows, placements_by_coordinate, row_groups_by_index, column_definitions_by_index, column_count, placement, .top)
		bottom := resolved_collapsed_table_cell_border(table, rows, placements_by_coordinate, row_groups_by_index, column_definitions_by_index, column_count, placement, .bottom)
		left_width := CSSPixels.nearest_value_for(left.border_data.width)
		right_width := CSSPixels.nearest_value_for(right.border_data.width)
		top_width := CSSPixels.nearest_value_for(top.border_data.width)
		bottom_width := CSSPixels.nearest_value_for(bottom.border_data.width)
		cell_state.border_left = left_width
		cell_state.border_right = right_width
		cell_state.border_top = top_width
		cell_state.border_bottom = bottom_width
		if placement.column == 0 {
			outer_left = css_pixels_max(outer_left, left_width)
		}
		if placement.column + placement.column_span == column_count {
			outer_right = css_pixels_max(outer_right, right_width)
		}
		if placement.row == 0 {
			outer_top = css_pixels_max(outer_top, top_width)
		}
		if placement.row + placement.row_span == rows.len {
			outer_bottom = css_pixels_max(outer_bottom, bottom_width)
		}
		// Missing-cells fixup creates anonymous cells only to occupy empty grid
		// slots. No border belongs to such a box, so the real boxes on either
		// side of each grid line own the complete collapsed-border shares.
		if placement.cell.is_missing_table_cell() {
			cell_state.border_left = CSSPixels.new(0)
			cell_state.border_right = CSSPixels.new(0)
			cell_state.border_top = CSSPixels.new(0)
			cell_state.border_bottom = CSSPixels.new(0)
			cell_state.clear_override_borders_data()
			continue
		}
		cell_state.set_override_borders_data(painting.BordersDataWithElementKind{
			left: painting.BorderDataWithElementKind{left.border_data, left.element_kind}
			right: painting.BorderDataWithElementKind{right.border_data, right.element_kind}
			top: painting.BorderDataWithElementKind{top.border_data, top.element_kind}
			bottom: painting.BorderDataWithElementKind{bottom.border_data, bottom.element_kind}
		})
	}
	if collapsed {
		if table_styled := table.as_node_with_style() {
			mut table_state := state.get_mutable(table_styled)
			table_state.border_left = outer_left
			table_state.border_right = outer_right
			table_state.border_top = outer_top
			table_state.border_bottom = outer_bottom
			// CSS 2.2 collapsing borders give the table margins and a resolved
			// outer border, but no used padding.
			table_state.padding_left = CSSPixels.new(0)
			table_state.padding_right = CSSPixels.new(0)
			table_state.padding_top = CSSPixels.new(0)
			table_state.padding_bottom = CSSPixels.new(0)
		}
	}
}

fn initialize_trailing_table_whitespace_state(mut state LayoutState, node &Node) {
	for child in node.children() {
		initialize_trailing_table_whitespace_state(mut state, child)
	}
	parent := node.parent() or { return }
	if !is_trailing_whitespace_of_inline_table(node) || !ignorable_table_whitespace(node) || (!parent.display().is_table_inside() && !parent.display().is_table_row_group() && !parent.display().is_table_header_group() && !parent.display().is_table_footer_group() && !parent.display().is_table_row()) {
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

// CSS 2 lays out the first header group before all ordinary rows and the first
// footer group after them. Later header/footer groups retain tree order and are
// treated like ordinary row groups.
fn table_row_containers_in_layout_order(table &Node) []&Node {
	mut containers := []&Node{}
	mut header_index := -1
	mut footer_index := -1
	for child in table.children() {
		display := child.display()
		if !display.is_table_row() && !display.is_table_row_group()
			&& !display.is_table_header_group() && !display.is_table_footer_group() {
			continue
		}
		if header_index < 0 && display.is_table_header_group() {
			header_index = containers.len
		}
		if footer_index < 0 && display.is_table_footer_group() {
			footer_index = containers.len
		}
		containers << child
	}
	mut ordered := []&Node{cap: containers.len}
	if header_index >= 0 {
		ordered << containers[header_index]
	}
	for index, container in containers {
		if index != header_index && index != footer_index {
			ordered << container
		}
	}
	if footer_index >= 0 {
		ordered << containers[footer_index]
	}
	return ordered
}

fn collect_table_rows_in_layout_order(table &Node, mut rows []&Node) {
	for container in table_row_containers_in_layout_order(table) {
		if container.display().is_table_row() {
			rows << container
			continue
		}
		for child in container.children() {
			if child.display().is_table_row() {
				rows << child
			}
		}
	}
}

fn collect_typed_table_rows(table &Node, mut rows []&Node) {
	collect_table_rows_in_layout_order(table, mut rows)
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
				node: child
				index: index
				span: span
			}
			index += span
			continue
		}
		if !child.display().is_table_column_group() {
			continue
		}
		for column in child.children() {
			if !column.display().is_table_column() {
				continue
			}
			span := table_span(column, 'span')
			columns << TableColumnDefinition{
				node: column
				index: index
				span: span
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
			// TableGrid::calculate_row_column_grid() currently records a
			// rowspan="0" cell as a one-row cell. Its downward-growing-cell
			// step is still a FIXME upstream, so preserve that behavior rather
			// than implementing the specification ahead of the source.
			row_span := if authored_row_span == 0 { 1 } else { authored_row_span }
			placement := TableCellPlacement{
				cell: cell
				row: row_index
				column: column
				row_span: row_span
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

fn table_column_definition_is_collapsed(definition TableColumnDefinition) bool {
	if definition.node.computed_values().visibility() == .collapse {
		return true
	}
	parent := definition.node.parent() or { return false }
	return parent.display().is_table_column_group()
		&& parent.computed_values().visibility() == .collapse
}

fn table_visible_column_count(collapsed_columns []bool, column_count int) int {
	mut count := 0
	for index in 0 .. column_count {
		if index >= collapsed_columns.len || !collapsed_columns[index] {
			count++
		}
	}
	return count
}

fn table_visible_columns_in_range(collapsed_columns []bool, start int, end int) int {
	mut count := 0
	for index in start .. end {
		if index >= collapsed_columns.len || !collapsed_columns[index] {
			count++
		}
	}
	return count
}

// TableFormattingContext::position_cell_boxes() records each column's
// left_offset once. Keep the equivalent prefix array so cell measurement and
// final positioning do not repeatedly sum every preceding column.
fn table_column_offsets(widths []CSSPixels, spacing CSSPixels, collapsed_columns []bool) []CSSPixels {
	mut offsets := []CSSPixels{len: widths.len + 1}
	mut offset := spacing
	for index, width in widths {
		offsets[index] = offset
		if index >= collapsed_columns.len || !collapsed_columns[index] {
			offset = offset.plus(width).plus(spacing)
		}
	}
	offsets[widths.len] = offset
	return offsets
}

fn table_column_range_width(offsets []CSSPixels, start int, span int, spacing CSSPixels, collapsed_columns []bool) CSSPixels {
	if start < 0 || span <= 0 || start >= offsets.len - 1 {
		return CSSPixels.new(0)
	}
	end := if start + span < offsets.len { start + span } else { offsets.len - 1 }
	if table_visible_columns_in_range(collapsed_columns, start, end) == 0 {
		return CSSPixels.new(0)
	}
	return offsets[end].minus(offsets[start]).minus(spacing)
}

fn table_cell_physical_offset(table &Node, table_width CSSPixels, offsets []CSSPixels, placement TableCellPlacement, spacing CSSPixels, collapsed_columns []bool) CSSPixels {
	logical_offset := offsets[placement.column]
	if table.computed_values().direction() != .rtl {
		return logical_offset
	}
	cell_width := table_column_range_width(offsets, placement.column, placement.column_span, spacing, collapsed_columns)
	return table_width.minus(logical_offset).minus(cell_width)
}

fn table_column_box_geometry(table &Node, table_width CSSPixels, offsets []CSSPixels, start int, end int, spacing CSSPixels, collapsed_columns []bool) (CSSPixels, CSSPixels) {
	column_count := offsets.len - 1
	clamped_start := if start < 0 {
		0
	} else if start > column_count {
		column_count
	} else {
		start
	}
	clamped_end := if end < clamped_start {
		clamped_start
	} else if end > column_count {
		column_count
	} else {
		end
	}
	logical_offset := offsets[clamped_start]
	width := if clamped_end > clamped_start
		&& table_visible_columns_in_range(collapsed_columns, clamped_start, clamped_end) > 0 {
		offsets[clamped_end].minus(logical_offset).minus(spacing)
	} else {
		CSSPixels.new(0)
	}
	if table.computed_values().direction() != .rtl {
		return logical_offset, width
	}
	return table_width.minus(logical_offset).minus(width), width
}

fn position_table_column_box(mut state LayoutState, node &Node, containing &UsedValues, x CSSPixels, y CSSPixels, width CSSPixels, height CSSPixels) {
	styled := node.as_node_with_style() or { return }
	mut used := state.get_mutable(styled)
	used.set_containing_block_used_values(containing)
	used.set_content_offset(CSSPixelPoint.new(x, y))
	used.set_content_width(width)
	used.set_content_height(height)
}

// TableFormattingContext::position_column_boxes(). Column backgrounds are
// painted over the grid, so columns and column groups retain concrete boxes
// even though they do not participate in ordinary block layout. A column
// group is the containing block of its child columns.
fn position_table_column_boxes(mut state LayoutState, table &Node, table_state &UsedValues, column_offsets []CSSPixels, collapsed_columns []bool, rows []&Node, row_is_collapsed []bool, horizontal_spacing CSSPixels, vertical_spacing CSSPixels) {
	mut block_start := vertical_spacing
	if rows.len > 0 {
		if styled := rows[0].as_node_with_style() {
			block_start = state.get(styled).offset.y()
		}
	}
	mut block_end := block_start
	for index, row in rows {
		if index < row_is_collapsed.len && row_is_collapsed[index] {
			continue
		}
		styled := row.as_node_with_style() or { continue }
		row_used := state.get(styled)
		block_end = css_pixels_max(block_end, row_used.offset.y().plus(row_used.border_box_height()))
	}
	block_size := block_end.minus(block_start)

	mut column_index := 0
	for child in table.children() {
		if child.display().is_table_column() {
			end := column_index + table_span(child, 'span')
			x, width := table_column_box_geometry(table, table_state.content_width(), column_offsets,
				column_index, end, horizontal_spacing, collapsed_columns)
			position_table_column_box(mut state, child, table_state, x, block_start, width,
				block_size)
			column_index = end
			continue
		}
		if !child.display().is_table_column_group() {
			continue
		}

		group_start := column_index
		mut has_child_columns := false
		for column in child.children() {
			if !column.display().is_table_column() {
				continue
			}
			has_child_columns = true
			column_index += table_span(column, 'span')
		}
		group_end := column_index
		group_x, group_width := table_column_box_geometry(table, table_state.content_width(),
			column_offsets, group_start, group_end, horizontal_spacing, collapsed_columns)
		position_table_column_box(mut state, child, table_state, group_x, block_start,
			group_width, block_size)

		if !has_child_columns {
			continue
		}
		group_styled := child.as_node_with_style() or { continue }
		group_state := state.get(group_styled)
		mut child_index := group_start
		for column in child.children() {
			if !column.display().is_table_column() {
				continue
			}
			end := child_index + table_span(column, 'span')
			column_x, column_width := table_column_box_geometry(table,
				table_state.content_width(), column_offsets, child_index, end,
				horizontal_spacing, collapsed_columns)
			position_table_column_box(mut state, column, group_state,
				column_x.minus(group_x), CSSPixels.new(0), column_width, block_size)
			child_index = end
		}
	}
}

// TableFormattingContext::compute_table_measures<Column>(). Spanning cells are
// processed by increasing span, and every contribution for a span is derived
// from the previous span's measures before any column is committed.
fn compute_spanning_table_column_measures(mut min_widths []CSSPixels, mut max_widths []CSSPixels, placements []TableCellPlacement, cell_measures []TableCellIntrinsicWidthMeasures, spacing CSSPixels, maximum_span int, fixed_mode bool) {
	for current_span in 2 .. maximum_span + 1 {
		mut next_min_widths := min_widths.clone()
		mut next_max_widths := max_widths.clone()
		for placement_index, placement in placements {
			if placement.column_span != current_span || (fixed_mode && placement.row != 0) {
				continue
			}
			end_column := if placement.column + placement.column_span < min_widths.len {
				placement.column + placement.column_span
			} else {
				min_widths.len
			}
			mut baseline_min_content_size := CSSPixels.new(0)
			mut baseline_max_content_size := CSSPixels.new(0)
			for column in placement.column .. end_column {
				baseline_min_content_size = baseline_min_content_size.plus(min_widths[column])
				baseline_max_content_size = baseline_max_content_size.plus(max_widths[column])
			}
			baseline_border_spacing := spacing.scaled(f64(placement.column_span - 1))
			measures := cell_measures[placement_index]
			for column in placement.column .. end_column {
				mut min_contribution := min_widths[column]
				baseline_difference := baseline_max_content_size.minus(baseline_min_content_size)
				normalized_difference := if baseline_difference.raw_value() != 0 {
					max_widths[column].minus(min_widths[column]).to_double() / baseline_difference.to_double()
				} else {
					0.0
				}
				clamped_difference := css_pixels_min(css_pixels_max(measures.outer_min_width.minus(baseline_min_content_size).minus(baseline_border_spacing), CSSPixels.new(0)), baseline_difference)
				min_contribution = min_contribution.plus(clamped_difference.times_float(normalized_difference))
				if baseline_max_content_size.raw_value() != 0 {
					ratio := CSSPixels.nearest_value_for(max_widths[column].to_double() / baseline_max_content_size.to_double())
					extra := css_pixels_max(CSSPixels.new(0), measures.outer_min_width.minus(baseline_max_content_size).minus(baseline_border_spacing))
					min_contribution = min_contribution.plus(ratio.times(extra))
				} else {
					extra := css_pixels_max(CSSPixels.new(0), measures.outer_min_width.minus(baseline_border_spacing))
					min_contribution = min_contribution.plus(extra.divided_by(CSSPixels.new(placement.column_span)).to_css_pixels())
				}

				mut max_contribution := max_widths[column]
				if baseline_max_content_size.raw_value() != 0 {
					ratio := CSSPixels.nearest_value_for(max_widths[column].to_double() / baseline_max_content_size.to_double())
					extra := css_pixels_max(CSSPixels.new(0), measures.outer_max_width.minus(baseline_max_content_size).minus(baseline_border_spacing))
					max_contribution = max_contribution.plus(ratio.times(extra))
				} else {
					extra := css_pixels_max(CSSPixels.new(0), measures.outer_max_width.minus(baseline_border_spacing))
					max_contribution = max_contribution.plus(extra.divided_by(CSSPixels.new(placement.column_span)).to_css_pixels())
				}
				next_min_widths[column] = css_pixels_max(next_min_widths[column], min_contribution)
				next_max_widths[column] = css_pixels_max(next_max_widths[column], max_contribution)
			}
		}
		min_widths = next_min_widths.clone()
		max_widths = next_max_widths.clone()
	}
}

// TableFormattingContext::compute_table_measures<Row>(). This is intentionally
// the same span-by-span contribution algorithm as the column path, operating on
// the outer intrinsic heights measured for each cell.
fn compute_spanning_table_row_measures(mut min_heights []CSSPixels, mut max_heights []CSSPixels, placements []TableCellPlacement, cell_measures []TableCellIntrinsicHeightMeasures, spacing CSSPixels, maximum_span int) {
	for current_span in 2 .. maximum_span + 1 {
		mut next_min_heights := min_heights.clone()
		mut next_max_heights := max_heights.clone()
		for placement_index, placement in placements {
			if placement.row_span != current_span {
				continue
			}
			end_row := if placement.row + placement.row_span < min_heights.len {
				placement.row + placement.row_span
			} else {
				min_heights.len
			}
			mut baseline_min_content_size := CSSPixels.new(0)
			mut baseline_max_content_size := CSSPixels.new(0)
			for row in placement.row .. end_row {
				baseline_min_content_size = baseline_min_content_size.plus(min_heights[row])
				baseline_max_content_size = baseline_max_content_size.plus(max_heights[row])
			}
			baseline_border_spacing := spacing.scaled(f64(placement.row_span - 1))
			measures := cell_measures[placement_index]
			for row in placement.row .. end_row {
				mut min_contribution := min_heights[row]
				baseline_difference := baseline_max_content_size.minus(baseline_min_content_size)
				normalized_difference := if baseline_difference.raw_value() != 0 {
					max_heights[row].minus(min_heights[row]).to_double() / baseline_difference.to_double()
				} else {
					0.0
				}
				clamped_difference := css_pixels_min(css_pixels_max(measures.outer_min_height.minus(baseline_min_content_size).minus(baseline_border_spacing), CSSPixels.new(0)), baseline_difference)
				min_contribution = min_contribution.plus(clamped_difference.times_float(normalized_difference))
				if baseline_max_content_size.raw_value() != 0 {
					ratio := CSSPixels.nearest_value_for(max_heights[row].to_double() / baseline_max_content_size.to_double())
					extra := css_pixels_max(CSSPixels.new(0), measures.outer_min_height.minus(baseline_max_content_size).minus(baseline_border_spacing))
					min_contribution = min_contribution.plus(ratio.times(extra))
				} else {
					extra := css_pixels_max(CSSPixels.new(0), measures.outer_min_height.minus(baseline_border_spacing))
					min_contribution = min_contribution.plus(extra.divided_by(CSSPixels.new(placement.row_span)).to_css_pixels())
				}

				mut max_contribution := max_heights[row]
				if baseline_max_content_size.raw_value() != 0 {
					ratio := CSSPixels.nearest_value_for(max_heights[row].to_double() / baseline_max_content_size.to_double())
					extra := css_pixels_max(CSSPixels.new(0), measures.outer_max_height.minus(baseline_max_content_size).minus(baseline_border_spacing))
					max_contribution = max_contribution.plus(ratio.times(extra))
				} else {
					extra := css_pixels_max(CSSPixels.new(0), measures.outer_max_height.minus(baseline_border_spacing))
					max_contribution = max_contribution.plus(extra.divided_by(CSSPixels.new(placement.row_span)).to_css_pixels())
				}
				next_min_heights[row] = css_pixels_max(next_min_heights[row], min_contribution)
				next_max_heights[row] = css_pixels_max(next_max_heights[row], max_contribution)
			}
		}
		min_heights = next_min_heights.clone()
		max_heights = next_max_heights.clone()
	}
}

fn table_cell_intrinsic_percentage_contribution(cell &Node) f64 {
	computed := cell.computed_values()
	width_percentage := if computed.size_value(.width).is_percentage() {
		computed.size_value(.width).percentage().value()
	} else {
		0.0
	}
	max_width_percentage := if computed.size_value(.max_width).is_percentage() {
		computed.size_value(.max_width).percentage().value()
	} else {
		math.inf(1)
	}
	return math.min(width_percentage, max_width_percentage)
}

// TableFormattingContext::compute_intrinsic_percentage<Column>().
fn compute_table_column_intrinsic_percentages(column_count int, column_definitions []TableColumnDefinition, placements []TableCellPlacement, cell_measures []TableCellIntrinsicWidthMeasures, nonspanning_max_widths []CSSPixels, maximum_span int, fixed_mode bool) ([]f64, []bool, []CSSPixels, []bool) {
	mut intrinsic_percentages := []f64{len: column_count}
	mut has_intrinsic_percentage := []bool{len: column_count}
	mut percentage_offsets := []CSSPixels{len: column_count, init: CSSPixels.new(0)}
	mut has_originating_cells := []bool{len: column_count}
	for definition in column_definitions {
		if definition.index >= column_count {
			continue
		}
		computed := definition.node.computed_values()
		width_percentage := if computed.size_value(.width).is_percentage() {
			computed.size_value(.width).percentage().value()
		} else {
			0.0
		}
		max_width_percentage := if computed.size_value(.max_width).is_percentage() {
			computed.size_value(.max_width).percentage().value()
		} else {
			math.inf(1)
		}
		has_intrinsic_percentage[definition.index] = computed.size_value(.width).is_percentage() || computed.size_value(.max_width).is_percentage()
		intrinsic_percentages[definition.index] = math.min(width_percentage, max_width_percentage)
	}
	for placement_index, placement in placements {
		if placement.column < column_count {
			has_originating_cells[placement.column] = true
		}
		if fixed_mode && placement.row != 0 {
			continue
		}
		if !placement.cell.computed_values().size_value(.width).is_percentage() {
			continue
		}
		end_column := if placement.column + placement.column_span < column_count {
			placement.column + placement.column_span
		} else {
			column_count
		}
		for column in placement.column .. end_column {
			has_intrinsic_percentage[column] = true
		}
		if placement.column_span == 1 && placement.column < column_count {
			percentage := table_cell_intrinsic_percentage_contribution(placement.cell)
			if percentage >= intrinsic_percentages[placement.column] {
				intrinsic_percentages[placement.column] = percentage
				if fixed_mode {
					percentage_offsets[placement.column] = cell_measures[placement_index].outer_min_width
				}
			}
		}
	}
	for current_span in 2 .. maximum_span + 1 {
		mut next_percentages := intrinsic_percentages.clone()
		for placement in placements {
			if placement.column_span != current_span || (fixed_mode && placement.row != 0) {
				continue
			}
			end_column := if placement.column + placement.column_span < column_count {
				placement.column + placement.column_span
			} else {
				column_count
			}
			mut cell_contribution := CSSPixels.nearest_value_for(table_cell_intrinsic_percentage_contribution(placement.cell))
			for column in placement.column .. end_column {
				cell_contribution = css_pixels_max(CSSPixels.new(0), cell_contribution.minus(CSSPixels.nearest_value_for(intrinsic_percentages[column])))
			}
			mut zero_percentage_max_sum := CSSPixels.new(0)
			mut zero_percentage_count := 0
			for column in placement.column .. end_column {
				if intrinsic_percentages[column] == 0 {
					zero_percentage_max_sum = zero_percentage_max_sum.plus(nonspanning_max_widths[column])
					zero_percentage_count++
				}
			}
			for column in placement.column .. end_column {
				if intrinsic_percentages[column] > 0 {
					continue
				}
				adjusted := if zero_percentage_max_sum.raw_value() != 0 {
					cell_contribution.times_float(nonspanning_max_widths[column].to_double() / zero_percentage_max_sum.to_double())
				} else if zero_percentage_count > 0 {
					cell_contribution.divided_by(CSSPixels.new(zero_percentage_count)).to_css_pixels()
				} else {
					CSSPixels.new(0)
				}
				next_percentages[column] = math.max(next_percentages[column], adjusted.to_double())
			}
		}
		intrinsic_percentages = next_percentages.clone()
	}
	mut total_intrinsic_percentage := 0.0
	for index in 0 .. intrinsic_percentages.len {
		intrinsic_percentages[index] = math.max(math.min(100.0 - total_intrinsic_percentage, intrinsic_percentages[index]), 0.0)
		total_intrinsic_percentage += intrinsic_percentages[index]
	}
	return intrinsic_percentages, has_intrinsic_percentage, percentage_offsets, has_originating_cells
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
		widths[index] = CSSPixels.nearest_value_for(candidate_weight * candidate_widths[index].to_double() + (1.0 - candidate_weight) * widths[index].to_double())
	}
}

fn distribute_table_excess_width_equally(mut widths []CSSPixels, eligible []bool, excess CSSPixels) bool {
	mut count := 0
	for value in eligible {
		if value {
			count++
		}
	}
	if count == 0 {
		return false
	}
	// In C++, `CSSPixels / size_t` produces a CSSPixelFraction and converting
	// that fraction back to CSSPixels truncates the fixed-point quotient. Do not
	// use divided_by_float() here: that rounds to nearest and can make the sum of
	// the column widths exceed the table width by one raw unit per column.
	addition := excess.divided_by(CSSPixels.new(count)).to_css_pixels()
	for index in 0 .. widths.len {
		if eligible[index] {
			widths[index] = widths[index].plus(addition)
		}
	}
	return true
}

fn distribute_table_excess_width_proportionally(mut widths []CSSPixels, eligible []bool, base_widths []CSSPixels, excess CSSPixels) bool {
	mut total_base_width := CSSPixels.new(0)
	mut found := false
	for index in 0 .. widths.len {
		if eligible[index] {
			found = true
			total_base_width = total_base_width.plus(base_widths[index])
		}
	}
	if !found || total_base_width.raw_value() <= 0 {
		return false
	}
	for index in 0 .. widths.len {
		if eligible[index] {
			widths[index] = widths[index].plus(excess.times_float(base_widths[index].to_double() / total_base_width.to_double()))
		}
	}
	return true
}

fn distribute_table_excess_width_by_percentage(mut widths []CSSPixels, eligible []bool, intrinsic_percentages []f64, excess CSSPixels) bool {
	mut total_percentage := 0.0
	mut found := false
	for index in 0 .. widths.len {
		if eligible[index] {
			found = true
			total_percentage += intrinsic_percentages[index]
		}
	}
	if !found || total_percentage <= 0 {
		return false
	}
	for index in 0 .. widths.len {
		if eligible[index] {
			widths[index] = widths[index].plus(excess.times_float(intrinsic_percentages[index] / total_percentage))
		}
	}
	return true
}

// TableFormattingContext::distribute_width_to_columns() and
// distribute_excess_width_to_columns().
fn distribute_table_width_to_columns(min_widths []CSSPixels, max_widths []CSSPixels, constrained_columns []bool, intrinsic_percentages []f64, has_intrinsic_percentage []bool, percentage_offsets []CSSPixels, has_originating_cells []bool, table_width CSSPixels, spacing CSSPixels, fixed_mode bool) []CSSPixels {
	available_width := table_width.minus(spacing.scaled(f64(min_widths.len + 1)))
	mut widths := []CSSPixels{len: min_widths.len, init: CSSPixels.new(0)}
	mut candidate_widths := []CSSPixels{len: min_widths.len, init: CSSPixels.new(0)}
	for index in 0 .. widths.len {
		if !fixed_mode || constrained_columns[index] {
			widths[index] = min_widths[index]
			candidate_widths[index] = min_widths[index]
		}
	}
	for index in 0 .. widths.len {
		if has_intrinsic_percentage[index] {
			candidate_widths[index] = css_pixels_max(min_widths[index], CSSPixels.nearest_value_for(intrinsic_percentages[index] / 100.0 * available_width.to_double()).plus(percentage_offsets[index]))
		}
	}
	if available_width.raw_value() < table_columns_total_width(candidate_widths).raw_value() {
		assign_table_column_widths_linear_combination(mut widths, candidate_widths, available_width)
		return widths
	}
	widths = candidate_widths.clone()
	for index in 0 .. widths.len {
		if constrained_columns[index] {
			candidate_widths[index] = max_widths[index]
		}
	}
	if available_width.raw_value() < table_columns_total_width(candidate_widths).raw_value() {
		assign_table_column_widths_linear_combination(mut widths, candidate_widths, available_width)
		return widths
	}
	widths = candidate_widths.clone()
	for index in 0 .. widths.len {
		if !has_intrinsic_percentage[index] {
			candidate_widths[index] = max_widths[index]
		}
	}
	if available_width.raw_value() < table_columns_total_width(candidate_widths).raw_value() {
		assign_table_column_widths_linear_combination(mut widths, candidate_widths, available_width)
		return widths
	}
	widths = candidate_widths.clone()
	mut excess := available_width.minus(table_columns_total_width(widths))
	if excess.raw_value() <= 0 {
		return widths
	}
	mut eligible := []bool{len: widths.len}
	if fixed_mode {
		for index in 0 .. widths.len {
			eligible[index] = !constrained_columns[index] && !has_intrinsic_percentage[index]
		}
		if distribute_table_excess_width_equally(mut widths, eligible, excess) {
			return widths
		}
		for index in 0 .. widths.len {
			eligible[index] = widths[index].raw_value() > 0
		}
		if distribute_table_excess_width_proportionally(mut widths, eligible, widths.clone(), excess) {
			return widths
		}
		for index in 0 .. widths.len {
			eligible[index] = intrinsic_percentages[index] > 0
		}
		if distribute_table_excess_width_by_percentage(mut widths, eligible, intrinsic_percentages, excess) {
			return widths
		}
		for index in 0 .. widths.len {
			eligible[index] = widths[index].raw_value() == 0
		}
		distribute_table_excess_width_equally(mut widths, eligible, excess)
		return widths
	}

	for index in 0 .. widths.len {
		eligible[index] = !constrained_columns[index] && has_originating_cells[index] && intrinsic_percentages[index] == 0 && max_widths[index].raw_value() > 0
	}
	if distribute_table_excess_width_proportionally(mut widths, eligible, max_widths, excess) {
		excess = available_width.minus(table_columns_total_width(widths))
		if excess.raw_value() <= 0 {
			return widths
		}
	}
	for index in 0 .. widths.len {
		eligible[index] = !constrained_columns[index] && has_originating_cells[index] && intrinsic_percentages[index] == 0
	}
	if distribute_table_excess_width_equally(mut widths, eligible, excess) {
		excess = available_width.minus(table_columns_total_width(widths))
		if excess.raw_value() <= 0 {
			return widths
		}
	}
	for index in 0 .. widths.len {
		eligible[index] = constrained_columns[index] && intrinsic_percentages[index] == 0 && max_widths[index].raw_value() > 0
	}
	if distribute_table_excess_width_proportionally(mut widths, eligible, max_widths, excess) {
		excess = available_width.minus(table_columns_total_width(widths))
		if excess.raw_value() <= 0 {
			return widths
		}
	}
	for index in 0 .. widths.len {
		eligible[index] = intrinsic_percentages[index] > 0
	}
	if distribute_table_excess_width_by_percentage(mut widths, eligible, intrinsic_percentages, excess) {
		excess = available_width.minus(table_columns_total_width(widths))
		if excess.raw_value() <= 0 {
			return widths
		}
	}
	for index in 0 .. widths.len {
		eligible[index] = has_originating_cells[index]
	}
	if distribute_table_excess_width_equally(mut widths, eligible, excess) {
		excess = available_width.minus(table_columns_total_width(widths))
		if excess.raw_value() <= 0 {
			return widths
		}
	}
	for index in 0 .. widths.len {
		eligible[index] = true
	}
	distribute_table_excess_width_equally(mut widths, eligible, excess)
	return widths
}

fn table_cell_measurement_inline_edges(values UsedValues, collapsed bool) CSSPixels {
	left_border := if collapsed {
		collapsed_border_part_after_line(values.border_left)
	} else {
		values.border_left
	}
	right_border := if collapsed {
		collapsed_border_part_before_line(values.border_right)
	} else {
		values.border_right
	}
	return left_border.plus(values.padding_left).plus(values.padding_right).plus(right_border)
}

fn table_cell_measurement_block_edges(values UsedValues, collapsed bool) CSSPixels {
	top_border := if collapsed {
		collapsed_border_part_after_line(values.border_top)
	} else {
		values.border_top
	}
	bottom_border := if collapsed {
		collapsed_border_part_before_line(values.border_bottom)
	} else {
		values.border_bottom
	}
	return top_border.plus(values.padding_top).plus(values.padding_bottom).plus(bottom_border)
}

fn table_cell_measurement_outer_height(values UsedValues, collapsed bool) CSSPixels {
	return values.content_height().plus(table_cell_measurement_block_edges(values, collapsed))
}

fn table_cell_content_offset_left(values UsedValues, collapsed bool) CSSPixels {
	border := if collapsed {
		collapsed_border_part_after_line(values.border_left)
	} else {
		values.border_left
	}
	return border.plus(values.padding_left)
}

fn table_cell_content_offset_top(values UsedValues, collapsed bool) CSSPixels {
	border := if collapsed {
		collapsed_border_part_after_line(values.border_top)
	} else {
		values.border_top
	}
	return border.plus(values.padding_top)
}

// Return the first in-flow content baseline relative to a box's content edge.
// Table cells use this instead of the generic atomic-inline baseline, which is
// affected by the cell's own vertical-align and selects the last line.
fn table_first_in_flow_content_baseline(state &LayoutState, box &Node) ?CSSPixels {
	styled := box.as_node_with_style() or { return none }
	values := state.try_get(styled) or { return none }
	if values.line_boxes.len > 0 {
		line := values.line_boxes.first()
		line_top := line.bottom().minus(line.block_length())
		return line_top.plus(line.baseline())
	}
	for child in box.children() {
		if !child.is_box() || child.is_out_of_flow() {
			continue
		}
		child_styled := child.as_node_with_style() or { continue }
		child_values := state.try_get(child_styled) or { continue }
		if baseline := child_values.derived_first_baseline() {
			return child_values.offset.y().plus(baseline)
		}
		if baseline := table_first_in_flow_content_baseline(state, child) {
			return child_values.offset.y().plus(baseline)
		}
	}
	return none
}

// CSS 2.2 17.5.3: a cell uses its first in-flow line/table-row baseline, or
// the bottom content edge when it has no such descendant.
fn table_cell_baseline(state &LayoutState, cell &Node, values &UsedValues, collapsed bool) CSSPixels {
	content_baseline := table_first_in_flow_content_baseline(state, cell) or {
		values.content_height()
	}
	return table_cell_content_offset_top(*values, collapsed).plus(content_baseline)
}

fn table_cell_is_baseline_aligned(cell &Node) bool {
	computed := cell.computed_values()
	if computed.vertical_align_length_percentage() != none {
		return true
	}
	return computed.vertical_align() !in [.top, .middle, .bottom]
}

fn table_row_derived_baseline(index int, row_heights []CSSPixels, row_baselines []CSSPixels, row_has_baseline []bool, row_smallest_cell_end_offset []CSSPixels, row_has_cell []bool) CSSPixels {
	if index < row_has_baseline.len && row_has_baseline[index] {
		return row_baselines[index]
	}
	if index < row_has_cell.len && row_has_cell[index] {
		return css_pixels_max(row_heights[index].minus(row_smallest_cell_end_offset[index]), CSSPixels.new(0))
	}
	return CSSPixels.new(0)
}

// A baseline-aligned cell whose baseline lies above the row baseline is moved
// down to it. Grow the row far enough to retain the largest descent below that
// shared baseline instead of giving the shifted cell negative bottom padding.
fn grow_table_rows_to_baseline_aligned_cells(mut heights []CSSPixels, row_baselines []CSSPixels,
	row_has_baseline []bool, row_max_cell_descent []CSSPixels, row_is_collapsed []bool) {
	for index in 0 .. heights.len {
		if index < row_is_collapsed.len && row_is_collapsed[index] {
			continue
		}
		if index < row_has_baseline.len && row_has_baseline[index] {
			reach := row_baselines[index].plus(row_max_cell_descent[index])
			heights[index] = css_pixels_max(heights[index], reach)
		}
	}
}

fn store_table_part_baselines(mut state LayoutState, table &Node, table_state &UsedValues, rows []&Node, row_offsets []CSSPixels, row_heights []CSSPixels, row_baselines []CSSPixels, row_has_baseline []bool, row_smallest_cell_end_offset []CSSPixels, row_has_cell []bool, row_is_collapsed []bool) {
	mut first_visible_row := -1
	mut last_visible_row := -1
	for index, row in rows {
		baseline := table_row_derived_baseline(index, row_heights, row_baselines,
			row_has_baseline, row_smallest_cell_end_offset, row_has_cell)
		if styled := row.as_node_with_style() {
			mut row_values := state.get_mutable(styled)
			row_values.set_derived_baselines(baseline, baseline)
		}
		if index >= row_is_collapsed.len || !row_is_collapsed[index] {
			if first_visible_row < 0 {
				first_visible_row = index
			}
			last_visible_row = index
		}
	}

	for group in table_row_containers_in_layout_order(table) {
		if !group.display().is_table_row_group() && !group.display().is_table_header_group()
			&& !group.display().is_table_footer_group() {
			continue
		}
		group_styled := group.as_node_with_style() or { continue }
		mut group_values := state.get_mutable(group_styled)
		mut first := ?CSSPixels(none)
		mut last := ?CSSPixels(none)
		for index, row in rows {
			if index < row_is_collapsed.len && row_is_collapsed[index] {
				continue
			}
			parent := row.parent() or { continue }
			if !layout_nodes_same(parent, group) {
				continue
			}
			baseline := row_offsets[index].plus(table_row_derived_baseline(index,
				row_heights, row_baselines, row_has_baseline,
				row_smallest_cell_end_offset, row_has_cell)).minus(group_values.offset.y())
			if first == none {
				first = baseline
			}
			last = baseline
		}
		group_values.set_derived_baselines(first, last)
	}

	mut table_first := ?CSSPixels(none)
	mut table_last := ?CSSPixels(none)
	if first_visible_row >= 0 {
		table_first = row_offsets[first_visible_row].plus(table_row_derived_baseline(first_visible_row, row_heights, row_baselines, row_has_baseline,
			row_smallest_cell_end_offset, row_has_cell))
		table_last = row_offsets[last_visible_row].plus(table_row_derived_baseline(last_visible_row, row_heights, row_baselines, row_has_baseline,
			row_smallest_cell_end_offset, row_has_cell))
	}
	mut mutable_table_state := unsafe { &UsedValues(table_state) }
	mutable_table_state.set_derived_baselines(table_first, table_last)
	if wrapper_values := table_state.containing_block_used_values() {
		mut wrapper_state := unsafe { &UsedValues(wrapper_values) }
		wrapper_first := if baseline := table_first {
			?CSSPixels(table_state.offset.y().plus(baseline))
		} else {
			?CSSPixels(none)
		}
		wrapper_last := if baseline := table_last {
			?CSSPixels(table_state.offset.y().plus(baseline))
		} else {
			?CSSPixels(none)
		}
		wrapper_state.set_derived_baselines(wrapper_first, wrapper_last)
	}
}

// A cell occupies exactly the columns it spans. Fixed layout can make those
// columns narrower than an auto-width cell's padding and borders, so reduce the
// end padding, start padding, end border, and start border in that order until
// the cell's painted border box fits the assigned inline size.
fn shrink_table_cell_inline_offsets_to_fit(mut values UsedValues, collapsed bool, inline_size CSSPixels) {
	zero := CSSPixels.new(0)
	mut excess := values.border_box_left().plus(values.border_box_right()).minus(inline_size)
	mut reduction := css_pixels_min(css_pixels_max(excess, zero), values.padding_right)
	values.padding_right = values.padding_right.minus(reduction)
	excess = values.border_box_left().plus(values.border_box_right()).minus(inline_size)
	reduction = css_pixels_min(css_pixels_max(excess, zero), values.padding_left)
	values.padding_left = values.padding_left.minus(reduction)

	for is_start_side in [false, true] {
		excess = values.border_box_left().plus(values.border_box_right()).minus(inline_size)
		if excess.raw_value() <= 0 {
			return
		}
		share := if is_start_side {
			values.border_left_collapsed()
		} else {
			values.border_right_collapsed()
		}
		allowed := css_pixels_max(share.minus(excess), zero)
		mut width := if collapsed { allowed.scaled(2.0) } else { allowed }
		if is_start_side {
			values.border_left = width
		} else {
			values.border_right = width
		}
		for width.raw_value() > 0 {
			current_share := if is_start_side {
				values.border_left_collapsed()
			} else {
				values.border_right_collapsed()
			}
			if current_share.raw_value() <= allowed.raw_value() {
				break
			}
			width = css_pixels_max(width.minus(CSSPixels.new(1)), zero)
			if is_start_side {
				values.border_left = width
			} else {
				values.border_right = width
			}
		}
	}
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

fn table_uses_fixed_mode_layout(table &Node) bool {
	width := table.computed_values().size_value(.width)
	return table.computed_values().table_layout() == .fixed && (width.is_length() || width.is_percentage() || width.is_min_content() || width.is_fit_content())
}

fn table_cell_intrinsic_width_measures(mut state LayoutState, cell &Node, collapsed bool, column_is_constrained bool, fixed_mode bool, percentage_basis CSSPixels) TableCellIntrinsicWidthMeasures {
	box := cell.as_box() or { return TableCellIntrinsicWidthMeasures{} }
	// Anonymous table cells are created after their descendants have already
	// participated in table fixup. Measure their current subtree directly so a
	// pre-fixup intrinsic cache cannot hide floats wrapped by that cell.
	styled := cell.as_node_with_style() or { return TableCellIntrinsicWidthMeasures{} }
	mut values := state.get_mutable(styled)
	winning_left := values.border_left
	winning_right := values.border_right
	winning_top := values.border_top
	winning_bottom := values.border_bottom
	resolve_box_model_edges(styled.computed_values(), mut values, percentage_basis.to_double())
	if collapsed {
		values.border_left = winning_left
		values.border_right = winning_right
		values.border_top = winning_top
		values.border_bottom = winning_bottom
	}
	computed := cell.computed_values()
	edges := table_cell_measurement_inline_edges(values, collapsed)
	mut min_width := computed.size_value(.min_width).to_px(layout_length_resolution_context(cell), percentage_basis)
	mut width := if computed.size_value(.width).is_length() {
		computed.size_value(.width).to_px(layout_length_resolution_context(cell), percentage_basis)
	} else {
		CSSPixels.new(0)
	}
	mut max_width := if computed.size_value(.max_width).is_length() {
		computed.size_value(.max_width).to_px(layout_length_resolution_context(cell), percentage_basis)
	} else {
		CSSPixels.max()
	}
	if computed.box_sizing() == .border_box {
		min_width = css_pixels_max(CSSPixels.new(0), min_width.minus(edges))
		width = css_pixels_max(CSSPixels.new(0), width.minus(edges))
		if max_width.raw_value() != CSSPixels.max().raw_value() {
			max_width = css_pixels_max(CSSPixels.new(0), max_width.minus(edges))
		}
	}
	if fixed_mode && !computed.size_value(.width).is_length() {
		// Fixed layout treats auto and percentage columns as having zero
		// min-content size. Content-box percentage cells retain only their
		// padding/border offsets, which distribution adds to the percentage.
		outer := if computed.size_value(.width).is_percentage()
			&& computed.box_sizing() != .border_box {
			edges
		} else {
			CSSPixels.new(0)
		}
		return TableCellIntrinsicWidthMeasures{
			outer_min_width: outer
			outer_max_width: outer
		}
	}
	min_content_width := if fixed_mode {
		width
	} else {
		calculate_min_content_width(mut state, box)
	}
	max_content_width := if fixed_mode {
		width
	} else {
		calculate_max_content_width(mut state, box)
	}
	width_is_specified_length_or_percentage := computed.size_value(.width).is_length() || computed.size_value(.width).is_percentage()
	mut outer_min_width := CSSPixels.new(0)
	mut outer_max_width := CSSPixels.new(0)
	if !fixed_mode || width_is_specified_length_or_percentage {
		outer_min_width = css_pixels_max(min_width, min_content_width).plus(edges)
		if column_is_constrained {
			outer_max_width = css_pixels_max(min_width, css_pixels_max(width, min_content_width)).plus(edges)
		} else {
			outer_max_width = css_pixels_max(min_width, css_pixels_max(width, css_pixels_max(min_content_width, css_pixels_min(max_width, max_content_width)))).plus(edges)
		}
	}
	return TableCellIntrinsicWidthMeasures{
		outer_min_width: outer_min_width
		outer_max_width: outer_max_width
	}
}

fn table_cell_intrinsic_height_measures(mut state LayoutState, cell &Node, collapsed bool, row_is_constrained bool, containing_block_height CSSPixels) TableCellIntrinsicHeightMeasures {
	box := cell.as_box() or { return TableCellIntrinsicHeightMeasures{} }
	styled := cell.as_node_with_style() or { return TableCellIntrinsicHeightMeasures{} }
	computed := cell.computed_values()
	mut measurement := UsedValues{}
	resolve_box_model_edges(computed, mut measurement, containing_block_height.to_double())
	if collapsed {
		cell_state := state.get(styled)
		measurement.border_top = cell_state.border_top
		measurement.border_bottom = cell_state.border_bottom
	}
	min_content_width := calculate_min_content_width(mut state, box)
	max_content_width := calculate_max_content_width(mut state, box)
	min_content_height := calculate_min_content_height(mut state, box, max_content_width)
	max_content_height := calculate_max_content_height(mut state, box, min_content_width)
	edges := table_cell_measurement_block_edges(measurement, collapsed)
	mut min_height := computed.size_value(.min_height).to_px(layout_length_resolution_context(cell), containing_block_height)
	if computed.box_sizing() == .border_box {
		min_height = css_pixels_max(CSSPixels.new(0), min_height.minus(edges))
	}
	specified_height := if computed.size_value(.height).is_auto() {
		CSSPixels.new(0)
	} else {
		table_cell_specified_outer_height(cell, computed.size_value(.height).to_px(layout_length_resolution_context(cell), containing_block_height), edges)
	}
	height := if computed.size_value(.height).is_length() {
		css_pixels_max(CSSPixels.new(0), specified_height.minus(edges))
	} else {
		CSSPixels.new(0)
	}
	mut max_height := if computed.size_value(.max_height).is_length() {
		computed.size_value(.max_height).to_px(layout_length_resolution_context(cell), containing_block_height)
	} else {
		CSSPixels.max()
	}
	if computed.box_sizing() == .border_box && max_height.raw_value() != CSSPixels.max().raw_value() {
		max_height = css_pixels_max(CSSPixels.new(0), max_height.minus(edges))
	}
	outer_min_height := css_pixels_max(min_height, min_content_height).plus(edges)
	outer_max_height := if row_is_constrained {
		css_pixels_max(min_height, css_pixels_max(height, min_content_height)).plus(edges)
	} else {
		css_pixels_max(min_height, css_pixels_max(height, css_pixels_max(min_content_height, css_pixels_min(max_height, max_content_height)))).plus(edges)
	}
	return TableCellIntrinsicHeightMeasures{
		outer_min_height:       outer_min_height
		outer_max_height:       outer_max_height
		outer_specified_height: specified_height
	}
}

// CSS 2.2 sizes a row from the computed height of each cell. That height is a
// content-box size in standards mode, except when box-sizing:border-box asks
// for the border box explicitly. Quirks mode retains its legacy border-box
// interpretation.
fn table_cell_specified_outer_height(cell &Node, specified CSSPixels, block_edges CSSPixels) CSSPixels {
	if cell.computed_values().box_sizing() == .border_box || cell.document().in_quirks_mode() {
		return specified
	}
	return specified.plus(block_edges)
}

fn compute_table_row_intrinsic_measures(mut state LayoutState, rows []&Node, placements []TableCellPlacement, collapsed bool, containing_block_height CSSPixels, spacing CSSPixels) ([]CSSPixels, []CSSPixels) {
	mut min_heights := []CSSPixels{len: rows.len, init: CSSPixels.new(0)}
	mut max_heights := []CSSPixels{len: rows.len, init: CSSPixels.new(0)}
	mut constrained_rows := []bool{len: rows.len}
	for index, row in rows {
		computed := row.computed_values()
		min_height := computed.size_value(.min_height).to_px(layout_length_resolution_context(row), containing_block_height)
		height := computed.size_value(.height).to_px(layout_length_resolution_context(row), containing_block_height)
		max_height := if computed.size_value(.max_height).is_length() {
			computed.size_value(.max_height).to_px(layout_length_resolution_context(row), containing_block_height)
		} else {
			CSSPixels.max()
		}
		min_heights[index] = css_pixels_max(min_height, height)
		max_heights[index] = css_pixels_max(min_height, css_pixels_min(max_height, height))
		constrained_rows[index] = computed.size_value(.height).is_length()
	}
	for placement in placements {
		if placement.row < constrained_rows.len
			&& placement.cell.computed_values().size_value(.height).is_length() {
			constrained_rows[placement.row] = true
		}
	}
	mut cell_measures := []TableCellIntrinsicHeightMeasures{cap: placements.len}
	for placement in placements {
		cell_measures << table_cell_intrinsic_height_measures(mut state, placement.cell, collapsed, constrained_rows[placement.row], containing_block_height)
	}
	for placement_index, placement in placements {
		if placement.row_span != 1 || placement.row >= min_heights.len {
			continue
		}
		measures := cell_measures[placement_index]
		min_heights[placement.row] = css_pixels_max(min_heights[placement.row], css_pixels_max(measures.outer_min_height, measures.outer_specified_height))
		max_heights[placement.row] = css_pixels_max(max_heights[placement.row], measures.outer_max_height)
	}
	mut maximum_span := 1
	for placement in placements {
		if placement.row_span > maximum_span {
			maximum_span = placement.row_span
		}
	}
	compute_spanning_table_row_measures(mut min_heights, mut max_heights, placements, cell_measures, spacing, maximum_span)
	return min_heights, max_heights
}

// The anonymous table wrapper's used width is the table grid's intrinsic
// width, not the fill-available width of an ordinary block. This is the width
// phase of TableFormattingContext::run_until_width_calculation().
fn cached_table_grid_intrinsic_widths(table &Node, percentage_basis CSSPixels) ?&TableGridIntrinsicWidths {
	table_box := table.as_box() or { return none }
	mut mutable_table_box := unsafe { &Box(table_box) }
	cache := mutable_table_box.cached_intrinsic_sizes()
	widths := cache.table_grid_width_measures or { return none }
	if widths.percentage_basis.raw_value() != percentage_basis.raw_value() {
		return none
	}
	return widths
}

fn calculate_table_caption_minimum_width(mut state LayoutState, table &Node, containing_width CSSPixels) CSSPixels {
	mut capmin := CSSPixels.new(0)
	for child in table.children() {
		if !child.display().is_table_caption() {
			continue
		}
		caption := child.as_box() or { continue }
		styled := child.as_node_with_style() or { continue }
		mut caption_state := state.get_mutable(styled)
		resolve_box_model_edges(styled.computed_values(), mut caption_state, containing_width.to_double())
		edges := flex_or_grid_item_outer_inline_edges(caption_state)
		mut contribution := calculate_min_content_width(mut state, caption).plus(edges)
		preferred_width := styled.computed_values().size_value(.width)
		if preferred_width.is_length_percentage() && !preferred_width.contains_percentage() {
			mut preferred_inner_width := preferred_width.to_px(layout_length_resolution_context(child),
				containing_width)
			if styled.computed_values().box_sizing() == .border_box {
				border_padding := caption_state.border_left.plus(caption_state.padding_left).plus(caption_state.padding_right).plus(caption_state.border_right)
				preferred_inner_width = css_pixels_max(CSSPixels.new(0), preferred_inner_width.minus(border_padding))
			}
			contribution = css_pixels_max(contribution, preferred_inner_width.plus(edges))
		} else if preferred_width.is_max_content() {
			contribution = css_pixels_max(contribution, calculate_max_content_width(mut state,
				caption).plus(edges))
		}
		capmin = css_pixels_max(capmin, contribution)
	}
	return capmin
}

fn calculate_table_grid_intrinsic_widths(mut state LayoutState, table &Node, percentage_basis CSSPixels) &TableGridIntrinsicWidths {
	if cached := cached_table_grid_intrinsic_widths(table, percentage_basis) {
		// Intrinsic widths are node-global, but every intrinsic probe owns a
		// separate throwaway LayoutState. Reapply the collapsed-border winners so
		// a cached max-content probe has the same table and cell edges as the
		// min-content probe that populated the cache.
		if state.subtree_root != none {
			resolve_collapsed_table_borders(mut state, table, cached.rows, cached.placements,
				cached.column_definitions, cached.column_count)
		}
		return cached
	}
	intrinsic_timing_start := time.sys_mono_now()
	defer {
		if os.getenv('LADYBIRD_DEBUG_TIMING') != '' {
			intrinsic_elapsed := (time.sys_mono_now() - intrinsic_timing_start) / 1_000_000
			if intrinsic_elapsed > 0 {
				eprintln('Ladybird V timing:       table_intrinsic_measures ${intrinsic_elapsed} ms')
			}
		}
	}
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
	mut collapsed_columns := []bool{len: column_count}
	for definition in column_definitions {
		if !table_column_definition_is_collapsed(definition) {
			continue
		}
		end := if definition.index + definition.span < column_count {
			definition.index + definition.span
		} else {
			column_count
		}
		for index in definition.index .. end {
			collapsed_columns[index] = true
		}
	}
	capmin := calculate_table_caption_minimum_width(mut state, table, percentage_basis)
	computed := table.computed_values()
	resolve_collapsed_table_borders(mut state, table, rows, placements, column_definitions, column_count)
	spacing := if computed.border_collapse() == .collapse {
		CSSPixels.new(0)
	} else {
		computed.border_spacing_horizontal().to_px(layout_length_resolution_context(table))
	}
	if column_count == 0 {
		return &TableGridIntrinsicWidths{
			grid_min: spacing
			grid_max: spacing
			capmin: capmin
			percentage_basis: percentage_basis
			rows: rows
			placements: placements
			column_definitions: column_definitions
			column_count: column_count
			collapsed_columns: collapsed_columns
		}
	}
	mut min_widths := []CSSPixels{len: column_count, init: CSSPixels.new(0)}
	mut max_widths := []CSSPixels{len: column_count, init: CSSPixels.new(0)}
	mut constrained_columns := []bool{len: column_count}
	for definition in column_definitions {
		definition_computed := definition.node.computed_values()
		// Percentages on columns are intrinsic-percentage contributions. They
		// resolve against the assignable table width during distribution, not
		// against the table's containing block while measuring outer sizes.
		definition_min_width := if definition_computed.size_value(.min_width).is_length() {
			definition_computed.size_value(.min_width).to_px(layout_length_resolution_context(definition.node), percentage_basis)
		} else {
			CSSPixels.new(0)
		}
		definition_width := if definition_computed.size_value(.width).is_length() {
			definition_computed.size_value(.width).to_px(layout_length_resolution_context(definition.node), percentage_basis)
		} else {
			CSSPixels.new(0)
		}
		definition_max_width := if definition_computed.size_value(.max_width).is_length() {
			definition_computed.size_value(.max_width).to_px(layout_length_resolution_context(definition.node), percentage_basis)
		} else {
			CSSPixels.max()
		}
		definition_min_size := css_pixels_max(definition_min_width, definition_width)
		definition_max_size := css_pixels_max(definition_min_width, css_pixels_min(definition_max_width, definition_width))
		for column in definition.index .. definition.index + definition.span {
			if column < min_widths.len {
				min_widths[column] = css_pixels_max(min_widths[column], definition_min_size)
				max_widths[column] = css_pixels_max(max_widths[column], definition_max_size)
			}
		}
		if definition.index < constrained_columns.len && definition_computed.size_value(.width).is_length() {
			constrained_columns[definition.index] = true
		}
	}
	for placement in placements {
		if placement.column < constrained_columns.len && placement.cell.computed_values().size_value(.width).is_length() {
			constrained_columns[placement.column] = true
		}
	}
	fixed_mode := table_uses_fixed_mode_layout(table)
	mut cell_measures := []TableCellIntrinsicWidthMeasures{cap: placements.len}
	for placement in placements {
		cell_measures << table_cell_intrinsic_width_measures(mut state, placement.cell, computed.border_collapse() == .collapse, constrained_columns[placement.column], fixed_mode, percentage_basis)
	}
	for placement_index, placement in placements {
		if placement.column_span != 1 || (fixed_mode && placement.row != 0) {
			continue
		}
		measures := cell_measures[placement_index]
		min_widths[placement.column] = css_pixels_max(min_widths[placement.column], measures.outer_min_width)
		max_widths[placement.column] = css_pixels_max(max_widths[placement.column], measures.outer_max_width)
	}
	nonspanning_min_widths := min_widths.clone()
	nonspanning_max_widths := max_widths.clone()
	mut maximum_span := 1
	for placement in placements {
		if placement.column_span > maximum_span {
			maximum_span = placement.column_span
		}
	}
	intrinsic_percentages, has_intrinsic_percentage, percentage_offsets, has_originating_cells := compute_table_column_intrinsic_percentages(column_count, column_definitions, placements, cell_measures, nonspanning_max_widths, maximum_span, fixed_mode)
	if !fixed_mode && table.document().font_rendering_policy() == .chromium {
		compute_chromium_spanning_table_column_measures(mut min_widths, mut max_widths, placements,
			cell_measures, spacing, ChromiumTableColumnConstraints{
			constrained: constrained_columns
			percent:     intrinsic_percentages
			has_percent: has_intrinsic_percentage
			mergeable:   has_originating_cells.map(!it)
		})
	} else {
		compute_spanning_table_column_measures(mut min_widths, mut max_widths, placements,
			cell_measures, spacing, maximum_span, fixed_mode)
	}
	undistributable_space := spacing.scaled(f64(column_count + 1))
	mut grid_min := undistributable_space
	mut grid_max := undistributable_space
	for width in min_widths {
		grid_min = grid_min.plus(width)
	}
	for width in max_widths {
		grid_max = grid_max.plus(width)
	}
	mut percentage_adjusted_width := grid_min
	// With width:auto, a percentage cell is also a constraint on the table
	// width. CSS 2.2 auto table layout asks the UA to enlarge the grid enough
	// for the cell's outer max-content width to occupy that percentage.
	for placement_index, placement in placements {
		if fixed_mode && placement.row != 0 {
			continue
		}
		cell_width := placement.cell.computed_values().size_value(.width)
		if !cell_width.is_percentage() || cell_width.percentage().value() == 0 {
			continue
		}
		adjusted := undistributable_space.plus(CSSPixels.nearest_value_for(math.ceil(100.0 / cell_width.percentage().value() * cell_measures[placement_index].outer_max_width.to_double())))
		percentage_adjusted_width = css_pixels_max(percentage_adjusted_width, adjusted)
	}
	widths := &TableGridIntrinsicWidths{
		grid_min: grid_min
		grid_max: grid_max
		capmin: capmin
		percentage_adjusted_width: percentage_adjusted_width
		percentage_basis: percentage_basis
		rows: rows
		placements: placements
		column_definitions: column_definitions
		column_count: column_count
		cell_measures: cell_measures
		nonspanning_min_widths: nonspanning_min_widths
		nonspanning_max_widths: nonspanning_max_widths
		column_min_widths: min_widths
		column_max_widths: max_widths
		constrained_columns: constrained_columns
		intrinsic_percentages: intrinsic_percentages
		has_intrinsic_percentage: has_intrinsic_percentage
		percentage_offsets: percentage_offsets
		has_originating_cells: has_originating_cells
		collapsed_columns: collapsed_columns
	}
	if table_box := table.as_box() {
		mut mutable_table_box := unsafe { &Box(table_box) }
		mut cache := mutable_table_box.cached_intrinsic_sizes()
		cache.min_content_width = grid_min
		cache.max_content_width = grid_max
		cache.table_grid_width_measures = retain_intrinsic_table_widths(widths)
		return cache.table_grid_width_measures or { widths }
	}
	return widths
}

fn retain_intrinsic_table_widths(widths &TableGridIntrinsicWidths) &TableGridIntrinsicWidths {
	if !platform.transient_arena_entered() { return widths }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return &TableGridIntrinsicWidths{
		...widths
		rows: widths.rows.clone()
		placements: widths.placements.clone()
		column_definitions: widths.column_definitions.clone()
		cell_measures: widths.cell_measures.clone()
		nonspanning_min_widths: widths.nonspanning_min_widths.clone()
		nonspanning_max_widths: widths.nonspanning_max_widths.clone()
		column_min_widths: widths.column_min_widths.clone()
		column_max_widths: widths.column_max_widths.clone()
		constrained_columns: widths.constrained_columns.clone()
		intrinsic_percentages: widths.intrinsic_percentages.clone()
		has_intrinsic_percentage: widths.has_intrinsic_percentage.clone()
		percentage_offsets: widths.percentage_offsets.clone()
		has_originating_cells: widths.has_originating_cells.clone()
		collapsed_columns: widths.collapsed_columns.clone()
	}
}

fn calculate_table_grid_intrinsic_width(mut state LayoutState, table &Node, percentage_basis CSSPixels, constraint SizeConstraint) CSSPixels {
	widths := calculate_table_grid_intrinsic_widths(mut state, table, percentage_basis)
	return if constraint == .min_content { widths.grid_min } else { widths.grid_max }
}

fn compute_table_wrapper_content_width(mut state LayoutState, wrapper &Node, mut wrapper_state UsedValues, containing_width CSSPixels) CSSPixels {
	wrapper_timing_start := time.sys_mono_now()
	defer {
		if os.getenv('LADYBIRD_DEBUG_TIMING') != '' {
			wrapper_elapsed := (time.sys_mono_now() - wrapper_timing_start) / 1_000_000
			if wrapper_elapsed > 0 {
				eprintln('Ladybird V timing:       table_wrapper_width ${wrapper_elapsed} ms')
			}
		}
	}
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
	resolve_box_model_edges(table_styled.computed_values(), mut table_state, containing_width.to_double())
	table_width := table_styled.computed_values().size_value(.width)
	intrinsic_widths := calculate_table_grid_intrinsic_widths(mut state, table_node, containing_width)
	grid_min := intrinsic_widths.grid_min
	grid_max := intrinsic_widths.grid_max
	resolve_width_constraint := fn [table_node, table_state, containing_width, grid_min, grid_max] (constraint css.Size) CSSPixels {
		if constraint.is_min_content() {
			return grid_min
		}
		if constraint.is_max_content() {
			return grid_max
		}
		if constraint.is_fit_content() {
			limit := if available := constraint.fit_content_available_space() {
				available.to_px(layout_length_resolution_context(table_node), containing_width)
			} else {
				containing_width
			}
			return css_pixels_min(grid_max, css_pixels_max(grid_min, limit))
		}
		return resolve_layout_content_size(table_node, constraint, containing_width, table_state,
			true) or { CSSPixels.new(0) }
	}
	mut used_min_width := css_pixels_max(grid_min, intrinsic_widths.capmin)
	minimum := table_styled.computed_values().size_value(.min_width)
	if !minimum.is_auto() {
		used_min_width = css_pixels_max(used_min_width, resolve_width_constraint(minimum))
	}
	mut table_content_width := used_min_width
	if wrapper_state.width_constraint == .min_content {
		table_content_width = grid_min
	} else if wrapper_state.width_constraint == .max_content || table_width.is_max_content() {
		table_content_width = grid_max
	} else if table_width.is_auto() {
		available_wrapper_content_width := containing_width.minus(wrapper_state.margin_box_left()).minus(wrapper_state.margin_box_right())
		available_table_content_width := available_wrapper_content_width.minus(table_state.border_box_left()).minus(table_state.border_box_right())
		table_content_width = css_pixels_max(css_pixels_min(grid_max, available_table_content_width), used_min_width)
		table_content_width = css_pixels_min(css_pixels_max(table_content_width, intrinsic_widths.percentage_adjusted_width), available_table_content_width)
	} else {
		table_content_width = css_pixels_max(resolve_width_constraint(table_width), used_min_width)
	}
	maximum := table_styled.computed_values().size_value(.max_width)
	if !maximum.is_none() {
		table_content_width = css_pixels_min(table_content_width, resolve_width_constraint(maximum))
	}
	// min-width wins when it conflicts with max-width.
	table_content_width = css_pixels_max(table_content_width, used_min_width)
	return table_content_width.plus(table_state.border_box_left()).plus(table_state.border_box_right())
}

fn layout_table_captions(mut state LayoutState, table &Node, mut table_state UsedValues, side css.CaptionSide, start_y CSSPixels, caption_available_height AvailableSize) CSSPixels {
	mut total_height := CSSPixels.new(0)
	caption_available_width := table_state.border_box_width()
	for child in table.children() {
		if !child.display().is_table_caption() || child.is_absolutely_positioned()
			|| child.computed_values().caption_side() != side {
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
		resolve_box_model_edges(styled.computed_values(), mut caption_state, caption_available_width.to_double())
		compute_block_used_width_for_node(mut state, styled, mut caption_state,
			AvailableSize.make_definite(caption_available_width))
		caption_state.set_has_definite_width(true)
		caption_outer_space := AvailableSpace.new(AvailableSize.make_definite(caption_available_width), caption_available_height)
		caption_inner_space := caption_state.available_inner_space_or_constraints_from(caption_outer_space)
		result := layout_inside_independent_formatting_context(mut state, child, mut caption_state, caption_inner_space)
		height_basis := if caption_available_height.is_definite() {
			?f64(caption_available_height.to_px_or_zero().to_double())
		} else {
			?f64(none)
		}
		if resolved_height := resolve_content_height_for_node(mut state, styled, caption_state, height_basis) {
			caption_state.set_content_height(css_px(resolved_height))
			caption_state.set_has_definite_height(true)
		} else {
			caption_state.set_content_height(result.automatic_content_height)
		}
		// Captions are block-level children of the table wrapper's BFC. Keep
		// their tree ownership under the table, but place their content boxes
		// in wrapper flow order: top margin/border/padding, content, then the
		// remaining outer edges before the next flow child.
		caption_state.set_content_x(caption_state.margin_box_left())
		caption_state.set_content_y(start_y.plus(total_height).plus(caption_state.margin_box_top()))
		total_height = total_height.plus(caption_state.margin_box_height())
	}
	return total_height
}

fn position_table_captions(mut state LayoutState, table &Node, side css.CaptionSide, start_y CSSPixels) CSSPixels {
	mut total_height := CSSPixels.new(0)
	for child in table.children() {
		if !child.display().is_table_caption() || child.is_absolutely_positioned()
			|| child.computed_values().caption_side() != side {
			continue
		}
		styled := child.as_node_with_style() or { continue }
		mut caption_state := state.get_mutable(styled)
		caption_state.set_content_y(start_y.plus(total_height).plus(caption_state.margin_box_top()))
		total_height = total_height.plus(caption_state.margin_box_height())
	}
	return total_height
}

fn run_table_formatting_context(mut state LayoutState, table &Node, mut table_state UsedValues, available_space AvailableSpace) FormattingContextResult {
	mut retained := retain_geometry_allocations()
	defer { retained.finish() }
	table_timing_start := time.sys_mono_now()
	_ = available_space
	table_width_percentage_basis := if wrapper_state := table_state.containing_block_used_values() {
		if containing_state := wrapper_state.containing_block_used_values() {
			containing_state.content_width()
		} else {
			wrapper_state.content_width()
		}
	} else {
		table_state.content_width()
	}
	table_height_percentage_basis := if wrapper_state := table_state.containing_block_used_values() {
		if containing_state := wrapper_state.containing_block_used_values() {
			containing_state.content_height()
		} else {
			CSSPixels.new(0)
		}
	} else {
		CSSPixels.new(0)
	}
	intrinsic_widths := calculate_table_grid_intrinsic_widths(mut state, table, table_width_percentage_basis)
	rows := intrinsic_widths.rows
	placements := intrinsic_widths.placements
	column_definitions := intrinsic_widths.column_definitions
	column_count := intrinsic_widths.column_count
	top_caption_height := layout_table_captions(mut state, table, mut table_state, .top,
		CSSPixels.new(0),
		available_space.height)
	bottom_caption_height := layout_table_captions(mut state, table, mut table_state, .bottom,
		CSSPixels.new(0), available_space.height)
	table_state.set_content_y(top_caption_height.plus(table_state.margin_box_top()))
	computed := table.computed_values()
	resolve_collapsed_table_borders(mut state, table, rows, placements, column_definitions, column_count)
	if computed.border_collapse() == .collapse {
		if wrapper_state := table_state.containing_block_used_values() {
			table_state.set_content_width(wrapper_state.content_width().minus(table_state.border_box_left()).minus(table_state.border_box_right()))
		}
	}
	if computed.size_value(.width).contains_percentage() {
		// Percentages on the principal table are relative to the table wrapper's
		// containing block, not to the anonymous wrapper itself.
		if wrapper_state := table_state.containing_block_used_values() {
			if outer_containing_state := wrapper_state.containing_block_used_values() {
				if resolved := resolve_layout_content_size(table, computed.size_value(.width), outer_containing_state.content_width(), table_state, true) {
					table_state.set_content_width(clamp_layout_content_size(table, resolved, outer_containing_state.content_width(), table_state, true))
					table_state.set_has_definite_width(true)
					// The table root's authored margins live on its anonymous
					// wrapper. Do not retain the generic block-width pass's
					// over-constraint remainder on the inner table box.
					table_state.margin_left = CSSPixels.new(0)
					table_state.margin_right = CSSPixels.new(0)
				}
			}
		}
	}
	if computed.size_value(.width).is_intrinsic_sizing_constraint()
		|| computed.size_value(.min_width).is_intrinsic_sizing_constraint()
		|| computed.size_value(.max_width).is_intrinsic_sizing_constraint() {
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
	fixed_mode := table_uses_fixed_mode_layout(table)
	if intrinsic_widths.grid_min.raw_value() > table_state.content_width().raw_value() {
		table_state.set_content_width(intrinsic_widths.grid_min)
	}
	// TableFormattingContext::compute_table_width() makes the anonymous table
	// wrapper exactly as wide as the principal table's border box. The wrapper
	// was measured in an intrinsic throwaway state before this real table pass,
	// so the real state must be synchronized here as well.
	if wrapper_values := table_state.containing_block_used_values() {
		mut wrapper_state := unsafe { &UsedValues(wrapper_values) }
		wrapper_state.set_content_width(table_state.border_box_width())
	}
	mut column_widths := distribute_table_width_to_columns(intrinsic_widths.column_min_widths, intrinsic_widths.column_max_widths, intrinsic_widths.constrained_columns, intrinsic_widths.intrinsic_percentages, intrinsic_widths.has_intrinsic_percentage, intrinsic_widths.percentage_offsets, intrinsic_widths.has_originating_cells, table_state.content_width(), horizontal_spacing, fixed_mode)
	mut removed_column_width := CSSPixels.new(0)
	for index in 0 .. column_widths.len {
		if index < intrinsic_widths.collapsed_columns.len
			&& intrinsic_widths.collapsed_columns[index] {
			removed_column_width = removed_column_width.plus(column_widths[index]).plus(horizontal_spacing)
			column_widths[index] = CSSPixels.new(0)
		}
	}
	if removed_column_width.raw_value() > 0 {
		table_state.set_content_width(table_state.content_width().minus(removed_column_width))
	}
	column_offsets := table_column_offsets(column_widths, horizontal_spacing, intrinsic_widths.collapsed_columns)
	row_is_collapsed := rows.map(table_row_is_collapsed(it))
	row_min_heights, _ := compute_table_row_intrinsic_measures(mut state, rows, placements, computed.border_collapse() == .collapse, table_height_percentage_basis, vertical_spacing)
	mut row_heights := []CSSPixels{len: rows.len, init: CSSPixels.new(0)}
	mut row_baselines := []CSSPixels{len: rows.len, init: CSSPixels.new(0)}
	mut row_has_baseline := []bool{len: rows.len}
	mut row_max_cell_descent := []CSSPixels{len: rows.len, init: CSSPixels.new(0)}
	mut row_smallest_cell_end_offset := []CSSPixels{len: rows.len, init: CSSPixels.max()}
	mut row_has_cell := []bool{len: rows.len}
	mut cell_baselines := []CSSPixels{len: placements.len, init: CSSPixels.new(0)}
	for index, row in rows {
		if row_is_collapsed[index] {
			continue
		}
		// First pass: definite row lengths participate in the base height.
		// Percentages are resolved only after the table grid height is known.
		row_height := row.computed_values().size_value(.height)
		if row_height.is_length() || (row_height.is_calculated() && !row_height.contains_percentage()) {
			if specified_height := resolve_layout_size(row, row_height, table_state.content_height()) {
				row_heights[index] = specified_height
			}
		}
	}
	for placement_index, placement in placements {
		cell_width := table_column_range_width(column_offsets, placement.column, placement.column_span, horizontal_spacing, intrinsic_widths.collapsed_columns)
		styled := placement.cell.as_node_with_style() or { continue }
		mut cell_state := state.get_mutable(styled)
		column_end := if placement.column + placement.column_span < column_count {
			placement.column + placement.column_span
		} else {
			column_count
		}
		cell_state.set_hidden_by_collapsed_columns(table_visible_columns_in_range(
			intrinsic_widths.collapsed_columns, placement.column, column_end) == 0)
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
		shrink_table_cell_inline_offsets_to_fit(mut cell_state, collapsed, cell_width)
		content_width := cell_width.minus(table_cell_measurement_inline_edges(cell_state, collapsed))
		// CSS Tables computes a definite cell height as the used height of the
		// cell's border box. UsedValues stores the content height, so subtract
		// the resolved padding and borders before laying out the cell contents.
		// This is intentionally different from ordinary box height resolution.
		mut forced_cell_height := ?CSSPixels(none)
		mut specified_cell_height := ?CSSPixels(none)
		cell_computed_height := placement.cell.computed_values().size_value(.height)
		if !row_is_collapsed[placement.row]
			&& (cell_computed_height.is_length()
				|| (cell_computed_height.is_calculated() && !cell_computed_height.contains_percentage())) {
			if cell_used_height := resolve_layout_size(placement.cell, cell_computed_height, table_state.content_height()) {
				edges := table_cell_measurement_block_edges(cell_state, collapsed)
				outer_height := table_cell_specified_outer_height(placement.cell, cell_used_height, edges)
				specified_cell_height = outer_height
				forced_cell_height = outer_height.minus(edges)
			}
		}
		cell_state = layout_independent_child_using_automatic_height(mut state, placement.cell, mut table_state, table_state.content_width(), if table_state.has_definite_height() {
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
		shrink_table_cell_inline_offsets_to_fit(mut cell_state, collapsed, cell_width)
		cell_baselines[placement_index] = table_cell_baseline(state, placement.cell,
			cell_state, collapsed)
		if placement.row >= 0 && placement.row < row_baselines.len
			&& !row_is_collapsed[placement.row] {
			row_has_cell[placement.row] = true
			row_smallest_cell_end_offset[placement.row] = css_pixels_min(row_smallest_cell_end_offset[placement.row], cell_state.border_box_bottom())
			if table_cell_is_baseline_aligned(placement.cell) {
				row_has_baseline[placement.row] = true
				row_baselines[placement.row] = css_pixels_max(row_baselines[placement.row],
					cell_baselines[placement_index])
				if placement.row_span == 1 {
					cell_descent := table_cell_measurement_outer_height(cell_state,
						collapsed).minus(cell_baselines[placement_index])
					row_max_cell_descent[placement.row] = css_pixels_max(
						row_max_cell_descent[placement.row], cell_descent)
				}
			}
		}
		if !row_is_collapsed[placement.row] {
			if specified_height := specified_cell_height {
				row_heights[placement.row] = css_pixels_max(row_heights[placement.row], specified_height)
			}
			if placement.row_span == 1 {
				row_heights[placement.row] = css_pixels_max(row_heights[placement.row], table_cell_measurement_outer_height(cell_state, collapsed))
			}
			row_heights[placement.row] = css_pixels_max(row_heights[placement.row], row_min_heights[placement.row])
		}
	}
	grow_table_rows_to_baseline_aligned_cells(mut row_heights, row_baselines,
		row_has_baseline, row_max_cell_descent, row_is_collapsed)
	// TableGrid marks a row collapsed when either the row itself or its row
	// group has visibility: collapse. Intrinsic row measures are still computed,
	// but compute_table_height() discards the collapsed row's base height.
	for index in 0 .. row_heights.len {
		if row_is_collapsed[index] {
			row_heights[index] = CSSPixels.new(0)
			row_baselines[index] = CSSPixels.new(0)
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
		if specified_height := resolve_layout_content_size(table, table_height, percentage_basis, table_state, false) {
			table_grid_height = css_pixels_max(table_grid_height, specified_height)
		}
	}
	if available_space.height.is_definite() {
		caption_height := top_caption_height.plus(bottom_caption_height)
		required_outer_height := css_pixels_max(available_space.height.to_px_or_zero().minus(caption_height),
			CSSPixels.new(0))
		required_grid_height := css_pixels_max(required_outer_height.minus(table_state.margin_box_top()).minus(table_state.margin_box_bottom()),
			CSSPixels.new(0))
		table_grid_height = css_pixels_max(table_grid_height, required_grid_height)
	}
	mut reference_heights := row_heights.clone()
	for index, row in rows {
		if row_is_collapsed[index] {
			reference_heights[index] = CSSPixels.new(0)
			continue
		}
		row_height := row.computed_values().size_value(.height)
		if row_height.is_percentage() || (row_height.is_calculated() && row_height.contains_percentage()) {
			if specified_height := resolve_layout_size(row, row_height, table_grid_height) {
				reference_heights[index] = css_pixels_max(reference_heights[index], specified_height)
			}
		}
	}
	for placement_index, placement in placements {
		cell_height := placement.cell.computed_values().size_value(.height)
		if !cell_height.is_percentage() && !(cell_height.is_calculated() && cell_height.contains_percentage()) {
			continue
		}
		if specified_height := resolve_layout_size(placement.cell, cell_height, table_grid_height) {
			styled := placement.cell.as_node_with_style() or { continue }
			mut cell_state := state.get_mutable(styled)
			collapsed := computed.border_collapse() == .collapse
			edges := table_cell_measurement_block_edges(cell_state, collapsed)
			outer_height := table_cell_specified_outer_height(placement.cell, specified_height, edges)
			if !row_is_collapsed[placement.row] {
				reference_heights[placement.row] = css_pixels_max(reference_heights[placement.row], outer_height)
			}
			// TableFormattingContext::compute_table_height() performs a second
			// cell layout after the table height makes percentages definite. The
			// resolved height is the cell's border-box height. It writes that
			// content height directly and reruns the already-created independent
			// formatting context without recomputing or clamping the cell metrics.
			cell_width := table_column_range_width(column_offsets, placement.column, placement.column_span, horizontal_spacing, intrinsic_widths.collapsed_columns)
			content_width := cell_width.minus(table_cell_measurement_inline_edges(cell_state, collapsed))
			content_height := outer_height.minus(edges)
			cell_state.set_content_width(content_width)
			cell_state.set_content_height(content_height)
			cell_state.set_has_definite_width(true)
			cell_state.set_has_definite_height(true)
			layout_inside_independent_formatting_context(mut state, placement.cell, mut cell_state, AvailableSpace.new(AvailableSize.make_definite(content_width), AvailableSize.make_definite(content_height)))
			cell_baselines[placement_index] = table_cell_baseline(state, placement.cell,
				cell_state, collapsed)
			if !row_is_collapsed[placement.row] {
				reference_heights[placement.row] = css_pixels_max(reference_heights[placement.row], table_cell_measurement_outer_height(cell_state, collapsed))
				row_has_cell[placement.row] = true
				row_smallest_cell_end_offset[placement.row] = css_pixels_min(row_smallest_cell_end_offset[placement.row], cell_state.border_box_bottom())
				if table_cell_is_baseline_aligned(placement.cell) {
					row_has_baseline[placement.row] = true
					row_baselines[placement.row] = css_pixels_max(row_baselines[placement.row],
						cell_baselines[placement_index])
					if placement.row_span == 1 {
						cell_descent := table_cell_measurement_outer_height(cell_state,
							collapsed).minus(cell_baselines[placement_index])
						row_max_cell_descent[placement.row] = css_pixels_max(
							row_max_cell_descent[placement.row], cell_descent)
					}
				}
			}
		}
	}
	grow_table_rows_to_baseline_aligned_cells(mut reference_heights, row_baselines,
		row_has_baseline, row_max_cell_descent, row_is_collapsed)
	mut sum_reference_height := CSSPixels.new(0)
	mut visible_row_count := 0
	for index, height in reference_heights {
		sum_reference_height = sum_reference_height.plus(height)
		if !row_is_collapsed[index] {
			visible_row_count++
		}
	}
	if sum_reference_height.raw_value() > 0 {
		if table_grid_height.raw_value() <= sum_reference_height.raw_value() {
			for index in 0 .. row_heights.len {
				if row_is_collapsed[index] {
					row_heights[index] = CSSPixels.new(0)
					continue
				}
				weight := reference_heights[index].to_double() / sum_reference_height.to_double()
				row_heights[index] = CSSPixels.nearest_value_for(table_grid_height.to_double() * weight)
			}
		} else if table_grid_height.raw_value() > sum_reference_height.raw_value() {
			mut auto_row_count := 0
			for index, row in rows {
				if row.computed_values().size_value(.height).is_auto()
					&& !row_is_collapsed[index] {
					auto_row_count++
				}
			}
			if auto_row_count > 0 {
				// CSSPixels / size_t yields a CSSPixelFraction upstream; assigning
				// that fraction to a row truncates the fixed-point quotient.
				increment := table_grid_height.minus(sum_reference_height).divided_by(CSSPixels.new(auto_row_count)).to_css_pixels()
				for index, row in rows {
					row_heights[index] = reference_heights[index]
					if row.computed_values().size_value(.height).is_auto()
						&& !row_is_collapsed[index] {
						row_heights[index] = row_heights[index].plus(increment)
					}
				}
			} else if visible_row_count > 0 {
				increment := table_grid_height.minus(sum_reference_height).divided_by(CSSPixels.new(visible_row_count)).to_css_pixels()
				for index in 0 .. row_heights.len {
					if row_is_collapsed[index] {
						row_heights[index] = CSSPixels.new(0)
						continue
					}
					row_heights[index] = reference_heights[index].plus(increment)
				}
			}
		} else {
			row_heights = reference_heights.clone()
		}
		// CSS Tables calls this the undistributable space. It is based on the
		// number of visible rows, not on the number of tracks in the grid.
		table_grid_height = table_grid_height.plus(vertical_spacing.scaled(f64(visible_row_count + 1)))
	}

	mut row_offsets := []CSSPixels{len: rows.len}
	visible_column_count := table_visible_column_count(intrinsic_widths.collapsed_columns, column_count)
	table_grid_content_width := if visible_column_count > 0 {
		table_columns_total_width(column_widths).plus(horizontal_spacing.scaled(f64(visible_column_count - 1)))
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
		if !row_is_collapsed[index] {
			cursor_y = cursor_y.plus(row_heights[index]).plus(vertical_spacing)
		}
	}
	// A row group spans its own rows at their already-computed grid positions.
	// Loose rows may occur between groups, so the previous group's end is only
	// the fallback position for an empty group, not the next nonempty group's
	// start.
	mut row_group_top_offset := vertical_spacing
	for group in table_row_containers_in_layout_order(table) {
		if !group.display().is_table_row_group() && !group.display().is_table_header_group() && !group.display().is_table_footer_group() {
			continue
		}
		styled := group.as_node_with_style() or { continue }
		mut group_state := state.get_mutable(styled)
		group_state.set_containing_block_used_values(table_state)
		mut group_top := row_group_top_offset
		mut group_bottom := row_group_top_offset
		mut group_width := CSSPixels.new(0)
		mut has_rows := false
		for row_index, row in rows {
			parent := row.parent() or { continue }
			if !layout_nodes_same(parent, group) {
				continue
			}
			row_styled := row.as_node_with_style() or { continue }
			row_state := state.get(row_styled)
			if !has_rows {
				group_top = row_offsets[row_index]
				has_rows = true
			}
			group_bottom = row_offsets[row_index].plus(row_state.border_box_height())
			group_width = css_pixels_max(group_width, row_state.border_box_width())
		}
		group_state.set_content_offset(CSSPixelPoint.new(horizontal_spacing, group_top))
		group_state.set_content_width(group_width)
		group_state.set_content_height(group_bottom.minus(group_top))
		row_group_top_offset = group_bottom
		if has_rows {
			row_group_top_offset = row_group_top_offset.plus(vertical_spacing)
		}
	}
	position_table_column_boxes(mut state, table, table_state, column_offsets, intrinsic_widths.collapsed_columns, rows,
		row_is_collapsed, horizontal_spacing, vertical_spacing)
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
		// position_cell_boxes() applies the signed difference verbatim. A
		// percentage-height cell can be taller than the row after weighted row
		// distribution, in which case upstream deliberately produces negative
		// alignment padding rather than clamping it to zero.
		alignment_space := spanned_height.minus(table_cell_measurement_outer_height(cell_state, collapsed))
		if table_cell_is_anonymous_wrapper_for_flex_or_grid(placement.cell) {
			cell_state.padding_bottom = cell_state.padding_bottom.plus(alignment_space)
		} else if table_cell_is_baseline_aligned(placement.cell) {
			row_baseline := if placement.row < row_has_baseline.len
				&& row_has_baseline[placement.row] {
				row_baselines[placement.row]
			} else {
				cell_baselines[placement_index]
			}
			baseline_adjustment := row_baseline.minus(cell_baselines[placement_index])
			cell_state.padding_top = cell_state.padding_top.plus(baseline_adjustment)
			cell_state.padding_bottom = cell_state.padding_bottom.plus(alignment_space.minus(baseline_adjustment))
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
				.top {
					cell_state.padding_bottom = cell_state.padding_bottom.plus(alignment_space)
				}
				else {}
			}
		}
		cell_state.set_content_x(table_cell_physical_offset(table, table_state.content_width(), column_offsets, placement, horizontal_spacing, intrinsic_widths.collapsed_columns).plus(table_cell_content_offset_left(cell_state, collapsed)))
		cell_state.set_content_y(row_offsets[placement.row].plus(table_cell_content_offset_top(cell_state, collapsed)))
	}
	final_table_height := css_pixels_max(css_pixels_max(cursor_y, row_group_top_offset), table_grid_height)
	table_state.set_content_height(final_table_height)
	store_table_part_baselines(mut state, table, table_state, rows, row_offsets, row_heights,
		row_baselines, row_has_baseline, row_smallest_cell_end_offset, row_has_cell,
		row_is_collapsed)
	bottom_caption_start := table_state.offset.y().plus(table_state.content_height()).plus(table_state.margin_box_bottom())
	_ = position_table_captions(mut state, table, .bottom, bottom_caption_start)
	if table.is_inline_table() {
		initialize_trailing_table_whitespace_state(mut state, table)
	}
	if os.getenv('LADYBIRD_DEBUG_TIMING') != '' {
		table_elapsed := (time.sys_mono_now() - table_timing_start) / 1_000_000
		if table_elapsed > 0 {
			eprintln('Ladybird V timing:       table ${table_elapsed} ms (${rows.len} rows, ${placements.len} cells)')
		}
	}
	return FormattingContextResult{
		automatic_content_width: table_state.content_width()
		automatic_content_height: final_table_height
	}
}

// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
module painting

import math

// Translation of Painting/TableBordersPainting.cpp. Collapsed table borders
// retain the element which won conflict resolution so intersections can be
// painted from least to most specific, just as they are upstream.
pub struct BorderDataWithElementKind {
pub:
	border_data  BorderData
	element_kind ConflictingElementKind = .cell
}

pub struct BordersDataWithElementKind {
pub:
	top    BorderDataWithElementKind
	right  BorderDataWithElementKind
	bottom BorderDataWithElementKind
	left   BorderDataWithElementKind
}

pub struct TableCellCoordinates {
pub:
	row_index    int
	column_index int
	row_span     int = 1
	column_span  int = 1
}

pub struct TableCellPaintData {
pub:
	coordinates      TableCellCoordinates
	rect             Rect
	borders          BordersDataWithElementKind
	radii            BorderRadiiData
	empty_cells_hide bool
	has_children     bool
}

enum TableBorderEdgeDirection {
	horizontal
	vertical
}

struct BorderEdgePaintingInfo {
	rect                          IntRect
	border_data_with_element_kind BorderDataWithElementKind
	direction                     TableBorderEdgeDirection
	row                           ?int
	column                        ?int
}

fn cell_coordinates_key(row int, column int) u64 {
	return (u64(u32(row)) << 32) | u64(u32(column))
}

fn row_index_for_element_kind(index int, element_kind ConflictingElementKind) ?int {
	return match element_kind {
		.cell, .row, .row_group { index }
		else { none }
	}
}

fn column_index_for_element_kind(index int, element_kind ConflictingElementKind) ?int {
	return match element_kind {
		.cell, .column, .column_group { index }
		else { none }
	}
}

fn collapsed_border_part_after_line(width f64, fractional bool) f64 {
	if width <= 0 {
		return 0
	}
	if fractional {
		// LayoutUnit halves truncate to 1/64 CSS pixel before device snapping.
		return math.floor(width * 32.0) / 64.0
	}
	return math.floor(width / 2.0)
}

fn collapsed_border_part_before_line(width f64, fractional bool) f64 {
	if width <= 0 {
		return 0
	}
	if fractional {
		return collapsed_border_part_after_line(width, true)
	}
	return width - collapsed_border_part_after_line(width, false)
}

fn device_rect_from_css_edges(left f64, top f64, right f64, bottom f64, converter DevicePixelConverter) IntRect {
	x := converter.rounded_device_pixels(left)
	y := converter.rounded_device_pixels(top)
	return IntRect{
		x: x
		y: y
		width: converter.rounded_device_pixels(right) - x
		height: converter.rounded_device_pixels(bottom) - y
	}
}

fn make_right_cell_edge(right_cell_rect Rect, cell_rect Rect, borders_data BordersDataWithElementKind, coordinates TableCellCoordinates, converter DevicePixelConverter, fractional bool) BorderEdgePaintingInfo {
	grid_line := right_cell_rect.x
	return BorderEdgePaintingInfo{
		rect: device_rect_from_css_edges(
			grid_line - collapsed_border_part_before_line(borders_data.right.border_data.width, fractional),
			cell_rect.y - collapsed_border_part_before_line(borders_data.top.border_data.width, fractional),
			grid_line + collapsed_border_part_after_line(borders_data.right.border_data.width, fractional),
			math.max(cell_rect.bottom(), right_cell_rect.bottom()) + collapsed_border_part_after_line(borders_data.bottom.border_data.width, fractional),
			converter)
		border_data_with_element_kind: borders_data.right
		direction: .vertical
		row: row_index_for_element_kind(coordinates.row_index, borders_data.right.element_kind)
		column: column_index_for_element_kind(coordinates.column_index, borders_data.right.element_kind)
	}
}

fn make_down_cell_edge(down_cell_rect Rect, cell_rect Rect, borders_data BordersDataWithElementKind, coordinates TableCellCoordinates, converter DevicePixelConverter, fractional bool) BorderEdgePaintingInfo {
	grid_line := down_cell_rect.y
	return BorderEdgePaintingInfo{
		rect: device_rect_from_css_edges(
			cell_rect.x - collapsed_border_part_before_line(borders_data.left.border_data.width, fractional),
			grid_line - collapsed_border_part_before_line(borders_data.bottom.border_data.width, fractional),
			math.max(cell_rect.right(), down_cell_rect.right()) + collapsed_border_part_after_line(borders_data.right.border_data.width, fractional),
			grid_line + collapsed_border_part_after_line(borders_data.bottom.border_data.width, fractional),
			converter)
		border_data_with_element_kind: borders_data.bottom
		direction: .horizontal
		row: row_index_for_element_kind(coordinates.row_index, borders_data.bottom.element_kind)
		column: column_index_for_element_kind(coordinates.column_index, borders_data.bottom.element_kind)
	}
}

fn make_first_row_top_cell_edge(cell_rect Rect, borders_data BordersDataWithElementKind, coordinates TableCellCoordinates, converter DevicePixelConverter, fractional bool) BorderEdgePaintingInfo {
	grid_line := cell_rect.y
	return BorderEdgePaintingInfo{
		rect: device_rect_from_css_edges(
			cell_rect.x - collapsed_border_part_before_line(borders_data.left.border_data.width, fractional),
			grid_line - collapsed_border_part_before_line(borders_data.top.border_data.width, fractional),
			cell_rect.right() + collapsed_border_part_after_line(borders_data.right.border_data.width, fractional),
			grid_line + collapsed_border_part_after_line(borders_data.top.border_data.width, fractional),
			converter)
		border_data_with_element_kind: borders_data.top
		direction: .horizontal
		row: row_index_for_element_kind(coordinates.row_index, borders_data.top.element_kind)
		column: column_index_for_element_kind(coordinates.column_index, borders_data.top.element_kind)
	}
}

fn make_last_row_bottom_cell_edge(cell_rect Rect, borders_data BordersDataWithElementKind, coordinates TableCellCoordinates, converter DevicePixelConverter, fractional bool) BorderEdgePaintingInfo {
	grid_line := cell_rect.bottom()
	return BorderEdgePaintingInfo{
		rect: device_rect_from_css_edges(
			cell_rect.x - collapsed_border_part_before_line(borders_data.left.border_data.width, fractional),
			grid_line - collapsed_border_part_before_line(borders_data.bottom.border_data.width, fractional),
			cell_rect.right() + collapsed_border_part_after_line(borders_data.right.border_data.width, fractional),
			grid_line + collapsed_border_part_after_line(borders_data.bottom.border_data.width, fractional),
			converter)
		border_data_with_element_kind: borders_data.bottom
		direction: .horizontal
		row: row_index_for_element_kind(coordinates.row_index, borders_data.bottom.element_kind)
		column: column_index_for_element_kind(coordinates.column_index, borders_data.bottom.element_kind)
	}
}

fn make_first_column_left_cell_edge(cell_rect Rect, borders_data BordersDataWithElementKind, coordinates TableCellCoordinates, converter DevicePixelConverter, fractional bool) BorderEdgePaintingInfo {
	grid_line := cell_rect.x
	return BorderEdgePaintingInfo{
		rect: device_rect_from_css_edges(
			grid_line - collapsed_border_part_before_line(borders_data.left.border_data.width, fractional),
			cell_rect.y - collapsed_border_part_before_line(borders_data.top.border_data.width, fractional),
			grid_line + collapsed_border_part_after_line(borders_data.left.border_data.width, fractional),
			cell_rect.bottom() + collapsed_border_part_after_line(borders_data.bottom.border_data.width, fractional),
			converter)
		border_data_with_element_kind: borders_data.left
		direction: .vertical
		row: row_index_for_element_kind(coordinates.row_index, borders_data.left.element_kind)
		column: column_index_for_element_kind(coordinates.column_index, borders_data.left.element_kind)
	}
}

fn make_last_column_right_cell_edge(cell_rect Rect, borders_data BordersDataWithElementKind, coordinates TableCellCoordinates, converter DevicePixelConverter, fractional bool) BorderEdgePaintingInfo {
	grid_line := cell_rect.right()
	return BorderEdgePaintingInfo{
		rect: device_rect_from_css_edges(
			grid_line - collapsed_border_part_before_line(borders_data.right.border_data.width, fractional),
			cell_rect.y - collapsed_border_part_before_line(borders_data.top.border_data.width, fractional),
			grid_line + collapsed_border_part_after_line(borders_data.right.border_data.width, fractional),
			cell_rect.bottom() + collapsed_border_part_after_line(borders_data.bottom.border_data.width, fractional),
			converter)
		border_data_with_element_kind: borders_data.right
		direction: .vertical
		row: row_index_for_element_kind(coordinates.row_index, borders_data.right.element_kind)
		column: column_index_for_element_kind(coordinates.column_index, borders_data.right.element_kind)
	}
}

fn remove_element_kind_from_borders_data(borders BordersDataWithElementKind) BordersData {
	return BordersData{
		top: borders.top.border_data
		right: borders.right.border_data
		bottom: borders.bottom.border_data
		left: borders.left.border_data
	}
}

fn paint_separate_cell_borders(cell TableCellPaintData, cell_rects map[u64]IntRect, converter DevicePixelConverter) []DisplayListCommand {
	cell_rect := cell_rects[cell_coordinates_key(cell.coordinates.row_index, cell.coordinates.column_index)]
	borders := remove_element_kind_from_borders_data(cell.borders).to_device_pixels(converter)
	return paint_all_borders(cell_rect, cell.radii.as_corners(converter), borders)
}

fn table_border_is_less_specific(a BorderData, b BorderData) bool {
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
	return style_precedence(a.line_style) < style_precedence(b.line_style)
}

fn optional_coordinate_compare_descending(a ?int, b ?int) int {
	a_value := a or { return 0 }
	b_value := b or { return 0 }
	if a_value == b_value {
		return 0
	}
	return if a_value > b_value { -1 } else { 1 }
}

fn border_edge_compare(a &BorderEdgePaintingInfo, b &BorderEdgePaintingInfo) int {
	a_border := a.border_data_with_element_kind.border_data
	b_border := b.border_data_with_element_kind.border_data
	if a_border.line_style == b_border.line_style && a_border.width == b_border.width {
		a_kind := int(a.border_data_with_element_kind.element_kind)
		b_kind := int(b.border_data_with_element_kind.element_kind)
		if a_kind != b_kind {
			// Larger enum values are less specific and must be painted first.
			return if a_kind > b_kind { -1 } else { 1 }
		}
		column_comparison := optional_coordinate_compare_descending(a.column, b.column)
		if column_comparison != 0 {
			return column_comparison
		}
		return optional_coordinate_compare_descending(a.row, b.row)
	}
	if table_border_is_less_specific(a_border, b_border) {
		return -1
	}
	if table_border_is_less_specific(b_border, a_border) {
		return 1
	}
	return 0
}

fn snap_cells_to_device_coordinates(cells []TableCellPaintData, row_count int, column_count int, converter DevicePixelConverter) map[u64]IntRect {
	mut y_line_start_coordinates := []int{len: row_count + 1}
	mut y_line_end_coordinates := []int{len: row_count + 1}
	mut x_line_start_coordinates := []int{len: column_count + 1}
	mut x_line_end_coordinates := []int{len: column_count + 1}
	for cell in cells {
		coordinates := cell.coordinates
		end_row_index := coordinates.row_index + coordinates.row_span
		end_column_index := coordinates.column_index + coordinates.column_span
		y_line_start_coordinates[coordinates.row_index] = max_int(converter.rounded_device_pixels(cell.rect.y), y_line_start_coordinates[coordinates.row_index])
		y_line_end_coordinates[end_row_index] = max_int(converter.rounded_device_pixels(cell.rect.bottom()), y_line_end_coordinates[end_row_index])
		x_line_start_coordinates[coordinates.column_index] = max_int(converter.rounded_device_pixels(cell.rect.x), x_line_start_coordinates[coordinates.column_index])
		x_line_end_coordinates[end_column_index] = max_int(converter.rounded_device_pixels(cell.rect.right()), x_line_end_coordinates[end_column_index])
	}
	mut result := map[u64]IntRect{}
	for cell in cells {
		coordinates := cell.coordinates
		end_row_index := coordinates.row_index + coordinates.row_span
		end_column_index := coordinates.column_index + coordinates.column_span
		x := x_line_start_coordinates[coordinates.column_index]
		y := y_line_start_coordinates[coordinates.row_index]
		result[cell_coordinates_key(coordinates.row_index, coordinates.column_index)] = IntRect{
			x: x
			y: y
			width: x_line_end_coordinates[end_column_index] - x
			height: y_line_end_coordinates[end_row_index] - y
		}
	}
	return result
}

fn paint_collected_edges(mut edges []BorderEdgePaintingInfo) []DisplayListCommand {
	edges.sort_with_compare(border_edge_compare)
	mut commands := []DisplayListCommand{cap: edges.len}
	for edge in edges {
		border := edge.border_data_with_element_kind.border_data
		if border.width <= 0 || edge.rect.width <= 0 || edge.rect.height <= 0
			|| border.line_style in [.none, .hidden] {
			continue
		}
		if border.line_style == .dotted || border.line_style == .dashed {
			commands << DisplayListCommand(DrawLine{
				from: IntPoint{edge.rect.x, edge.rect.y}
				to: if edge.direction == .horizontal {
					IntPoint{edge.rect.right(), edge.rect.y}
				} else {
					IntPoint{edge.rect.x, edge.rect.bottom()}
				}
				color: border.color
				thickness: if edge.direction == .horizontal { edge.rect.height } else { edge.rect.width }
				line_style: border.line_style
			})
		} else {
			// FIXME: Match upstream support for the remaining line styles; Ladybird
			// currently paints all of them as solid rectangles here.
			commands << DisplayListCommand(FillRect{edge.rect, border.color})
		}
	}
	return commands
}

// Translation of Painting::paint_table_borders(). Separate cell borders use
// the shared snapped grid; collapsed borders collect each shared edge once,
// sort it, and paint it in the same device-pixel geometry as Ladybird.
pub fn paint_table_borders(cells []TableCellPaintData, border_collapse bool, converter DevicePixelConverter) []DisplayListCommand {
	return paint_table_borders_with_fractional_shares(cells, border_collapse, converter, false)
}

// Chromium retains half-pixel collapsed borders until the final edge snap.
// The translated LibWeb entry point above preserves whole-pixel splitting.
pub fn paint_table_borders_with_fractional_shares(cells []TableCellPaintData, border_collapse bool, converter DevicePixelConverter, fractional bool) []DisplayListCommand {
	if cells.len == 0 {
		return []DisplayListCommand{}
	}
	mut row_count := 0
	mut column_count := 0
	for cell in cells {
		row_count = max_int(row_count, cell.coordinates.row_index + cell.coordinates.row_span)
		column_count = max_int(column_count, cell.coordinates.column_index + cell.coordinates.column_span)
	}
	cell_rects := snap_cells_to_device_coordinates(cells, row_count, column_count, converter)
	if !border_collapse {
		mut commands := []DisplayListCommand{}
		for cell in cells {
			if cell.empty_cells_hide && !cell.has_children {
				continue
			}
			commands << paint_separate_cell_borders(cell, cell_rects, converter)
		}
		return commands
	}
	mut edges := []BorderEdgePaintingInfo{}
	mut cell_rects_css := map[u64]Rect{}
	for cell in cells {
		cell_rects_css[cell_coordinates_key(cell.coordinates.row_index, cell.coordinates.column_index)] = cell.rect
	}
	for cell in cells {
		coordinates := cell.coordinates
		cell_rect := cell_rects_css[cell_coordinates_key(coordinates.row_index, coordinates.column_index)]
		borders := cell.borders
		right_coordinates := TableCellCoordinates{
			row_index: coordinates.row_index
			column_index: coordinates.column_index + coordinates.column_span
		}
		if right_cell_rect := cell_rects_css[cell_coordinates_key(right_coordinates.row_index, right_coordinates.column_index)] {
			edges << make_right_cell_edge(right_cell_rect, cell_rect, borders, right_coordinates,
				converter, fractional)
		}
		down_coordinates := TableCellCoordinates{
			row_index: coordinates.row_index + coordinates.row_span
			column_index: coordinates.column_index
		}
		if down_cell_rect := cell_rects_css[cell_coordinates_key(down_coordinates.row_index, down_coordinates.column_index)] {
			edges << make_down_cell_edge(down_cell_rect, cell_rect, borders, down_coordinates,
				converter, fractional)
		}
		if coordinates.row_index == 0 {
			edges << make_first_row_top_cell_edge(cell_rect, borders, TableCellCoordinates{
				row_index: 0
				column_index: coordinates.column_index
			}, converter, fractional)
		}
		if coordinates.row_index + coordinates.row_span == row_count {
			edges << make_last_row_bottom_cell_edge(cell_rect, borders, TableCellCoordinates{
				row_index: row_count - 1
				column_index: coordinates.column_index
			}, converter, fractional)
		}
		if coordinates.column_index == 0 {
			edges << make_first_column_left_cell_edge(cell_rect, borders, TableCellCoordinates{
				row_index: coordinates.row_index
				column_index: 0
			}, converter, fractional)
		}
		if coordinates.column_index + coordinates.column_span == column_count {
			edges << make_last_column_right_cell_edge(cell_rect, borders, TableCellCoordinates{
				row_index: coordinates.row_index
				column_index: column_count - 1
			}, converter, fractional)
		}
	}
	mut commands := paint_collected_edges(mut edges)
	// The collapsed edge collector paints square intersections. Ladybird then
	// repaints every radiused cell with paint_all_borders() so its rounded
	// corners cover those intersections.
	for cell in cells {
		if !cell.radii.has_any_radius() {
			continue
		}
		borders := remove_element_kind_from_borders_data(cell.borders).to_device_pixels(converter)
		commands << paint_all_borders(converter.rounded_device_rect(cell.rect), cell.radii.as_corners(converter), borders)
	}
	return commands
}

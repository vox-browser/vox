module layout

import math

pub struct LayoutItemState {
pub mut:
	id string
	row int
	column int
	row_span int = 1
	column_span int = 1
	row_gap f64
	column_gap f64
	available_width f64
	available_height f64
	minimum f64
	preferred f64
	maximum f64 = 1.0e12
	target f64
	flex_base f64
	hypothetical_main f64
	hypothetical_cross f64
	margin_start_value f64
	margin_end_value f64
	used_margin_start_value f64
	used_margin_end_value f64
	computed map[string]string
}

pub fn (item LayoutItemState) available_space() (f64, f64) { return item.available_width, item.available_height }
pub fn (item LayoutItemState) computed_values() map[string]string { return item.computed.clone() }
pub fn (item LayoutItemState) raw_position() (int, int) { return item.row, item.column }
pub fn (item LayoutItemState) gap_adjusted_row() f64 { return f64(item.row) + f64(item.row) * item.row_gap }
pub fn (item LayoutItemState) gap_adjusted_column() f64 { return f64(item.column) + f64(item.column) * item.column_gap }
pub fn (item LayoutItemState) gap_adjusted_position() (f64, f64) { return item.gap_adjusted_column(), item.gap_adjusted_row() }
pub fn (item LayoutItemState) span() (int, int) { return item.row_span, item.column_span }
pub fn (item LayoutItemState) minimum_size() f64 { return item.minimum }
pub fn (item LayoutItemState) preferred_size() f64 { return item.preferred }
pub fn (item LayoutItemState) maximum_size() f64 { return item.maximum }
pub fn (item LayoutItemState) margin_start() f64 { return item.margin_start_value }
pub fn (item LayoutItemState) margin_end() f64 { return item.margin_end_value }
pub fn (item LayoutItemState) used_margin_start() f64 { return item.used_margin_start_value }
pub fn (item LayoutItemState) used_margin_end() f64 { return item.used_margin_end_value }
pub fn (item LayoutItemState) used_margin_box_start() f64 { return item.used_margin_start_value }
pub fn (item LayoutItemState) used_margin_box_end() f64 { return item.used_margin_end_value }
pub fn (mut item LayoutItemState) add_margin_box_sizes(start f64, end f64) { item.used_margin_start_value += start; item.used_margin_end_value += end }
pub fn (mut item LayoutItemState) add_main_margin_box_sizes(start f64, end f64) { item.add_margin_box_sizes(start, end) }
pub fn (mut item LayoutItemState) add_cross_margin_box_sizes(start f64, end f64) { item.margin_start_value += start; item.margin_end_value += end }
pub fn (item LayoutItemState) outer_flex_base_size() f64 { return item.flex_base + item.used_margin_start_value + item.used_margin_end_value }
pub fn (item LayoutItemState) outer_hypothetical_main_size() f64 { return item.hypothetical_main + item.used_margin_start_value + item.used_margin_end_value }
pub fn (item LayoutItemState) outer_target_main_size() f64 { return item.target + item.used_margin_start_value + item.used_margin_end_value }
pub fn (item LayoutItemState) hypothetical_cross_size_with_margins() f64 { return item.hypothetical_cross + item.margin_start_value + item.margin_end_value }

pub struct LayoutGridState {
pub mut:
	occupied map[string]bool
	minimum_row int
	maximum_row int = -1
	minimum_column int
	maximum_column int = -1
	children []string
}

fn layout_grid_key(row int, column int) string { return '${row}:${column}' }
pub fn (grid LayoutGridState) min_row_index() int { return grid.minimum_row }
pub fn (grid LayoutGridState) max_row_index() int { return grid.maximum_row }
pub fn (grid LayoutGridState) min_column_index() int { return grid.minimum_column }
pub fn (grid LayoutGridState) max_column_index() int { return grid.maximum_column }
pub fn (grid LayoutGridState) row_count() int { return if grid.maximum_row < grid.minimum_row { 0 } else { grid.maximum_row - grid.minimum_row + 1 } }
pub fn (grid LayoutGridState) column_count() int { return if grid.maximum_column < grid.minimum_column { 0 } else { grid.maximum_column - grid.minimum_column + 1 } }
pub fn (grid LayoutGridState) is_occupied(row int, column int) bool { return grid.occupied[layout_grid_key(row, column)] }
pub fn (grid LayoutGridState) is_area_occupied(row int, column int, row_span int, column_span int) bool { for y := row; y < row + row_span; y++ { for x := column; x < column + column_span; x++ { if grid.is_occupied(y, x) { return true } } }; return false }
pub fn (mut grid LayoutGridState) set_occupied(row int, column int, row_span int, column_span int) { for y := row; y < row + row_span; y++ { for x := column; x < column + column_span; x++ { grid.occupied[layout_grid_key(y, x)] = true } }; grid.minimum_row = math.min(grid.minimum_row, row); grid.maximum_row = math.max(grid.maximum_row, row + row_span - 1); grid.minimum_column = math.min(grid.minimum_column, column); grid.maximum_column = math.max(grid.maximum_column, column + column_span - 1) }
pub fn (mut grid LayoutGridState) set_max_column_index(value int) { grid.maximum_column = math.max(grid.maximum_column, value) }
pub fn (grid LayoutGridState) find_unoccupied_place(row_span int, column_span int) (int, int) { for row := grid.minimum_row; row <= math.max(grid.minimum_row, grid.maximum_row + 1); row++ { for column := grid.minimum_column; column <= math.max(grid.minimum_column, grid.maximum_column + 1); column++ { if !grid.is_area_occupied(row, column, row_span, column_span) { return row, column } } }; return grid.maximum_row + 1, grid.minimum_column }
pub fn (mut grid LayoutGridState) calculate_row_column_grid(items []LayoutItemState) { for item in items { grid.set_occupied(item.row, item.column, item.row_span, item.column_span) } }
pub fn (grid LayoutGridState) occupancy_grid() map[string]bool { return grid.occupied.clone() }
pub fn (grid LayoutGridState) for_each_child_box_matching(kind string) []string { return grid.children.filter(it.contains(kind)) }
pub fn (grid LayoutGridState) is_table_row(value string) bool { return value.contains('row') && !value.contains('group') }
pub fn (grid LayoutGridState) is_table_row_group(value string) bool { return value.contains('row-group') }
pub fn (grid LayoutGridState) is_table_column_group(value string) bool { return value.contains('column-group') }

pub struct LayoutTableState {
pub mut:
	edges []f64
	columns []string
}
pub fn (mut table LayoutTableState) collect_cell_conflicting_edges(values []f64) { table.edges << values }
pub fn (mut table LayoutTableState) collect_row_conflicting_edges(values []f64) { table.edges << values }
pub fn (mut table LayoutTableState) collect_row_group_conflicting_edges(values []f64) { table.edges << values }
pub fn (mut table LayoutTableState) collect_column_group_conflicting_edges(values []f64) { table.edges << values }
pub fn (mut table LayoutTableState) collect_table_box_conflicting_edges(values []f64) { table.edges << values }
pub fn (table LayoutTableState) collect_conflicting_col_elements() []string { return table.columns.clone() }
pub fn (table LayoutTableState) collect_conflicting_row_group_elements() []f64 { return table.edges.clone() }
pub fn (table LayoutTableState) conflicting_edges() []f64 { return table.edges.clone() }
pub fn (table LayoutTableState) get_col_element(index int) ?string { return if index >= 0 && index < table.columns.len { table.columns[index] } else { none } }

pub struct LayoutTrackState {
pub:
	base_size f64
	flex f64
	gap bool
	auto bool
}
pub fn LayoutTrackState.create_auto() LayoutTrackState { return LayoutTrackState{auto: true} }
pub fn LayoutTrackState.create_from_definition(base_size f64, flex f64) LayoutTrackState { return LayoutTrackState{base_size: base_size, flex: flex} }
pub fn LayoutTrackState.create_gap(size f64) LayoutTrackState { return LayoutTrackState{base_size: size, gap: true} }

pub struct LayoutFlexLineState {
pub:
	grow_factors []f64
	shrink_factors []f64
	bases []f64
}
pub fn (line LayoutFlexLineState) sum_of_flex_factor_of_unfrozen_items() f64 { return layout_sum(line.grow_factors) }
pub fn (line LayoutFlexLineState) sum_of_scaled_flex_shrink_factor_of_unfrozen_items() f64 { mut total := 0.0; for index, factor in line.shrink_factors { if index < line.bases.len { total += factor * line.bases[index] } }; return total }

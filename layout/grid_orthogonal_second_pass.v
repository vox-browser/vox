module layout

fn grid_has_orthogonal_items(container &Node, placements []GridItemPlacement) bool {
	for placement in placements {
		if grid_is_vertical(container) != grid_is_vertical(placement.item) { return true }
	}
	return false
}

// Resolving rows can give an orthogonal item's inline axis its first definite
// constraint. Recompute content-sized columns from that constraint before
// distributing their remaining space. Flexible/subgrid axes retain their
// dedicated sizing paths. Anonymous table wrappers also keep their dedicated
// percentage-height and intrinsic-width measurements.
fn update_orthogonal_grid_column_contributions(mut state LayoutState, container &Node, mut columns []GridTrack, rows []GridTrack, placements []GridItemPlacement, row_gap CSSPixels, column_gap CSSPixels, available_width AvailableSize) bool {
	if columns.any(it.flexible) { return false }
	for index in 0 .. columns.len {
		columns[index].base_size_frozen = false
		columns[index].growth_limit_frozen = false
		if columns[index].auto_max { columns[index].has_growth_limit = false }
	}

	mut changed := false
	for placement in placements {
		item := placement.item
		if grid_is_vertical(container) == grid_is_vertical(item) || !grid_is_vertical(item) || item.is_table_wrapper() {
			continue
		}
		style := item.computed_values()
		if !style.size_value(.height).is_auto()
			|| property_is_auto(style, .margin_top) || property_is_auto(style, .margin_bottom) {
			continue
		}
		styled := item.as_node_with_style() or { continue }
		box := item.as_box() or { continue }
		mut values := state.get_mutable(styled)
		area_height := grid_track_range_size(rows, placement.row, placement.row_span, row_gap)
		values.set_content_height(css_pixels_max(CSSPixels.new(0), area_height.minus(flex_or_grid_item_outer_block_edges(values))))
		values.set_has_definite_height(true)
		previous_width := values.content_width()
		previous_definite_width := values.has_definite_width()
		values.set_indefinite_content_width()
		minimum := intrinsic_outer_width_contribution(mut state, box, .min_content).plus(placement.sizing_extra(true))
		maximum := intrinsic_outer_width_contribution(mut state, box, .max_content).plus(placement.sizing_extra(true))
		values.set_content_width(previous_width)
		values.set_has_definite_width(previous_definite_width)
		before := grid_track_range_size(columns, placement.column, placement.column_span, column_gap)
		distribute_grid_item_contribution_across_intrinsic_track_bases(mut columns, placement.column, placement.column_span, column_gap, minimum, .minimum_contribution)
		distribute_grid_item_contribution_across_intrinsic_track_bases(mut columns, placement.column, placement.column_span, column_gap, minimum, .min_content_contribution)
		distribute_grid_item_contribution_across_intrinsic_track_growth_limits(mut columns, placement.column, placement.column_span, column_gap, maximum, .max_content_maximum)
		if grid_track_range_size(columns, placement.column, placement.column_span, column_gap) != before {
			changed = true
		}
	}
	if changed {
		finalize_grid_track_growth_limits(mut columns)
		maximize_grid_tracks(mut columns, available_width, column_gap, none)
	}
	return changed
}

fn grid_has_orthogonal_children(container &Node) bool {
 for item in ordered_grid_items(container) {
  if grid_is_vertical(container)!=grid_is_vertical(item) { return true }
 }
 return false
}

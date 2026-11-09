module layout

// Physical x tracks are sized before physical y tracks. Vertical items need
// that later inline constraint even when they share the grid's writing mode.
fn grid_has_orthogonal_items(container &Node, placements []GridItemPlacement) bool {
	for placement in placements {
		if grid_is_vertical(placement.item) || grid_is_vertical(container) != grid_is_vertical(placement.item) { return true }
	}
	return false
}

// A fixed row range already constrains a vertical item's inline size before
// column sizing. Seeding it now avoids measuring that item with an unbounded
// inline axis, then retaining an oversized column in the second pass.
fn initialize_orthogonal_grid_inline_sizes(mut state LayoutState, container &Node, placements []GridItemPlacement, rows []GridTrack, gap CSSPixels) {
 mut parent := state.get_mutable(container.as_node_with_style() or { return })
 mut effective_gap := gap
 if parent.has_definite_height() && rows.all(!it.intrinsic && !it.flexible && it.flex==0) {
  _,effective_gap=grid_block_content_geometry(container,parent.content_height(),rows,gap)
 }
 for placement in placements {
  item := placement.item
  if !grid_is_vertical(item) || placement.row<0 || placement.row+placement.row_span>rows.len { continue }
  mut definite := true
  for track in rows[placement.row..placement.row+placement.row_span] {
   if track.intrinsic || track.flexible || track.flex>0 { definite=false;break }
  }
  if !definite { continue }
  styled := item.as_node_with_style() or { continue }
  mut used := state.get_mutable(styled)
  used.set_containing_block_used_values(parent)
  resolve_box_model_edges(item.computed_values(),mut used,parent.content_width().to_double())
  area := grid_track_range_size(rows,placement.row,placement.row_span,effective_gap)
  if height := resolve_layout_content_size(item,item.computed_values().size_value(.height),area,used,false) {
   used.set_content_height(height)
   used.set_has_definite_height(true)
  } else if item.computed_values().size_value(.height).is_auto() && grid_block_alignment(container,item) in [.normal,.stretch]
   && !property_is_auto(item.computed_values(),.margin_top) && !property_is_auto(item.computed_values(),.margin_bottom) {
   used.set_content_height(css_pixels_max(CSSPixels.new(0),area.minus(flex_or_grid_item_outer_block_edges(used))))
   used.set_has_definite_height(true)
  }
 }
}

// Resolving rows can give an orthogonal item's inline axis its first definite
// constraint. Recompute content-sized columns from that constraint before
// distributing their remaining space. Indefinite flexible columns also update
// their content-based flex fraction. Anonymous table wrappers keep their
// percentage-height and intrinsic-width measurements.
fn update_orthogonal_grid_column_contributions(mut state LayoutState, container &Node, mut columns []GridTrack, rows []GridTrack, placements []GridItemPlacement, row_gap CSSPixels, column_gap CSSPixels, available_width AvailableSize, baseline_shims map[voidptr]CSSPixels) bool {
	for index in 0 .. columns.len {
		columns[index].base_size_frozen = false
		columns[index].growth_limit_frozen = false
		if columns[index].auto_max { columns[index].has_growth_limit = false }
	}

	mut changed := false
	for placement in placements {
		item := placement.item
		if !grid_is_vertical(item) || item.is_table_wrapper() {
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
		stretch := css_pixels_max(CSSPixels.new(0),area_height.minus(flex_or_grid_item_outer_block_edges(values)))
		height := if grid_block_alignment(container,item) in [.normal,.stretch] { stretch } else { calculate_fit_content_height(mut state,box,values.content_width(),AvailableSize.make_definite(area_height)) }
		values.set_content_height(clamp_layout_content_size(item,height,area_height,values,false))
		values.set_has_definite_height(true)
		previous_width := values.content_width()
		previous_definite_width := values.has_definite_width()
		values.set_indefinite_content_width()
		minimum := intrinsic_outer_width_contribution(mut state,box,.min_content).plus(placement.sizing_extra(true))
		maximum := intrinsic_outer_width_contribution(mut state,box,.max_content).plus(placement.sizing_extra(true))
		values.set_content_width(previous_width)
		values.set_has_definite_width(previous_definite_width)
		before := grid_track_range_size(columns, placement.column, placement.column_span, column_gap)
		if grid_track_range_crosses_flexible_track(columns,placement.column,placement.column_span) {
			if available_width.is_definite() { continue }
			fraction := grid_flex_fraction_for_range(columns,placement.column,placement.column_span,maximum.plus(baseline_shims[voidptr(item)]),column_gap)
			for index in placement.column..placement.column+placement.column_span {
				if index>=0 && index<columns.len && columns[index].flex>0 {
					columns[index].base_size=css_pixels_max(columns[index].base_size,CSSPixels.nearest_value_for(columns[index].flex).times_fraction(fraction))
				}
			}
		}
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
  if grid_is_vertical(item) || grid_is_vertical(container)!=grid_is_vertical(item) { return true }
 }
 return false
}

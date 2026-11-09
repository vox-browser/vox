module layout

// Grid percentage edges resolve against the logical inline size of the grid
// area. Before intrinsic sizing, only fixed track ranges provide that basis;
// percentages that depend on the intrinsic range contribute zero.
fn initialize_grid_item_percentage_bases(mut state LayoutState, container &Node, placements []GridItemPlacement, columns []GridTrack, row_basis CSSPixels, column_gap CSSPixels, row_gap CSSPixels, height_definite bool, implicit_rows int, required_rows int) {
	vertical := grid_is_vertical(container)
	tracks := if vertical {
		resolve_grid_axis_tracks_in_state(mut state, container, false, row_basis, row_gap, height_definite, implicit_rows, if required_rows > 0 {
			required_rows
		} else {
			1
		})
	} else {
		columns
	}
	gap := if vertical { row_gap } else { column_gap }
	for placement in placements {
		start := if vertical { placement.row } else { placement.column }
		span := if vertical { placement.row_span } else { placement.column_span }
		mut definite := start >= 0 && start + span <= tracks.len
		if definite {
			for track in tracks[start..start + span] {
				if track.intrinsic || track.flexible || track.flex > 0 {
					definite = false
					break
				}
			}
		}
		basis := if definite {
			grid_track_range_size(tracks, start, span, gap)
		} else {
			CSSPixels.new(0)
		}
		if styled := placement.item.as_node_with_style() {
			state.get_mutable(styled).set_box_model_percentage_basis(basis)
		}
	}
}

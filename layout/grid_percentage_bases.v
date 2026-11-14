module layout

// Grid percentage edges resolve against the logical inline size of the grid
// area. Before intrinsic sizing, only fixed track ranges provide that basis;
// percentages that depend on the intrinsic range contribute zero.
fn initialize_grid_item_percentage_bases(mut state LayoutState, container &Node, placements []GridItemPlacement, columns []GridTrack, row_basis CSSPixels, column_gap CSSPixels, row_gap CSSPixels, height_definite bool, implicit_rows int, required_rows int) {
	vertical := grid_is_vertical(container)
	mut tracks := if vertical {
		resolve_grid_axis_tracks_in_state(mut state, container, false, row_basis, row_gap, height_definite, implicit_rows, required_rows)
	} else {
		columns
	}
	gap := if vertical { row_gap } else { column_gap }
	container_values := state.get(container.as_node_with_style() or { return })
	inline_definite := if vertical {
		height_definite
	} else {
		container_values.has_definite_width()
	}
	inline_size := if vertical {
		container_values.content_height()
	} else {
		container_values.content_width()
	}
	mut fixed_maximum_range := inline_definite
	mut maximum_extent := gap.scaled(f64(if tracks.len > 0 { tracks.len - 1 } else { 0 }))
	for track in tracks {
		if !track.fixed_max || track.flexible || track.flex > 0 {
			fixed_maximum_range = false
			break
		}
		maximum_extent = maximum_extent.plus(css_pixels_max(track.base_size, track.fixed_max_size))
	}
	if fixed_maximum_range && maximum_extent.raw_value() <= inline_size.raw_value() {
		// Definite free space lets every fixed maximum be reached even when
		// its minimum is intrinsic. The area inline size is then known before
		// measuring percentage edges in the perpendicular tracks.
		tracks = tracks.clone()
		for index in 0 .. tracks.len {
			tracks[index].base_size = css_pixels_max(tracks[index].base_size, tracks[index].fixed_max_size)
			tracks[index].intrinsic = false
		}
	}
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

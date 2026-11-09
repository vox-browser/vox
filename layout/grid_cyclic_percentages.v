module layout

// Percentage tracks contribute as auto while their axis is indefinite. Once
// that intrinsic extent is known, resolve them for layout without feeding the
// percentages back into the container's own automatic size.
fn resolve_cyclic_percentage_grid_rows(mut state LayoutState, container &Node, mut rows []GridTrack, extent CSSPixels, gap CSSPixels, implicit_before int, required int) bool {
	resolved := resolve_grid_axis_tracks_in_state(mut state, container, false, extent, gap, true, implicit_before, required)
	if resolved.len != rows.len { return false }
	mut changed := false
	for index, track in resolved {
		if track.fixed_max && !rows[index].fixed_max {
			rows[index] = track
			changed = true
		}
	}
	return changed
}

module layout

import css

fn grid_lanes_columns(node &Node) bool {
	style := node.computed_values()
	direction := if value := style.property(.grid_lanes_direction, .yes) {
		value.css_text.split(' ')[0]
	} else {
		'normal'
	}
	if direction == 'column' { return true }
	if direction == 'row' { return false }
	return !style.grid_template_columns().is_empty() || style.grid_template_rows().is_empty()
}

fn grid_lanes_axis_is_horizontal(node &Node) bool {
	return grid_lanes_columns(node) != grid_is_vertical(node)
}

// The grid sizing machinery is shared, but automatic lane items contribute at
// every position they could occupy before the packing algorithm chooses one.
fn grid_lanes_sizing_placements(container &Node, placements []GridItemPlacement, count int, horizontal bool) []GridItemPlacement {
	if !container.display().is_grid_lanes_inside() || grid_lanes_axis_is_horizontal(container) != horizontal {
		return placements.clone()
	}
	mut result := []GridItemPlacement{}
	for placement in placements {
		style := placement.item.computed_values()
		if !grid_axis_is_auto(grid_axis_placement(container, style, horizontal, true), grid_axis_placement(container, style, horizontal, false)) {
			result << placement
			continue
		}
		span := if horizontal { placement.column_span } else { placement.row_span }
		for start in 0 .. if count - span + 1 > 0 { count - span + 1 } else { 1 } {
			result << GridItemPlacement{ ...placement, column: if horizontal {
				start
			} else {
				placement.column
			}, row: if horizontal { placement.row } else { start } }
		}
	}
	return result
}

fn grid_lanes_tolerance(container &Node, extent CSSPixels) CSSPixels {
	value := container.computed_values().property(.fit_tolerance, .yes) or { return container.computed_values().font_size() }
	if value.css_text == 'normal' { return container.computed_values().font_size() }
	if value.css_text == 'infinite' { return CSSPixels.max() }
	return css.LengthPercentage.from_style_value(value).to_px(layout_length_resolution_context(container), extent)
}

// Native lane running positions and the placement cursor are independent of
// regular grid rows. Explicit placements and spans still use the common line
// resolver and track sizing; each item advances all lanes it spans.
fn pack_grid_lanes(mut state LayoutState, container &Node, mut container_state UsedValues, placements []GridItemPlacement, columns []GridTrack, rows []GridTrack, column_gap CSSPixels, row_gap CSSPixels, column_leading CSSPixels, row_leading CSSPixels, width CSSPixels, height CSSPixels) CSSPixels {
	horizontal := grid_lanes_axis_is_horizontal(container)
	tracks := if horizontal { columns } else { rows }
	if tracks.len == 0 { return CSSPixels.new(0) }
	lane_gap := if horizontal { column_gap } else { row_gap }
	stack_gap := if horizontal { row_gap } else { column_gap }
	lane_extent := if horizontal { width } else { height }
	tolerance := grid_lanes_tolerance(container, lane_extent)
	direction := if value := container.computed_values().property(.grid_lanes_direction, .yes) {
		value.css_text
	} else {
		'normal'
	}
	reverse_tracks := direction.contains('track-reverse')
	reverse_fill := direction.contains('fill-reverse')
	mut running := []CSSPixels{len: tracks.len}
	mut cursor := 0
	mut extent := CSSPixels.new(0)
	for placement in placements {
		item := placement.item
		styled := item.as_node_with_style() or { continue }
		mut values := state.get_mutable(styled)
		// Grid alignment stores the unused grid-area space in margins. Packing
		// advances by the authored margin box rather than that alignment space.
		resolve_box_model_edges(styled.computed_values(), mut values, width.to_double())
		span := grid_lanes_min_int(if horizontal {
			placement.column_span
		} else {
			placement.row_span
		}, tracks.len)
		mut lane := if horizontal { placement.column } else { placement.row }
		auto := grid_axis_is_auto(grid_axis_placement(container, item.computed_values(), horizontal, true), grid_axis_placement(container, item.computed_values(), horizontal, false))
		if auto {
			mut positions := []CSSPixels{}
			mut shortest := CSSPixels.max()
			for start in 0 .. tracks.len - span + 1 {
				mut position := CSSPixels.new(0)
				for j in start .. start + span { position = css_pixels_max(position, running[j]) }
				positions << position
				shortest = css_pixels_min(shortest, position)
			}
			lane = -1
			for start in cursor .. positions.len {
				if positions[start].raw_value() <= shortest.plus(tolerance).raw_value() {
					lane = start
					break
				}
			}
			if lane < 0 {
				for start, position in positions {
					if position.raw_value() <= shortest.plus(tolerance).raw_value() {
						lane = start
						break
					}
				}
			}
			if lane < 0 { lane = 0 }
			cursor = lane + span
		}
		lane = grid_lanes_max_int(0, grid_lanes_min_int(lane, tracks.len - span))
		if reverse_tracks { lane = tracks.len - lane - span }
		mut stack_start := CSSPixels.new(0)
		for j in lane .. lane + span { stack_start = css_pixels_max(stack_start, running[j]) }
		area := grid_track_range_size(tracks, lane, span, lane_gap)
		if horizontal && property_is_auto(item.computed_values(), .width) && grid_inline_alignment(container, item) in [
			.normal,
			.stretch,
		] {
			desired := clamp_layout_content_size(item, area.minus(flex_or_grid_item_outer_inline_edges(values)), area, values, true)
			if desired != values.content_width() {
				values = layout_independent_child(mut state, item, mut container_state, area, if container_state.has_definite_height() {
					?CSSPixels(container_state.content_height())
				} else {
					none
				}, desired, none)
			}
		}
		if !horizontal && property_is_auto(item.computed_values(), .height) && grid_block_alignment(container, item) in [
			.normal,
			.stretch,
		] {
			desired := clamp_layout_content_size(item, area.minus(flex_or_grid_item_outer_block_edges(values)), area, values, false)
			if desired != values.content_height() {
				values = layout_independent_child(mut state, item, mut container_state, width, area, values.content_width(), desired)
			}
		}
		size := if horizontal { values.margin_box_height() } else { values.margin_box_width() }
		end := stack_start.plus(css_pixels_max(CSSPixels.new(0), size))
		for j in lane .. lane + span { running[j] = end.plus(stack_gap) }
		extent = css_pixels_max(extent, end)
		lane_start := if horizontal {
			grid_physical_column_offset(container, width, tracks, lane, span, lane_gap, column_leading)
		} else {
			grid_physical_row_offset(container, height, tracks, lane, span, lane_gap, row_leading)
		}
		if horizontal {
			values.set_content_x(lane_start.plus(values.margin_box_left()))
			values.set_content_y(stack_start.plus(values.margin_box_top()))
		} else {
			values.set_content_y(lane_start.plus(values.margin_box_top()))
			values.set_content_x(stack_start.plus(values.margin_box_left()))
		}
	}
	// Reverse stacking uses the completed range rather than an indefinite input.
	if grid_axis_reversed(container, !horizontal) != reverse_fill {
		for placement in placements {
			mut values := state.get_mutable(placement.item.as_node_with_style() or { continue })
			if horizontal {
				values.set_content_y(extent.minus(values.offset.y()).minus(values.content_height()))
			} else {
				values.set_content_x(extent.minus(values.offset.x()).minus(values.content_width()))
			}
		}
	}
	return extent
}

fn grid_lanes_min_int(a int, b int) int { return if a < b { a } else { b } }

fn grid_lanes_max_int(a int, b int) int { return if a > b { a } else { b } }

module layout

import css

struct GridBaselineSubject {
	item &Node
	group int
	from_end bool
	area_start CSSPixels
	area_end CSSPixels
	baseline CSSPixels
	outer_size CSSPixels
}

fn grid_baseline_from_low(state &LayoutState, container &Node, item &Node, horizontal bool, set BaselineSet, depth int) CSSPixels {
	styled := item.as_node_with_style() or { return CSSPixels.new(0) }
	used := state.get(styled)
	item_horizontal := item.computed_values().writing_mode() == .horizontal_tb
	if !horizontal && item_horizontal { return layout_box_baseline(state,item,set) }
	if horizontal && !item_horizontal && depth < 64 {
		if used.line_boxes.len > 0 {
			for i in 0 .. used.line_boxes.len {
				index := if set == .first { i } else { used.line_boxes.len-1-i }
				line := used.line_boxes[index]
				if line.is_empty() { continue }
				// Vertical text shares a central baseline. Line offsets retain
				// logical block progression, even after physical placement.
				central := resolve_dominant_baseline_metric(container.computed_values()) == .central
				logical := line.bottom_.minus(line.block_length()).plus(if central { line.block_length().divided_by_float(2) } else { line.baseline() })
				physical := if grid_axis_reversed(item,true) { used.content_width().minus(logical) } else { logical }
				return used.margin_box_left().plus(physical)
			}
		}
		if child := layout_box_child_to_derive_baseline_from(state,item,set) {
			child_style := child.as_node_with_style() or { return used.margin_box_width() }
			child_used := state.get(child_style)
			return used.margin_box_left().plus(child_used.offset.x().minus(child_used.margin_box_left()))
				.plus(grid_baseline_from_low(state,container,child,true,set,depth+1))
		}
	}
	// An orthogonal item has no baseline along this axis. Synthesize from
	// its border box, using the context's central or alphabetic baseline.
	central := resolve_dominant_baseline_metric(container.computed_values()) == .central
	if horizontal {
		return used.margin_left.plus(if central { used.border_box_width().divided_by_float(2) } else if grid_axis_reversed(container,true) { CSSPixels.new(0) } else { used.border_box_width() })
	}
	return used.margin_top.plus(if central { used.border_box_height().divided_by_float(2) } else { used.border_box_height() })
}

fn align_grid_baseline_subjects(mut state LayoutState, container &Node, placements []GridItemPlacement,
	width CSSPixels, height CSSPixels, columns []GridTrack, rows []GridTrack,
	column_gap CSSPixels, row_gap CSSPixels, column_leading CSSPixels, row_leading CSSPixels) {
	for horizontal in [false,true] {
		mut subjects := []GridBaselineSubject{}
		mut shared := map[int]CSSPixels{}
		for placement in placements {
			item := placement.item
			words := grid_alignment_text(container,item,horizontal).split(' ')
			if words.len == 0 || words.last() != 'baseline' { continue }
			computed := item.computed_values()
			if property_is_auto(computed,if horizontal { css.PropertyID.margin_left } else { css.PropertyID.margin_top })
				|| property_is_auto(computed,if horizontal { css.PropertyID.margin_right } else { css.PropertyID.margin_bottom }) { continue }
			styled := item.as_node_with_style() or { continue }
			mut used := state.get_mutable(styled)
			area_width := grid_track_range_size(columns,placement.column,placement.column_span,column_gap)
			// Alignment shims are not authored margins or baseline descent.
			if horizontal {
				used.margin_left = css_px(computed.length_percentage_to_px(.margin_left,area_width.to_double()) or { 0.0 })
				used.margin_right = css_px(computed.length_percentage_to_px(.margin_right,area_width.to_double()) or { 0.0 })
			} else {
				used.margin_top = css_px(computed.length_percentage_to_px(.margin_top,area_width.to_double()) or { 0.0 })
				used.margin_bottom = css_px(computed.length_percentage_to_px(.margin_bottom,area_width.to_double()) or { 0.0 })
			}
			last := words[0] == 'last'
			parallel := grid_is_vertical(container) == grid_is_vertical(item)
			opposite := parallel && grid_axis_reversed(container,horizontal) != grid_axis_reversed(item,horizontal)
			logical_end := last != opposite
			from_end := logical_end != grid_axis_reversed(container,horizontal)
			track := if horizontal { placement.column } else { placement.row }
			span := if horizontal { placement.column_span } else { placement.row_span }
			group_track := track + if logical_end { span-1 } else { 0 }
			group := group_track*2 + if from_end { 1 } else { 0 }
			start := if horizontal {
				grid_physical_column_offset(container,width,columns,placement.column,placement.column_span,column_gap,column_leading)
			} else {
				grid_physical_row_offset(container,height,rows,placement.row,placement.row_span,row_gap,row_leading)
			}
			extent := if horizontal { area_width } else { grid_track_range_size(rows,placement.row,placement.row_span,row_gap) }
			baseline := grid_baseline_from_low(state,container,item,horizontal,if last { .last } else { .first },0)
			outer := if horizontal { used.margin_box_width() } else { used.margin_box_height() }
			candidate := if from_end { start.plus(extent).minus(outer.minus(baseline)) } else { start.plus(baseline) }
			if previous := shared[group] {
				shared[group] = if from_end { css_pixels_min(previous,candidate) } else { css_pixels_max(previous,candidate) }
			} else { shared[group] = candidate }
			subjects << GridBaselineSubject{item:item,group:group,from_end:from_end,area_start:start,area_end:start.plus(extent),baseline:baseline,outer_size:outer}
		}
		for subject in subjects {
			styled := subject.item.as_node_with_style() or { continue }
			mut used := state.get_mutable(styled)
			baseline := shared[subject.group] or { continue }
			if horizontal { used.set_content_x(baseline.minus(subject.baseline).plus(used.margin_box_left())) }
			else { used.set_content_y(baseline.minus(subject.baseline).plus(used.margin_box_top())) }
		}
	}
}

fn publish_grid_content_baselines(mut state LayoutState, container &Node, mut container_used UsedValues, placements []GridItemPlacement) {
	if grid_is_vertical(container) || placements.len == 0 { return }
	mut first := placements[0]
	mut last := placements[0]
	for placement in placements {
		if placement.row < first.row || (placement.row == first.row && placement.column < first.column) { first = placement }
		if placement.row+placement.row_span > last.row+last.row_span
			|| (placement.row+placement.row_span == last.row+last.row_span && placement.column+placement.column_span > last.column+last.column_span) { last = placement }
	}
	// A shared baseline in the outermost track takes precedence over a
	// non-participating item which happens to occur earlier in grid order.
	for placement in placements {
		words := grid_alignment_text(container,placement.item,false).split(' ')
		if words.len == 0 || words.last() != 'baseline' { continue }
		if words[0] != 'last' && placement.row == first.row { first = placement }
		if words[0] == 'last' && placement.row+placement.row_span == last.row+last.row_span { last = placement }
	}
	mut first_baseline := ?CSSPixels(none)
	mut last_baseline := ?CSSPixels(none)
	for index,placement in [first,last] {
		styled := placement.item.as_node_with_style() or { continue }
		used := state.get(styled)
		baseline := grid_baseline_from_low(state,container,placement.item,false,if index == 0 { .first } else { .last },0)
		value := used.offset.y().plus(baseline).minus(used.margin_box_top())
		if index == 0 { first_baseline = value }
		else { last_baseline = value }
	}
	container_used.set_derived_baselines(first_baseline,last_baseline)
}

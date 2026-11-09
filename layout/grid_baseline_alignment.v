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
	parent_offset CSSPixels
}

// A percentage preferred size stays cyclic with an intrinsic track even
// after the final grid area gives that percentage a numeric value.
fn grid_baseline_size_is_cyclic(state &LayoutState,container &Node,item &Node,horizontal bool,tracks []GridTrack,start int,span int) bool {
 if !item.computed_values().size_value(if horizontal { css.PropertyID.width } else { .height }).contains_percentage() { return false }
 if grid_track_range_crosses_intrinsic_sizing_track(tracks,start,span) { return true }
 used := state.get(container.as_node_with_style() or { return false })
 definite := if horizontal { used.has_definite_width() } else { used.has_definite_height() }
 return !definite && grid_track_range_crosses_flexible_track(tracks,start,span)
}

// Opposed writing directions form distinct first/last baseline groups.
// An orthogonal subject has only a synthesized baseline and retains the
// alignment context's direction instead of joining the opposite group.
fn grid_baseline_group_reversed(container &Node,item &Node,horizontal bool) bool {
 return if grid_is_vertical(item)==horizontal { grid_axis_reversed(item,horizontal) } else { grid_axis_reversed(container,horizontal) }
}

fn grid_alignment_baseline_from_low(state &LayoutState,container &Node,item &Node,horizontal bool,set BaselineSet,reversed bool) CSSPixels {
 if horizontal && !grid_is_vertical(item) && resolve_dominant_baseline_metric(container.computed_values())!=.central {
  used := state.get(item.as_node_with_style() or { return CSSPixels.new(0) })
  return used.margin_left.plus(if reversed { used.border_box_width() } else { CSSPixels.new(0) })
 }
 return grid_baseline_from_low(state,container,item,horizontal,set,0)
}

// Baselines of scroll containers are taken at the initial scroll position
// and clamped to their border edges (CSS Align 3 section 9.1).
fn grid_baseline_from_low(state &LayoutState, container &Node, item &Node, horizontal bool, set BaselineSet, depth int) CSSPixels {
 value := grid_content_baseline_from_low(state,container,item,horizontal,set,depth)
 if !item.is_scroll_container() { return value }
 used := state.get(item.as_node_with_style() or { return value })
 start := if horizontal { used.margin_left } else { used.margin_top }
 extent := if horizontal { used.border_box_width() } else { used.border_box_height() }
 return css_pixels_max(start,css_pixels_min(value,start.plus(extent)))
}

fn grid_content_baseline_from_low(state &LayoutState, container &Node, item &Node, horizontal bool, set BaselineSet, depth int) CSSPixels {
	styled := item.as_node_with_style() or { return CSSPixels.new(0) }
	used := state.get(styled)
	item_horizontal := item.computed_values().writing_mode() == .horizontal_tb
	if horizontal && !item_horizontal && !item.has_size_containment() {
		if baseline := used.derived_vertical_baseline(set) { return used.margin_box_left().plus(baseline) }
	}
	if !horizontal && item_horizontal { return layout_box_baseline_in_context(state,item,set,true,false) }
	if horizontal && !item_horizontal && !item.has_size_containment() && depth < 64 {
		if used.line_boxes.len > 0 {
			for i in 0 .. used.line_boxes.len {
				index := if set == .first { i } else { used.line_boxes.len-1-i }
				line := used.line_boxes[index]
				if line.is_empty() { continue }
    if line.has_block_level_box() {
     child := line.fragments_[0].layout_node()
     child_used := state.get(child.as_node_with_style() or { continue })
     return used.margin_box_left().plus(child_used.offset.x().minus(child_used.margin_box_left())).plus(grid_baseline_from_low(state,container,child,true,set,depth+1))
    }
				// Vertical text shares a central baseline. Line offsets retain
				// logical block progression, even after physical placement.
				central := resolve_dominant_baseline_metric(container.computed_values()) == .central
				logical := line.bottom_.minus(line.block_length()).plus(if central && resolve_dominant_baseline_metric(item.computed_values()) != .central { line.block_length().divided_by_float(2) } else { line.baseline() })
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
		return used.margin_left.plus(if central { used.border_box_width().divided_by_float(2) } else if container.computed_values().writing_mode()==.sideways_lr && !grid_axis_reversed(container,true) { used.border_box_width() } else { CSSPixels.new(0) })
	}
	return used.margin_top.plus(if central { used.border_box_height().divided_by_float(2) } else { used.border_box_height() })
}

fn align_grid_baseline_subjects(mut state LayoutState, container &Node, column_subjects []GridItemPlacement, row_subjects []GridItemPlacement,
	width CSSPixels, height CSSPixels, columns []GridTrack, rows []GridTrack,
	column_gap CSSPixels, row_gap CSSPixels, column_leading CSSPixels, row_leading CSSPixels) {
	for horizontal in [false,true] {
		if container.display().is_grid_lanes_inside() && grid_lanes_axis_is_horizontal(container)!=horizontal { continue }
		mut subjects := []GridBaselineSubject{}
		mut shared := map[int]CSSPixels{}
		for placement in if horizontal { column_subjects } else { row_subjects } {
			item := placement.item
			words := grid_alignment_text(container,item,horizontal).split(' ')
			if words.len == 0 || words.last() != 'baseline' { continue }
   if grid_baseline_size_is_cyclic(state,container,item,horizontal,if horizontal { columns } else { rows },if horizontal { placement.column } else { placement.row },if horizontal { placement.column_span } else { placement.row_span }) { continue }
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
			reversed := grid_baseline_group_reversed(container,item,horizontal)
			opposite := grid_axis_reversed(container,horizontal) != reversed
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
			baseline := grid_alignment_baseline_from_low(state,container,item,horizontal,if last { .last } else { .first },reversed)
			outer := if horizontal { used.margin_box_width() } else { used.margin_box_height() }
			axis_reversed := grid_axis_reversed(container,horizontal)
			extra_start := if horizontal { if axis_reversed { placement.inline_end_extra } else { placement.inline_start_extra } } else { if axis_reversed { placement.block_end_extra } else { placement.block_start_extra } }
			extra_end := if horizontal { if axis_reversed { placement.inline_start_extra } else { placement.inline_end_extra } } else { if axis_reversed { placement.block_start_extra } else { placement.block_end_extra } }
			candidate := if from_end { start.plus(extent).minus(outer.minus(baseline).plus(extra_end)) } else { start.plus(baseline).plus(extra_start) }
			if previous := shared[group] {
				shared[group] = if from_end { css_pixels_min(previous,candidate) } else { css_pixels_max(previous,candidate) }
			} else { shared[group] = candidate }
			subjects << GridBaselineSubject{item:item,group:group,from_end:from_end,area_start:start,area_end:start.plus(extent),baseline:baseline,outer_size:outer,parent_offset:grid_baseline_parent_offset(state,container,item,horizontal)}
		}
		for subject in subjects {
			styled := subject.item.as_node_with_style() or { continue }
			mut used := state.get_mutable(styled)
			baseline := shared[subject.group] or { continue }
			if horizontal { used.set_content_x(baseline.minus(subject.baseline).plus(used.margin_box_left()).minus(subject.parent_offset)) }
			else { used.set_content_y(baseline.minus(subject.baseline).plus(used.margin_box_top()).minus(subject.parent_offset)) }
		}
	}
}

// Flattened subgrid subjects align in their ancestor's tracks while retaining
// offsets relative to their own containing block.
fn grid_baseline_parent_offset(state &LayoutState,container &Node,item &Node,horizontal bool) CSSPixels {
 mut result := CSSPixels.new(0)
 mut parent := item.containing_block()
 for _ in 0..64 {
  node := unsafe { &Node(parent or { break }) }
  if layout_nodes_same(node,container) { break }
  used := state.get(node.as_node_with_style() or { break })
  result=result.plus(if horizontal { used.offset.x() } else { used.offset.y() })
  parent=node.containing_block()
 }
 return result
}

fn grid_baseline_track(placement GridItemPlacement, horizontal bool, end bool) int {
 start := if horizontal { placement.column } else { placement.row }
 span := if horizontal { placement.column_span } else { placement.row_span }
 return start + if end { span } else { 0 }
}

fn publish_grid_content_baselines(mut state LayoutState, container &Node, mut container_used UsedValues, placements []GridItemPlacement) {
	if placements.len == 0 { return }
	vertical := grid_is_vertical(container)
	mut first := placements[0]
	mut last := placements[0]
	for placement in placements {
		if grid_baseline_track(placement,vertical,false) < grid_baseline_track(first,vertical,false) || (grid_baseline_track(placement,vertical,false) == grid_baseline_track(first,vertical,false) && grid_baseline_track(placement,!vertical,false) < grid_baseline_track(first,!vertical,false)) { first = placement }
		if grid_baseline_track(placement,vertical,true) > grid_baseline_track(last,vertical,true)
			|| (grid_baseline_track(placement,vertical,true) == grid_baseline_track(last,vertical,true) && grid_baseline_track(placement,!vertical,true) > grid_baseline_track(last,!vertical,true)) { last = placement }
	}
	// A shared baseline in the outermost track takes precedence over a
	// non-participating item which happens to occur earlier in grid order.
	mut first_has_preferred,mut last_has_preferred := false,false
	for placement in placements {
		words := grid_alignment_text(container,placement.item,vertical).split(' ')
		if words.len == 0 || words.last() != 'baseline' { continue }
		if grid_baseline_track(placement,vertical,false) == grid_baseline_track(first,vertical,false) && (!first_has_preferred || words[0] != 'last') {
			first = placement
			first_has_preferred = words[0] != 'last'
		}
		if grid_baseline_track(placement,vertical,true) == grid_baseline_track(last,vertical,true) && (!last_has_preferred || words[0] == 'last') {
			last = placement
			last_has_preferred = words[0] == 'last'
		}
	}
	mut first_baseline := ?CSSPixels(none)
	mut last_baseline := ?CSSPixels(none)
	for index,placement in [first,last] {
		styled := placement.item.as_node_with_style() or { continue }
		used := state.get(styled)
		words := grid_alignment_text(container,placement.item,vertical).split(' ')
		preference := if words.len > 0 && words.last() == 'baseline' {
			if words[0] == 'last' { BaselineSet.last } else { BaselineSet.first }
		} else if index == 0 { BaselineSet.first } else { BaselineSet.last }
		baseline := grid_baseline_from_low(state,container,placement.item,vertical,preference,0)
		value := if vertical { used.offset.x().plus(baseline).minus(used.margin_box_left()) } else { used.offset.y().plus(baseline).minus(used.margin_box_top()) }
		if index == 0 { first_baseline = value }
		else { last_baseline = value }
	}
	if vertical { container_used.set_derived_vertical_baselines(first_baseline,last_baseline) }
	else { container_used.set_derived_baselines(first_baseline,last_baseline) }
}

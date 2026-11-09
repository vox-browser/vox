module layout

import css

struct VerticalMulticolItem {
 node &Node
 spanning bool
 extent CSSPixels
mut:
 block_position CSSPixels
 column int
}

struct VerticalMulticolGroup {
 first int
 end int
 spanning bool
 extent CSSPixels
}

// Atomic vertical columns share a block-size and progress in the inline
// direction. Spanners split column sets and occupy the full inline extent.
fn layout_vertical_multicol_atomic_blocks(mut state LayoutState, box &Node, mut values UsedValues, mode LayoutMode, available AvailableSpace) ?FormattingContextResult {
 computed := box.computed_values()
 if !grid_is_vertical(box) || !computed.establishes_multi_column_container()
  || !computed.size_value(.width).is_auto() { return none }
 mut children := []&Node{}
 for child in box.children() {
  if can_skip_anonymous_text_run(child) { continue }
  if child.as_box() == none || !multicol_atomic_child_supported(child) { return none }
  style := child.computed_values()
  children << child
 }
 if children.len == 0 { return none }
 mut inline_size := if available.height.is_definite() { available.height.to_px_or_zero() } else { values.content_height() }
 count := determine_used_multicol_column_count(box,inline_size) or { return none }
 if count < 2 { return none }
 gap := multicol_column_gap(box,inline_size)
 if inline_size.raw_value() <= 0 {
  mut largest := CSSPixels.new(0)
  for child in children {
   child_box := child.as_box() or { return none }
   largest = css_pixels_max(largest,calculate_max_content_height(mut state,child_box,CSSPixels.new(0)))
  }
  inline_size = largest.scaled(f64(count)).plus(gap.scaled(f64(count-1)))
 }
 column_size := determine_used_multicol_column_width(box,inline_size,count)
 mut items := []VerticalMulticolItem{}
 for child in children {
  styled := child.as_node_with_style() or { return none }
  child_box := child.as_box() or { return none }
  style := child.computed_values()
  spanning := style.column_span() == .all
  available_inline := if spanning { inline_size } else { column_size }
  mut initial := state.get_mutable(styled)
  initial.set_containing_block_used_values(values)
  resolve_box_model_edges(style,mut initial,inline_size.to_double())
  height := css_pixels_max(CSSPixels.new(0),available_inline.minus(flex_or_grid_item_outer_block_edges(initial)))
  initial.set_content_height(height)
  initial.set_has_definite_height(true)
  width := resolve_layout_content_size(child,style.size_value(.width),values.content_width(),initial,true) or { calculate_max_content_width(mut state,child_box) }
  used := layout_independent_child(mut state,child,mut values,values.content_width(),inline_size,width,height)
  if !spanning && style.break_inside() !in [.avoid,.avoid_column] && used.line_boxes.len>1 { return none }
  items << VerticalMulticolItem{node:child,spanning:spanning,extent:used.margin_box_width()}
 }
 mut groups := []VerticalMulticolGroup{}
 mut first := 0
 for first < items.len {
  if items[first].spanning {
   groups << VerticalMulticolGroup{first:first,end:first+1,spanning:true,extent:items[first].extent}
   first++
   continue
  }
  mut end := first
  mut tops,mut bottoms := []CSSPixels{},[]CSSPixels{}
  mut total := CSSPixels.new(0)
  mut forced := [0]
  for end < items.len && !items[end].spanning {
   if end > first && (items[end].node.computed_values().break_before() == .column || items[end-1].node.computed_values().break_after() == .column) { forced << end-first }
   tops << total
   total = total.plus(items[end].extent)
   bottoms << total
   end++
  }
  breaks := if forced.len > 1 { MulticolLineBreaks{starts:forced} } else { balance_multicol_blocks(tops,bottoms,total,count) }
  mut extent := CSSPixels.new(0)
  for column,start in breaks.starts {
   last := if column+1 < breaks.starts.len { breaks.starts[column+1] } else { end-first }
   extent = css_pixels_max(extent,bottoms[last-1].minus(tops[start]))
   for index in start .. last {
    items[first+index].column = column
    items[first+index].block_position = tops[index].minus(tops[start])
   }
  }
  groups << VerticalMulticolGroup{first:first,end:end,extent:extent}
  first = end
 }
 mut block_size := CSSPixels.new(0)
 for group in groups { block_size = block_size.plus(group.extent) }
 values.set_content_width(block_size)
 values.set_content_height(inline_size)
 reverse_block := grid_axis_reversed(box,true)
 reverse_inline := grid_axis_reversed(box,false)
 mut cursor := CSSPixels.new(0)
 mut first_baseline := if reverse_block { CSSPixels.min() } else { CSSPixels.max() }
 mut last_baseline := if reverse_block { CSSPixels.max() } else { CSSPixels.min() }
 for group in groups {
  for index in group.first .. group.end {
   item := items[index]
   mut used := state.get_mutable(item.node.as_node_with_style() or { continue })
   block_start := cursor.plus(item.block_position)
   x := if reverse_block { block_size.minus(block_start).minus(item.extent).plus(used.margin_box_left()) } else { block_start.plus(used.margin_box_left()) }
   column_inline_size := if group.spanning { inline_size } else { column_size }
   inline_start := column_size.plus(gap).scaled(f64(item.column))
   y := if reverse_inline { inline_size.minus(inline_start).minus(column_inline_size).plus(used.margin_box_top()) } else { inline_start.plus(used.margin_box_top()) }
   used.set_content_offset(css.CSSPixelPoint.new(x,y))
   first_value := x.minus(used.margin_box_left()).plus(grid_baseline_from_low(state,box,item.node,true,.first,0))
   last_value := x.minus(used.margin_box_left()).plus(grid_baseline_from_low(state,box,item.node,true,.last,0))
   first_baseline = if reverse_block { css_pixels_max(first_baseline,first_value) } else { css_pixels_min(first_baseline,first_value) }
   last_baseline = if reverse_block { css_pixels_min(last_baseline,last_value) } else { css_pixels_max(last_baseline,last_value) }
  }
  cursor = cursor.plus(group.extent)
 }
 values.set_derived_vertical_baselines(first_baseline,last_baseline)
 _ = mode
 return FormattingContextResult{automatic_content_width:block_size,automatic_content_height:inline_size}
}

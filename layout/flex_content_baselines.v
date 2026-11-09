module layout

// Baselines follow the laid-out flex lines and visual item order. DOM child
// order alone loses row/column reversal and wrap-reverse line progression.
fn publish_flex_content_baselines(mut state LayoutState, container &Node, mut values UsedValues, lines []FlexLine, row_axis bool) {
 if container.computed_values().writing_mode() != .horizontal_tb || lines.len == 0 { return }
 mut selected := [0,0]
 mut cross_edges := [CSSPixels.max(),CSSPixels.min()]
 for index,line in lines {
  mut low,mut high := CSSPixels.max(),CSSPixels.min()
  for item in line.items {
   styled := item.as_node_with_style() or { continue }
   used := state.get(styled)
   start := if row_axis { used.offset.y().minus(used.margin_box_top()) } else { used.offset.x().minus(used.margin_box_left()) }
   extent := if row_axis { used.margin_box_height() } else { used.margin_box_width() }
   low = css_pixels_min(low,start)
   high = css_pixels_max(high,start.plus(extent))
  }
  if low.raw_value() < cross_edges[0].raw_value() { selected[0] = index; cross_edges[0] = low }
  if high.raw_value() >= cross_edges[1].raw_value() { selected[1] = index; cross_edges[1] = high }
 }
 mut results := [?CSSPixels(none),?CSSPixels(none)]
 for side,index in selected {
  mut candidate := ?&Node(none)
  mut edge := if side == 0 { CSSPixels.max() } else { CSSPixels.min() }
  mut has_aligned := false
  for item in lines[index].items {
   styled := item.as_node_with_style() or { continue }
   used := state.get(styled)
   aligned := row_axis && flex_item_participates_in_baseline_alignment(container,item)
   if has_aligned && !aligned { continue }
   coordinate := if row_axis { used.offset.x() } else { used.offset.y() }
   if candidate == none || (aligned && !has_aligned) || (if side == 0 { coordinate.raw_value() < edge.raw_value() } else { coordinate.raw_value() >= edge.raw_value() }) {
    candidate = item; edge = coordinate; has_aligned = aligned
   }
  }
  if item := candidate {
   used := state.get(item.as_node_with_style() or { continue })
   results[side] = used.offset.y().minus(used.margin_box_top()).plus(layout_box_baseline(state,item,if side == 0 { .first } else { .last }))
  }
 }
 values.set_derived_baselines(results[0],results[1])
}

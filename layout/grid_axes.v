module layout

import css

// Track sizing operates on physical x/y axes. CSS rows, columns, flow and
// alignment remain logical and are projected at the formatting boundary.
fn grid_is_vertical(node &Node) bool {
 return node.computed_values().writing_mode() != .horizontal_tb
}

fn grid_axis_reversed(node &Node, horizontal bool) bool {
 style := node.computed_values()
 if !grid_is_vertical(node) { return horizontal && style.direction() == .rtl }
 if horizontal { return style.writing_mode() in [.vertical_rl, .sideways_rl] }
 return (style.direction() == .rtl) != (style.writing_mode() == .sideways_lr)
}

fn grid_axis_template(node &Node, horizontal bool) css.GridTrackSizeList {
 style := node.computed_values()
 return if horizontal != grid_is_vertical(node) { style.grid_template_columns() } else { style.grid_template_rows() }
}

fn grid_axis_implicit_tracks(node &Node, horizontal bool) css.GridTrackSizeList {
 style := node.computed_values()
 return if horizontal != grid_is_vertical(node) { style.grid_auto_columns() } else { style.grid_auto_rows() }
}

fn grid_axis_placement(container &Node, style &css.ComputedValues, horizontal bool, start bool) css.GridTrackPlacement {
 if horizontal != grid_is_vertical(container) {
  return if start { style.grid_column_start() } else { style.grid_column_end() }
 }
 return if start { style.grid_row_start() } else { style.grid_row_end() }
}

fn grid_axis_gap(node &Node, horizontal bool) css.PropertyID {
 return if horizontal != grid_is_vertical(node) { css.PropertyID.column_gap } else { .row_gap }
}

fn grid_axis_content_alignment(node &Node, horizontal bool) css.JustifyContent {
 style := node.computed_values()
 if horizontal != grid_is_vertical(node) { return style.justify_content() }
 return match style.align_content() {
  .normal { .normal } .start { .start } .end_ { .end_ }
  .flex_start { .flex_start } .flex_end { .flex_end } .center { .center }
  .stretch { .stretch } .space_between { .space_between }
  .space_around { .space_around } .space_evenly { .space_evenly }
 }
}

fn grid_physical_areas(node &Node) css.GridTemplateAreas {
 areas := node.computed_values().grid_template_areas()
 if !grid_is_vertical(node) { return areas }
 mut result := css.GridTemplateAreas{row_count:areas.column_count,column_count:areas.row_count}
 for name, area in areas.areas {
  result.areas[name] = css.GridArea{row_start:area.column_start,row_end:area.column_end,column_start:area.row_start,column_end:area.row_end}
 }
 return result
}

fn grid_alignment_text(container &Node, item &Node, horizontal bool) string {
 inline_axis := horizontal != grid_is_vertical(container)
 self_property := if inline_axis { css.PropertyID.justify_self } else { css.PropertyID.align_self }
 items_property := if inline_axis { css.PropertyID.justify_items } else { css.PropertyID.align_items }
 value := item.computed_values().property(self_property,.yes) or { return 'normal' }
 if value.css_text == 'auto' {
  return (container.computed_values().property(items_property,.yes) or { return 'normal' }).css_text
 }
 return value.css_text
}

fn grid_item_alignment_is_safe(container &Node, item &Node, horizontal bool) bool {
 return 'safe' in grid_alignment_text(container,item,horizontal).split(' ')
}

fn grid_item_physical_alignment(container &Node, item &Node, horizontal bool) GridItemAlignment {
 words := grid_alignment_text(container,item,horizontal).split(' ')
 if words.len == 0 { return .normal }
 word := words.last()
 return match word {
  'center' { .center }
  'stretch' { .stretch }
  'baseline' { .baseline }
  'self-start','self-end' {
   same_start := grid_axis_reversed(container,horizontal) == grid_axis_reversed(item,horizontal)
   if same_start == (word == 'self-start') { .start } else { .end }
  }
  'left','right' {
   if grid_axis_reversed(container,horizontal) == (word == 'right') { .start } else { .end }
  }
  'start','flex-start','flow-start' { .start }
  'end','flex-end','flow-end' { .end }
  else { .normal }
 }
}

fn grid_inline_alignment(container &Node, item &Node) GridItemAlignment {
 return grid_item_physical_alignment(container,item,true)
}

fn grid_block_alignment(container &Node, item &Node) GridItemAlignment {
 return grid_item_physical_alignment(container,item,false)
}

fn grid_physical_row_offset(container &Node, height CSSPixels, tracks []GridTrack, start int, span int, gap CSSPixels, leading CSSPixels) CSSPixels {
 offset := leading.plus(grid_track_offset(tracks,start,gap))
 return if grid_axis_reversed(container,false) { height.minus(offset).minus(grid_track_range_size(tracks,start,span,gap)) } else { offset }
}

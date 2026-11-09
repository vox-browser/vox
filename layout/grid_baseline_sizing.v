module layout

import css

struct GridBaselineSizeSubject {
 item &Node
 group int
 from_end bool
 baseline CSSPixels
 extent CSSPixels
}

fn grid_clamp_minimum_for_baseline_shim(state &LayoutState,item &Node,tracks []GridTrack,start int,span int,gap CSSPixels,contribution CSSPixels,shim CSSPixels,horizontal bool) CSSPixels {
 if shim.raw_value()==0 { return contribution }
 if start<0 || start+span>tracks.len { return contribution }
 mut maximum := gap.scaled(f64(span-1))
 for track in tracks[start..start+span] {
  if !track.fixed_max { return contribution }
  maximum=maximum.plus(track.fixed_max_size)
 }
 values := state.get(item.as_node_with_style() or { return contribution })
 edges := if horizontal { flex_or_grid_item_outer_inline_edges(values) } else { flex_or_grid_item_outer_block_edges(values) }
 // The shim consumes stretch-fit space, but can never shrink the item's
 // own margin/border/padding box plus that shim below its outer edges.
 return css_pixels_max(edges.plus(shim),css_pixels_min(contribution,maximum))
}

// Baseline alignment contributes an extra ascent or descent before intrinsic
// tracks are sized; a later position shift alone can push a subject outside
// the track. Measure vertical baseline groups at their natural block sizes.
fn grid_vertical_baseline_column_shims(mut state LayoutState, container &Node, container_values &UsedValues, placements []GridItemPlacement,tracks []GridTrack) map[voidptr]CSSPixels {
 mut result := map[voidptr]CSSPixels{}
 mut subjects := []GridBaselineSizeSubject{}
 mut ascents := map[int]CSSPixels{}
 mut descents := map[int]CSSPixels{}
 for placement in placements {
  item := placement.item
  words := grid_alignment_text(container,item,true).split(' ')
  if words.len == 0 || words.last() != 'baseline' { continue }
  if grid_baseline_size_is_cyclic(state,container,item,true,tracks,placement.column,placement.column_span) { continue }
  computed := item.computed_values()
  if property_is_auto(computed,.margin_left) || property_is_auto(computed,.margin_right) { continue }
  styled := item.as_node_with_style() or { continue }
  box := item.as_box() or { continue }
  mut measure := state.new_measurement_for_subtree(styled)
  populate_intrinsic_containing_block_chain(mut measure,mut state,item)
  mut parent := measure.get_mutable(container.as_node_with_style() or { continue })
  parent.set_content_width(container_values.content_width())
  parent.set_content_height(container_values.content_height())
  parent.set_has_definite_height(container_values.has_definite_height())
  mut initial := measure.get_mutable(styled)
  initial.set_containing_block_used_values(parent)
  resolve_box_model_edges(computed,mut initial,parent.content_width().to_double())
  width := resolve_layout_content_size(item,computed.size_value(.width),parent.content_width(),initial,true) or { calculate_max_content_width(mut measure,box) }
  height := if parent.has_definite_height() { ?CSSPixels(parent.content_height()) } else { ?CSSPixels(none) }
  mut values := layout_independent_child(mut measure,item,mut parent,parent.content_width(),height,width,none)
  values.margin_left = css_px(computed.length_percentage_to_px(.margin_left,parent.content_width().to_double()) or { 0.0 })
  values.margin_right = css_px(computed.length_percentage_to_px(.margin_right,parent.content_width().to_double()) or { 0.0 })
  last := words[0] == 'last'
  reversed := grid_baseline_group_reversed(container,item,true)
  opposite := grid_axis_reversed(container,true) != reversed
  logical_end := last != opposite
  from_end := logical_end != grid_axis_reversed(container,true)
  track := placement.column + if logical_end { placement.column_span-1 } else { 0 }
  group := track*2 + if from_end { 1 } else { 0 }
  baseline := grid_alignment_baseline_from_low(measure,container,item,true,if last { .last } else { .first },reversed)
  extent := values.margin_box_width()
  ascents[group] = css_pixels_max(ascents[group],baseline)
  descents[group] = css_pixels_max(descents[group],extent.minus(baseline))
  subjects << GridBaselineSizeSubject{item:item,group:group,from_end:from_end,baseline:baseline,extent:extent}
  measure.release_measurement()
 }
 for subject in subjects {
  result[voidptr(subject.item)] = if subject.from_end { descents[subject.group].minus(subject.extent.minus(subject.baseline)) } else { ascents[subject.group].minus(subject.baseline) }
 }
 return result
}

// Row sizing follows the first width-constrained child layout, so its line
// baselines already include wrapping in the resolved column area.
fn grid_row_baseline_shims(state &LayoutState,container &Node,placements []GridItemPlacement,tracks []GridTrack) map[voidptr]CSSPixels {
 mut result := map[voidptr]CSSPixels{}
 mut subjects := []GridBaselineSizeSubject{}
 mut ascents := map[int]CSSPixels{}
 mut descents := map[int]CSSPixels{}
 for placement in placements {
  item := placement.item
  words := grid_alignment_text(container,item,false).split(' ')
  if words.len==0 || words.last()!='baseline' { continue }
  if grid_baseline_size_is_cyclic(state,container,item,false,tracks,placement.row,placement.row_span) { continue }
  computed := item.computed_values()
  if property_is_auto(computed,.margin_top) || property_is_auto(computed,.margin_bottom) { continue }
  styled := item.as_node_with_style() or { continue }
  values := state.get(styled)
  last := words[0]=='last'
  reversed := grid_baseline_group_reversed(container,item,false)
  opposite := grid_axis_reversed(container,false)!=reversed
  logical_end := last != opposite
  from_end := logical_end != grid_axis_reversed(container,false)
  track := placement.row+if logical_end { placement.row_span-1 } else { 0 }
  group := track*2+if from_end { 1 } else { 0 }
  baseline := grid_alignment_baseline_from_low(state,container,item,false,if last { .last } else { .first },reversed)
  extent := values.margin_box_height()
  ascents[group]=css_pixels_max(ascents[group],baseline)
  descents[group]=css_pixels_max(descents[group],extent.minus(baseline))
  subjects << GridBaselineSizeSubject{item:item,group:group,from_end:from_end,baseline:baseline,extent:extent}
 }
 for subject in subjects {
  result[voidptr(subject.item)] = if subject.from_end { descents[subject.group].minus(subject.extent.minus(subject.baseline)) } else { ascents[subject.group].minus(subject.baseline) }
 }
 return result
}

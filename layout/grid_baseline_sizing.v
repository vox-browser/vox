module layout

import css

struct GridBaselineSizeSubject {
 item &Node
 group int
 from_end bool
 baseline CSSPixels
 extent CSSPixels
}

// Baseline alignment contributes an extra ascent or descent before intrinsic
// tracks are sized; a later position shift alone can push a subject outside
// the track. Measure vertical baseline groups at their natural block sizes.
fn grid_vertical_baseline_column_shims(mut state LayoutState, container &Node, container_values &UsedValues, placements []GridItemPlacement) map[voidptr]CSSPixels {
 mut result := map[voidptr]CSSPixels{}
 if !grid_is_vertical(container) { return result }
 mut subjects := []GridBaselineSizeSubject{}
 mut ascents := map[int]CSSPixels{}
 mut descents := map[int]CSSPixels{}
 for placement in placements {
  item := placement.item
  if !grid_is_vertical(item) { continue }
  words := grid_alignment_text(container,item,true).split(' ')
  if words.len == 0 || words.last() != 'baseline' { continue }
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
  opposite := grid_axis_reversed(container,true) != grid_axis_reversed(item,true)
  logical_end := last != opposite
  from_end := logical_end != grid_axis_reversed(container,true)
  track := placement.column + if logical_end { placement.column_span-1 } else { 0 }
  group := track*2 + if from_end { 1 } else { 0 }
  baseline := grid_baseline_from_low(measure,container,item,true,if last { .last } else { .first },0)
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

module layout

import css

// An auto abspos grid edge refers to the padding edge. Resolve the two
// endpoints separately; auto / <line> must not become a one-track area.
fn grid_abspos_axis_bounds(container &Node, horizontal bool, start css.GridTrackPlacement, end css.GridTrackPlacement,
 position GridAxisPlacement, implicit_before int, size CSSPixels, padding_low CSSPixels, padding_high CSSPixels,
 tracks []GridTrack, gap CSSPixels, leading CSSPixels) (CSSPixels,CSSPixels) {
 reversed := grid_axis_reversed(container,horizontal)
 mut low := CSSPixels.new(0).minus(if reversed { padding_high } else { padding_low })
 mut high := size.plus(if reversed { padding_low } else { padding_high })
 first := position.start + implicit_before
 last := position.end + implicit_before
 start_auto := start.is_auto() || (start.is_span() && !end.is_positioned())
 end_auto := end.is_auto() || (end.is_span() && !start.is_positioned())
 if !start_auto && first >= 0 && first <= tracks.len {
  low = leading.plus(grid_track_offset(tracks,first,gap))
 }
 if !end_auto && last >= 0 && last <= tracks.len {
  high = leading.plus(grid_track_offset(tracks,last,gap))
  if last > 0 && last < tracks.len && !grid_gutter_after_track_collapses(tracks,last-1) {
   high = high.minus(gap)
  }
 }
 extent := css_pixels_max(high.minus(low),CSSPixels.new(0))
 return if reversed { size.minus(high) } else { low },extent
}
